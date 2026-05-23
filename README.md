# FitRehber Mobil

FitRehber platformunun **Flutter** ile geliştirilmiş mobil uygulaması. Kullanıcılara
beslenme takibi, sağlık içerikleri, forum ve yapay zekâ destekli bir asistan sunan
kapsamlı bir fitness rehberi uygulamasıdır.

---

## İçindekiler

- [Özellikler](#özellikler)
- [Kullanılan Teknolojiler](#kullanılan-teknolojiler)
- [Proje Yapısı](#proje-yapısı)
- [Kod Rehberi](#kod-rehberi)
- [Mimari](#mimari)
- [Kurulum ve Çalıştırma](#kurulum-ve-çalıştırma)
- [Testler](#testler)

---

## Özellikler

| Bölüm | Açıklama |
|-------|----------|
| **Kimlik Doğrulama** | E-posta/parola ile giriş ve kayıt, Google ile giriş (OAuth 2.0 + PKCE), e-posta doğrulama, parola sıfırlama. Oturum token'ları cihazın şifreli alanında saklanır. |
| **Onboarding** | Yeni kullanıcı için 4 adımlı profil kurulum sihirbazı (kimlik, ölçüler, hedef, özet). |
| **Ana Sayfa** | Kategoriye göre filtrelenebilen, sonsuz kaydırmalı sağlık içerikleri akışı. Çevrimdışı önbellek desteği. |
| **Beslenme Takibi** | Günlük kalori/makro takibi, öğün kayıtları, su takibi ve kişiye özel hedef hesaplama (Mifflin-St Jeor formülü). |
| **Forum** | Kullanıcıların soru sorup tartıştığı, görsel ekleyebildiği bölüm. |
| **Yapay Zekâ Asistanı** | Beslenme, antrenman ve sağlık konularında sohbet tabanlı AI asistanı. |
| **Profil** | Kullanıcı profili, rozetler, aktivite ısı haritası, paylaşımlar/kaydedilenler/beğeniler. |
| **Makale & Yorumlar** | Zengin biçimli makale görüntüleme, ağaç yapılı (iç içe) yorum sistemi. |

---

## Kullanılan Teknolojiler

- **Flutter / Dart** — çapraz platform mobil uygulama çatısı
- **Riverpod** — durum yönetimi (state management)
- **go_router** — sayfa yönlendirme ve oturum tabanlı yönlendirme koruması
- **Dio** — HTTP istemcisi (token yenileme interceptor'ı ile)
- **flutter_secure_storage** — token'ların güvenli (şifreli) saklanması
- **shared_preferences / Hive** — yerel önbellekleme
- **cached_network_image, shimmer, google_fonts** — arayüz bileşenleri

---

## Proje Yapısı

Proje, **özellik bazlı (feature-first)** bir klasör mimarisi kullanır. Her özellik
kendi ekranlarını, durum yöneticilerini ve widget'larını kendi klasöründe barındırır:

```
lib/
├── main.dart                 # Uygulamanın giriş noktası
├── core/                     # Uygulama genelinde temel yapı taşları
│   ├── constants/api_sabitleri.dart
│   ├── router/uygulama_yonlendirici.dart
│   └── theme/uygulama_temasi.dart
├── features/                 # Her biri bağımsız bir özellik (modül)
│   ├── kimlik/               # Giriş, kayıt, e-posta doğrulama, parola sıfırlama
│   ├── ilk_kurulum/          # İlk kurulum sihirbazı
│   ├── ana_sayfa/            # Ana sayfa ve alt gezinme kabuğu
│   ├── beslenme/             # Beslenme ve su takibi
│   ├── icerik/               # Makale detayı ve yorumlar
│   ├── forum/                # Forum ve soru sorma
│   ├── asistan/              # Yapay zekâ asistanı
│   ├── profil/               # Kullanıcı profili
│   ├── kategoriler/          # İçerik kategorileri
│   └── arama/                # İçerik arama
└── shared/                   # Özellikler arası paylaşılan kod
    ├── models/               # Veri modelleri (JSON dönüşümleri)
    ├── services/             # Yerel besin veritabanı vb.
    ├── widgets/              # Tekrar kullanılabilir widget'lar
    ├── utils/                # Yardımcı hesaplama sınıfları
    ├── sayfalama/            # Sayfalama yardımcıları
    ├── api_servisi.dart      # Tüm backend isteklerinin merkezi
    ├── kimlik_servisi.dart   # Kimlik doğrulama servisi
    ├── google_oauth_akisi.dart
    └── oturum_denetleyici.dart
```

Her özellik klasörü kendi içinde `providers` (durum yöneticileri) ve `widgets`
(parça widget'lar) alt klasörlerini kullanabilir. Ekran dosyaları doğrudan ilgili
özellik klasörünün içinde durur; örnek: `features/kimlik/giris_ekrani.dart`.

---

## Kod Rehberi

Kod tabanı savunmada rahat okunabilmesi için uygulamaya ait isimlerde Türkçe
semantik adlandırma kullanır. Flutter/Dart yaşam döngüsü metotları ve paket API'leri
bilerek değiştirilmemiştir: `build`, `initState`, `dispose`, `fromJson`, `toJson`,
`copyWith`, `Widget`, `Provider`, `Dio`, `GoRouter` gibi isimler framework
sözleşmesidir.

- `KimlikServisi`: giriş, kayıt, Google OAuth, e-posta doğrulama maili tekrar gönderme
  ve şifre sıfırlama isteklerini yönetir.
- `OturumDenetleyici`: uygulama açılışında token okur, profili yükler, router'ın
  hangi ekrana gideceğini belirleyen oturum durumunu tutar.
- `ApiServisi`: backend ile konuşan merkezi servis katmanıdır. Token yenileme,
  hata ayıklama ve profil/beslenme/içerik/forum istekleri burada toplanır.
- `BeslenmeHesaplayici`: kalori, makro ve su hedefi hesaplarını içerir; formüller
  testlerle korunur.
- `SayfaliYanit` ve `SayfalamaTetikleyici`: sonsuz kaydırmalı listelerde yeni sayfa
  yükleme kararını ve gelen sayfalı API yanıtını düzenler.

Backend JSON alanları ve uç nokta isimleri kontrat olduğu için korunur. Örneğin
`username`, `email`, `password`, `access`, `refresh`, `is_onboarded`, `message` ve
`answer` alanları API ile birebir uyum için İngilizce kalır.

Uç nokta adresleri ayrıca `test/api_sabitleri_test.dart` ile korunur. Bu test,
Türkçeleştirme sırasında değişken adları çevrilse bile `/auth/login/`,
`/mobile/auth/register/`, `/verification/resend/` ve `/password-reset/request/`
gibi backend sözleşmelerinin yanlışlıkla Türkçeleşmesini engeller.

---

## Mimari

Uygulama üç katmanlı bir akışa dayanır:

1. **Sunum katmanı (`features/`)** — Kullanıcının gördüğü ekranlar ve widget'lar.
2. **Durum katmanı (Riverpod provider'ları)** — Ekranların verisini ve iş akışını yönetir.
3. **Servis katmanı (`shared/`)** — Backend ile iletişim (`ApiServisi`, `KimlikServisi`).

**Veri akışı örneği:** Bir ekran → ilgili provider'ı çağırır → provider `ApiServisi`
üzerinden backend'e istek atar → gelen JSON modele dönüştürülür → durum güncellenir →
ekran otomatik olarak yeniden çizilir.

**Hata yönetimi:** Tüm ağ hataları servis katmanında yakalanır ve kullanıcıya
gösterilebilecek anlaşılır Türkçe mesajlara dönüştürülür (`hata_yardimcilari.dart`).
Erişim token'ı süresi dolduğunda araya giren bir interceptor token'ı sessizce
yeniler ve isteği tekrar dener.

---

## Kurulum ve Çalıştırma

Gereksinim: [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.11+).

```bash
# Bağımlılıkları yükle
flutter pub get

# Uygulamayı bağlı bir cihazda/emülatörde çalıştır
flutter run
```

---

## Testler

Proje, model dönüşümleri, hesaplamalar, yönlendirme ve widget davranışları için
birim ve widget testleri içerir. `api_sabitleri_test.dart` kritik backend
uç nokta adresleri için regresyon testi görevi görür.

```bash
# Tüm testleri çalıştır
flutter test

# Kod analizini çalıştır
flutter analyze
```
