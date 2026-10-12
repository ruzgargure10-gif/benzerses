# BenzerSes 🎧

**Bir şarkı veya sanatçı yaz → sana benzeyen sanatçıları ve şarkıları bulsun.**

Tek dosyalık (`index.html`), sunucusuz bir müzik keşif motoru. Kurulum yok, derleme yok, hiçbir hesap/API anahtarı gerekmiyor — dosyayı açtığın an çalışır.

## Ne yapar?

- **Sanatçı & şarkı arama** — yazarken canlı öneri (sanatçılar + şarkılar)
- **Benzer sanatçı motoru (3 katmanlı)**
  1. **Deezer** dinleme grafiği — birlikte dinlenme verisi
  2. **ListenBrainz + MusicBrainz** — ortak dinleyici oturumları
  3. **Yerleşik tür haritası** — veri zayıf olduğunda devreye girer, sonuç asla boş kalmaz
- **Zincirle keşif** — "Candan Erçetin → Sezen Aksu → Nazan Öncel…" şeklinde benzerden benzere ilerleme
- **Önerilen şarkılar** — her öneri "neden önerildi" etiketiyle gelir (örn. *Duman gibi*)
- **30 saniyelik önizleme çaları** — Deezer önizlemesi yoksa otomatik iTunes önizlemesine geçer; sırada çalma, karıştırma, ileri/geri
- **Favoriler, son aramalar, paylaşılabilir bağlantılar** (`#/artist/14826` gibi), mobil uyumlu koyu tema

## Teknik

| | |
|---|---|
| Teknoloji | Tek HTML dosyası, saf JS/CSS — bağımlılık yok, derleme yok |
| Veri | Deezer (JSONP), Apple iTunes Search (CORS), MusicBrainz, ListenBrainz Labs |
| Gizlilik | Sunucu yok, izleme yok, çerez yok — aramalar tarayıcıdan çıkmaz (localStorage cache + favoriler) |
| Telif | Yalnızca resmî 30 sn önizlemeler çalar; tüm haklar sanatçılara ve plak şirketlerine aittir |

## Yayına alma

Herhangi bir statik barındırıcıda çalışır (yönlendirme hash tabanlı olduğu için sunucu ayarı gerekmez):

- **GitHub Pages:** `deploy/deploy-github.sh <TOKEN> benzerses` → `https://kullanıcıadı.github.io/benzerses/`
- **Netlify Drop:** `index.html` dosyasını <https://app.netlify.com/drop> sayfasına sürükle-bırak
- **Vercel / Cloudflare Pages:** repo bağla, çerçeve: "Other", çıktı klasörü: kök
- **Kendi hostingin:** `index.html` dosyasını FTP ile `public_html` içine at — hepsi bu

## Yerel çalıştırma

```bash
python3 -m http.server 4173     # http://localhost:4173
# veya dosyaya çift tıkla (file://) — çoğu tarayıcıda çalışır
```

## Güvenlik ve gizlilik

| Konu | Durum |
|---|---|
| Sunucu / veritabanı | **Yok.** Statik tek dosya → SQL injection, RCE, oturum çalma gibi sunucu saldırı yüzeyleri yapısal olarak imkânsız |
| Hesaplar / çerezler | **Yok.** Kimlik doğrulama, çerez, reklam, izleme kodu bulunmaz |
| XSS | Tüm metinler `esc()` ile kaçışlanır; `eval` / `document.write` / `new Function` yok (denetim: 0 bulgu) |
| **CSP (katı, hash'li)** | `script-src 'self' 'sha256-…' https://api.deezer.com` — **`'unsafe-inline'` yok**; sayfaya enjekte edilen kod çalışamaz (test edildi: enjeksiyon engellendi) |
| **URL beyaz listesi** | Görsel/ses yalnızca Deezer/Apple CDN'lerinden; kurcalanan localStorage dahi dış adres yükleyemez (test edildi) |
| Veri doğrulama | API + önbellek verisi alan-alan doğrulanır; uygunsuz alanlar atılır |
| Girdi sınırları | Arama 80 karakter; kontrol karakterleri temizlenir; hash rotası beyaz listeli; URL'ler `URLSearchParams` ile kodlanır |
| Hız sınırı | API'lere eşzamanlı en fazla 8 istek (IP kısıtlamasına karşı) |
| Yerel veri | Yalnızca `localStorage`; “verilerimi sil” düğmesi tek dokunuşla temizler |
| İletişim | HTTPS (GitHub Pages) + `Referrer-Policy: strict-origin-when-cross-origin` |
| Dağıtım | Yükleme öncesi CSP-hash doğrulaması, yayın sonrası SHA-256 bütünlük kontrolü, gizli anahtar taraması + push koruması, Pages HTTPS zorlaması (`deploy/deploy-github.sh`) |
| Bilinen sınır 1 | Deezer CORS başlığı göndermediği için **JSONP** kullanılır (api.deezer.com'a güven); sunucu aracısı kurulursa kaldırılabilir |
| Bilinen sınır 2 | GitHub Pages özel HTTP başlığı ('X-Frame-Options', 'Permissions-Policy', CSP `frame-ancestors`) desteklemez; Cloudflare/Netlify katmanı eklenirse açılabilir |

> **Geliştirici notu:** `index.html` içindeki JavaScript'i değiştirirsen CSP hash'i güncellenmeli:
> `python3 tools/csp-hash.py` (kontrol: `python3 tools/csp-hash.py --check`). Deploy betiği hash uyuşmazsa yüklemeyi reddeder.

## Sınırlar

- Önizlemeler 30 saniyedir ve hangi şarkının önizlemesi olacağı kaynağa bağlıdır; önizlemesi olmayan şarkı otomatik atlanır.
- Deezer "benzer sanatçı" verisi çok yeni/niş isimlerde boş dönebilir; bu durumda ListenBrainz, ardından tür haritası devreye girer.
- Ticari kullanım öncesi Deezer/iTunes/ListenBrainz kullanım koşullarını gözden geçir.
