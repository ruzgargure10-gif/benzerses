# Kurulum — Kayıt sistemi + Yönetim paneli (5 dakika)

Site şu an **sunucusuz (statik)**. Kayıt/giriş sistemi ve yönetim paneli için ücretsiz bir
veritabanı servisi olan **Supabase** kullanıyoruz. **Site zaten koduyla hazır** — sadece aşağıdaki
3 adımı yapman gerekiyor.

---

## Adım 1 — Supabase hesabı aç (1 dk)

1. https://supabase.com → **Start your project** → **Continue with GitHub** ile giriş yap.
2. **New project** düğmesine bas:
   - Name: `benzerses`
   - Database Password: güçlü bir şifre (not al, lazım olmayacak ama)
   - Region: **Frankfurt (eu-central-1)** — Türkiye'ye en yakın.
3. Proje hazırlanmasını bekle (~2 dk).

## Adım 2 — Veritabanını kur (1 dk)

1. Sol menüden **SQL Editor**'ü aç → **New query**.
2. Bu depodaki **`supabase/setup.sql`** dosyasının **tamamını** kopyalayıp yapıştır → **Run**.
3. Hata yoksa şema, güvenlik duvarları (RLS) ve fonksiyonlar kuruldu. ✅

## Adım 3 — Anahtarları siteye bağla (1 dk)

Sol menü: **Settings → API**. Şu iki değeri kopyala:

| Ne | Nerede |
|---|---|
| **Project URL** | `https://xxxxx.supabase.co` gibi |
| **anon public** anahtar | `eyJhbGci...` ile başlayan uzun dize |

Sonra `index.html` içinde en altta şu bloğu bul ve doldur:

```js
const CONFIG = {
  SUPABASE_URL: '',        // ← Project URL buraya
  SUPABASE_ANON_KEY: '',   // ← anon public buraya
};
```

Ardından yayınla:

```bash
python3 tools/csp-hash.py                              # CSP hash'ini tazele
python3 tools/csp-hash.py --check                      # doğrula
bash deploy/deploy-github.sh                           # GITHUB_TOKEN envi ile
```

> **anon anahtar gizli değildir** — tarayıcıda görünmesi normaldir; asıl koruma veritabanındaki
> RLS politikalarıdır (Adım 2'de kuruldu). **service_role anahtarını ASLA siteye koyma.**

## Yönetici (admin) yapmak

Kayıt olduktan sonra SQL Editor'de kendini yönetici işaretle (e-postanı yaz):

```sql
update public.profiles set is_admin = true where email = 'SENIN_EPOSTAN@ornek.com';
```

Artık üst menüde **Yönetim** düğmesi görünür (`#/admin`).

> **İstersen bu adımları ben de yapabilirim:** supabase.com → Account → Access Tokens'tan bir
> token (`sbp_...`) oluşturup bana ver; SQL'i çalıştırır, anahtarları bağlar, yayınlar ve test ederim.

---

## Panelde ne görünür?

| Bölüm | İçerik |
|---|---|
| Özet | Toplam kullanıcı, bugünkü kayıt/giriş, toplam oturum, toplam aktivite |
| Kullanıcılar | Kullanıcı adı, e-posta, kayıt tarihi, son giriş, KVKK onay zamanı, yönetici durumu |
| Oturumlar | Her girişin cihazı (tarayıcı/işletim sistemi), dili, saat dilimi, ekran çözünürlüğü, **maskeli IP**, tarih |
| Aktiviteler | Dinlenen şarkılar, aranan sanatçılar, ziyaret edilen sanatçı sayfaları (son 120) |
| İşlemler | Yönetici yap/çıkar, kullanıcının verilerini sil, CSV indir |

## Panelde ne **görünmez** ve neden?

| Görünmez | Neden |
|---|---|
| Kullanıcı şifreleri | Supabase şifreleri tek yönlü (bcrypt) saklar — hiç kimse, sen dahil, göremez |
| Oturum token'ları (çerezler) | Gösterilseydi, paneli ele geçiren biri tüm hesaplara girebilirdi. Güvenlik gereği hiçbir panelde gösterilmez |
| Kullanıcının tarayıcısındaki veriler | Favoriler/önbellek kullanıcının kendi tarayıcısındadır; **hiçbir site bunu uzaktan okuyamaz** (tarayıcı güvenlik modeli). Sitedeki eşdeğeri veritabanındaki `favorites` tablosudur |
| Başka sitelerin çerezleri | Teknik olarak imkânsız + KVKK/TCK kapsamında suçtur. Bu proje kapsamı dışındadır |

## Veri koruma (KVKK uyumu)

- Kayıt ekranında **açık rıza** kutusu vardır; onay zamanı `profiles.consent_at` alanına kaydedilir.
- Toplanan veriler: kullanıcı adı, e-posta, rıza zamanı, giriş/aktivite kayıtları.
- Amaç: hesap hizmeti sunmak ve güvenliği sağlamak. Üçüncü taraflarla paylaşılmaz, satılmaz.
- Kullanıcı her an: **Hesabım → Verilerimi sil** (tek dokunuş) ve panelden yönetici tarafından da silinebilir.
- Saklama önerisi: 12 ay; sonrasında oturum/aktivite kayıtlarını toplu temizle (SQL):
  ```sql
  delete from public.activity     where created_at < now() - interval '12 months';
  delete from public.sessions_log where created_at < now() - interval '12 months';
  ```
- Aydınlatma metni site içinde: `#/gizlilik`

## Güvenlik özeti (teknik)

- Şifreler Supabase Auth'ta **bcrypt** ile saklanır; site şifreyi hiçbir yerde tutmaz.
- Tüm veri erişimi **RLS** ile kısıtlı: kullanıcı yalnızca kendi satırlarını görür/yazar; yönetici tümünü görür.
- `is_admin` alanı istemciden **değiştirilemez** (kolon izni kapalı; yalnızca `set_admin` RPC'si ile ve o da yönetici kontrolü yapar).
- Oturum meta verisi (IP, tarayıcı) **sunucu tarafında** trigger ile doldurulur; istemci uyduramaz.
- Yetkisiz erişim denemeleri Supabase tarafından hız sınırlanır (rate limit) ve loglanır.
