-- ============================================================
--  BenzerSes — Supabase şeması / güvenlik / fonksiyonlar
--  KURULUM: Supabase Dashboard → SQL Editor → tümünü yapıştır → RUN
--  Not: Her şey satır düzeyi güvenlik (RLS) ile korunur; istemci
--       koda hiçbir gizli anahtar girmez.
-- ============================================================

-- 1) PROFİLLER
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  username   text,
  email      text,
  is_admin   boolean not null default false,
  consent_at timestamptz,
  created_at timestamptz not null default now(),
  last_login timestamptz
);
create unique index if not exists profiles_username_key on public.profiles (lower(username));

-- 2) OTURUM GÜNLÜĞÜ (kim, hangi cihazdan, ne zaman giriş yaptı)
create table if not exists public.sessions_log (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  user_agent text,
  platform   text,
  language   text,
  timezone   text,
  screen     text,
  referrer   text,
  ip         inet,
  created_at timestamptz not null default now()
);

-- 3) AKTİVİTE AKIŞI (dinleme / arama / sanatçı ziyareti)
create table if not exists public.activity (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,
  detail     text,
  created_at timestamptz not null default now()
);

-- 4) FAVORİLER (bulut eşitleme)
create table if not exists public.favorites (
  user_id    uuid not null references auth.users(id) on delete cascade,
  artist_id  bigint not null,
  name       text,
  picture    text,
  created_at timestamptz not null default now(),
  primary key (user_id, artist_id)
);

-- 5) profiles ile birleşik sorgu (join) için yabancı anahtarlar
alter table public.sessions_log drop constraint if exists sessions_user_fk;
alter table public.sessions_log add constraint sessions_user_fk
  foreign key (user_id) references public.profiles(id) on delete cascade;
alter table public.activity drop constraint if exists activity_user_fk;
alter table public.activity add constraint activity_user_fk
  foreign key (user_id) references public.profiles(id) on delete cascade;
alter table public.favorites drop constraint if exists favorites_user_fk;
alter table public.favorites add constraint favorites_user_fk
  foreign key (user_id) references public.profiles(id) on delete cascade;

-- 6) Yardımcı: çağıran kullanıcı yönetici mi?
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

-- 7) Oturum meta verisini SUNUCU tarafında doldur (istemci kurcalayamaz)
create or replace function public.tg_session_meta() returns trigger
language plpgsql security definer set search_path = public as $$
declare h jsonb := '{}'::jsonb; ips text;
begin
  begin h := current_setting('request.headers', true)::jsonb; exception when others then h := '{}'::jsonb; end;
  if new.ip is null then
    ips := split_part(coalesce(h->>'x-forwarded-for',''), ',', 1);
    if ips <> '' then begin new.ip := ips::inet; exception when others then null; end if; end if;
  end if;
  if new.user_agent is null then new.user_agent := left(coalesce(h->>'user-agent',''), 400); end if;
  if new.referrer  is null then new.referrer  := left(coalesce(h->>'referer',''), 300); end if;
  return new;
end $$;
drop trigger if exists session_meta on public.sessions_log;
create trigger session_meta before insert on public.sessions_log
for each row execute function public.tg_session_meta();

-- 8) Kayıt olan kullanıcı için otomatik profil
create or replace function public.tg_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare uname text; base text;
begin
  base := nullif(trim(coalesce(new.raw_user_meta_data->>'username','')), '');
  if base is null then base := split_part(coalesce(new.email,'kullanici'), '@', 1); end if;
  base := left(regexp_replace(base, '[^[:alnum:]_\.\-]', '', 'g'), 24);
  if base = '' then base := 'kullanici'; end if;
  uname := base;
  if exists (select 1 from public.profiles where lower(username) = lower(uname)) then
    uname := base || '_' || substr(md5(random()::text), 1, 4);
  end if;
  insert into public.profiles (id, username, email, consent_at)
  values (new.id, uname, new.email,
          case when coalesce((new.raw_user_meta_data->>'consent')::boolean, false) then now() else null end)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists new_user on auth.users;
create trigger new_user after insert on auth.users
for each row execute function public.tg_new_user();

-- 9) RLS: herkes yalnızca kendi verisini; yönetici hepsini görür
alter table public.profiles     enable row level security;
alter table public.sessions_log enable row level security;
alter table public.activity     enable row level security;
alter table public.favorites    enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists sessions_insert on public.sessions_log;
create policy sessions_insert on public.sessions_log for insert
  with check (user_id = auth.uid());
drop policy if exists sessions_select on public.sessions_log;
create policy sessions_select on public.sessions_log for select
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists sessions_delete on public.sessions_log;
create policy sessions_delete on public.sessions_log for delete
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists activity_insert on public.activity;
create policy activity_insert on public.activity for insert
  with check (user_id = auth.uid());
drop policy if exists activity_select on public.activity;
create policy activity_select on public.activity for select
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists activity_delete on public.activity;
create policy activity_delete on public.activity for delete
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists favorites_all on public.favorites;
create policy favorites_all on public.favorites for all
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid());

-- 10) İzinler (en az yetki ilkesi: anon hiçbir şey görmez)
revoke all on public.profiles, public.sessions_log, public.activity, public.favorites from anon;
revoke all on public.profiles, public.sessions_log, public.activity, public.favorites from authenticated;
grant select on public.profiles to authenticated;
grant update (username) on public.profiles to authenticated;   -- yalnızca kullanıcı adı alanı!
grant select, insert, delete on public.sessions_log to authenticated;
grant select, insert, delete on public.activity to authenticated;
grant select, insert, delete on public.favorites to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- 11) Güvenli RPC'ler (istemci doğrudan tablo güncelleyemez)
create or replace function public.set_username(p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare clean text;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  clean := left(regexp_replace(coalesce(p_name,''), '[^[:alnum:]_\.\-]', '', 'g'), 24);
  if length(clean) < 3 then raise exception 'Kullanıcı adı en az 3 karakter olmalı'; end if;
  if exists (select 1 from public.profiles where lower(username) = lower(clean) and id <> auth.uid()) then
    raise exception 'Bu kullanıcı adı zaten alınmış';
  end if;
  update public.profiles set username = clean where id = auth.uid();
end $$;

create or replace function public.touch_login() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  update public.profiles set last_login = now() where id = auth.uid();
end $$;

create or replace function public.set_admin(p_user uuid, p_admin boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Yetki yok'; end if;
  if p_user = auth.uid() then raise exception 'Kendi yetkini değiştiremezsin'; end if;
  update public.profiles set is_admin = p_admin where id = p_user;
end $$;

create or replace function public.delete_user_data(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (p_user = auth.uid() or public.is_admin()) then raise exception 'Yetki yok'; end if;
  delete from public.activity     where user_id = p_user;
  delete from public.sessions_log where user_id = p_user;
  delete from public.favorites    where user_id = p_user;
  -- Not: giriş hesabının kendisi (auth.users) buradan silinmez.
  -- Tam hesap silme: Dashboard → Authentication → Users → kullanıcıyı sil.
end $$;

-- ============================================================
--  SON ADIM (bir kez): kendini yönetici yap
--  Aşağıdaki satırdaki e-postayı kendi e-postanla değiştir ve çalıştır:
-- ============================================================
-- update public.profiles set is_admin = true where email = 'SENIN_EPOSTAN@ornek.com';
