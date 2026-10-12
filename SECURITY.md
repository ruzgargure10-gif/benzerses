# Güvenlik Politikası — BenzerSes

## Mimari özeti

BenzerSes **tamamen statiktir**: sunucu, veritabanı, oturum, hesap, çerez ve izleme kodu yoktur.
Site tek bir HTML dosyasıdır ve tüm işlemler tarayıcıda çalışır.

Bu tasarım gereği şu saldırı sınıfları **yapısal olarak imkânsızdır**: SQL injection, sunucu tarafı
komut çalıştırma (RCE), kimlik/oturum çalma, kullanıcı verisi sızıntısı, CSRF (state değiştiren sunucu ucu yok).

## Uygulanan korumalar

| Katman | Önlem |
|---|---|
| Kod enjeksiyonu (XSS) | Tüm API/önbellek metinleri `esc()` ile HTML-kaçışlanır; `eval` / `document.write` / `new Function` yoktur |
| CSP | **SHA-256 script hash'li katı politika**: `script-src 'self' 'sha256-…' https://api.deezer.com` — `'unsafe-inline'` yoktur, yani sayfaya sonradan enjekte edilen hiçbir kod çalışamaz |
| Kaynak beyaz listesi | Görsel/ses URL'leri yalnızca Deezer/Apple CDN alan adlarına aitse kabul edilir (API yanıtı veya localStorage kurcalansa bile) |
| Veri doğrulama | API ve önbellek verileri alan-alan doğrulanır (tip, uzunluk, sayı aralığı); uygunsuz alanlar atılır |
| Girdi sınırları | Arama 80 karakterle sınırlı; kontrol karakterleri/görünmez unicode temizlenir; hash yönlendirmesi yalnızca beklenen biçimleri kabul eder; URL'ler `URLSearchParams` ile kodlanır |
| Kaynak tüketimi | API'lere eşzamanlı en fazla 8 istek (IP engeli/hız sınırı riskine karşı) |
| Gizlilik | Sunucuya hiçbir veri gitmez; favoriler/önbellek yalnızca tarayıcının localStorage'ında tutulur ve “verilerimi sil” düğmesiyle tek dokunuşla silinir |
| İletişim | Tüm veri kaynakları HTTPS; `Referrer-Policy: strict-origin-when-cross-origin` |
| Dağıtım | Yükleme öncesi CSP-hash doğrulaması, yayın sonrası SHA-256 bütünlük kontrolü, GitHub gizli anahtar taraması + push koruması, Pages HTTPS zorlaması |

## Bilinen sınırlar (dürüstçe)

1. **JSONP**: Deezer API'si CORS başlığı göndermediği için verisi `<script>` üzerinden JSONP ile alınır.
   Bu, `api.deezer.com`'un dürüstlüğüne güvenmek anlamına gelir. Bir sunucu aracısı (serverless proxy)
   kurulursa JSONP tamamen kaldırılabilir.
2. **HTTP başlığı düzeyindeki korumalar**: GitHub Pages özel yanıt başlığı ayarlamaya izin vermez.
   Bu nedenle `X-Frame-Options`, `Permissions-Policy` gibi başlıklar ve `frame-ancestors` CSP yönergesi
   uygulanamaz (meta etiketle çalışmaz). Cloudflare/Netlify gibi başlık destekleyen bir katman
   eklenirse bu korumalar da açılabilir.
3. **İstemci tarafı**: Kullanıcının tarayıcısına kurulmuş kötü niyetli bir eklenti, her sitede olduğu gibi,
   sayfaya müdahale edebilir. Bu, web uygulamalarının genel sınırıdır.

## Güvenlik açığı bildirimi

Bir zafiyet bulduysan: https://github.com/BenzerSes/issues adresinden (veya depo sahibinin
issue sayfasından) **özel bir bildirim** aç ya da doğrudan depo sahibine ulaş.
Lütfen herkese açık istismar paylaşımından önce bize haber ver.

Yanıt hedefi: 72 saat içinde ilk dönüş.
