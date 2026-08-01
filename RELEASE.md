# Yayın Rehberi — Android

Bu dosya FitRehber mobil uygulamasının Play Store'a çıkarılması için gereken
adımları sırayla anlatır. Repo tarafındaki hazırlık tamamlandı; kalanlar
makine kurulumu ve imzalama gerektiriyor.

## Durum

| | |
|---|---|
| ✅ Uygulama adı | `FitRehber` (önceden `fitrehber_mobile` görünüyordu) |
| ✅ Launcher ikonu | Marka ikonu, 5 yoğunlukta (önceden varsayılan Flutter logosu) |
| ✅ `applicationId` | `tr.com.fitrehber.fitrehber_mobile` |
| ✅ Sürüm | `1.0.0+2` |
| ✅ İzinler | INTERNET, CAMERA (barkod tarayıcı) — fazlası yok |
| ✅ Deep link | `fitrehber://` şeması (Google OAuth dönüşü) |
| ✅ İmzalama yapılandırması | `build.gradle.kts` hazır, `key.properties` bekliyor |
| ✅ Sır koruması | `key.properties` ve `*.jks` iki `.gitignore`'da da kayıtlı |
| ❌ Android SDK | **kurulu değil** — `flutter doctor` doğruluyor |
| ❌ Keystore | **yok** — üretilmesi gerekiyor |

---

## 1. Android SDK kur

`flutter doctor` şu an şunu diyor:

```
[X] Android toolchain — Unable to locate Android SDK
```

[Android Studio](https://developer.android.com/studio) kur (~2-3 GB). İlk
açılışta SDK bileşenlerini yüklemeyi teklif eder, kabul et. Sonra:

```bash
flutter doctor --android-licenses
flutter doctor
```

`[√] Android toolchain` görene kadar devam etme.

---

## 2. Keystore üret

⚠️ **Bu adımı sen yapmalısın.** İmzalama anahtarı üretmek ve parolasını
saklamak sana ait bir iş.

```bash
keytool -genkey -v -keystore %USERPROFILE%\fitrehber-upload.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sorulan bilgileri doldur, iki parola belirle (store ve key).

### 🔴 Bu dosyayı kaybetme

Play Store'a bir kez yükledikten sonra **aynı anahtarla imzalamayan hiçbir
güncelleme kabul edilmez.** Keystore'u kaybedersen uygulamayı güncelleyemezsin;
yeni bir uygulama olarak yayınlamak zorunda kalırsın ve mevcut kullanıcılar
taşınmaz.

- Keystore'u repo dışında sakla (zaten `.gitignore`'da)
- Parolasıyla birlikte güvenli bir yerde yedekle (parola yöneticisi vb.)
- Play Console'da "Play App Signing" açıksa Google yükleme anahtarını
  sıfırlayabilir; yine de upload keystore'u saklamak şart

---

## 3. `key.properties` oluştur

`android/key.properties` dosyasını şu içerikle oluştur:

```properties
storePassword=<store parolan>
keyPassword=<key parolan>
keyAlias=upload
storeFile=C:/Users/<kullanici>/fitrehber-upload.jks
```

`storeFile` yolunda **ters bölü değil düz bölü** kullan. Bu dosya
`.gitignore`'da, commit edilmeyecek.

Doğrula:

```bash
# key.properties yoksa build debug imzasina duser ve Play kabul etmez
type android\key.properties
```

---

## 4. Release build

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

İmzanın doğru olduğunu kontrol et:

```bash
flutter build apk --release
keytool -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```

Çıktıda kendi sertifika bilgilerini görmelisin. `CN=Android Debug` görüyorsan
`key.properties` okunmamış demektir.

---

## 5. 🔴 Gerçek cihazda soğuk açılış testi — ATLAMA

Bu sürümde besin verisi artık uygulamayla **paketlenmiyor**. Önceden
`assets/data/foods_*.json` içinde ~3.900 besin geliyordu; kaldırıldı çünkü o
kayıtlar gerçek `besin_id` taşımıyordu ve seçildiklerinde öğün kaydı
custom-food yoluna düşüyordu (porsiyon desteklenmiyor, kayıt besin
veritabanından kalıcı kopuk kalıyordu).

Artık tek kaynak sunucu. **Bu akış hiçbir gerçek cihazda denenmedi.**

Test senaryosu:

1. Uygulamayı **temiz kur** (varsa önce kaldır, veri sil)
2. Kayıt ol / giriş yap → onboarding'i tamamla
3. Beslenme ekranını aç
   - "Besin veritabanı hazırlanıyor…" görünmeli
   - Senkron bitince arama çalışmalı
4. Bir besin ara, öğüne ekle → porsiyon seçilebiliyor mu?
5. **Uçak modunu aç**, uygulamayı kapat/aç, tekrar ara
   - Önbellek kalıcı olduğu için arama hâlâ çalışmalı
6. Uygulamayı sil, uçak modundayken tekrar kur ve gir
   - "Besin veritabanı indirilemedi" + "Tekrar dene" görünmeli

Beklenen davranış `lib/features/beslenme/widgets/besin_arama_paneli.dart`
içindeki `_VeritabaniHazirlaniyor` ve `_VeritabaniIndirilemedi` bileşenlerinde.

Senkron `oturum_denetleyici.dart` içinde oturum kurulur kurulmaz tetikleniyor
(beslenme ekranı açılmasını beklemiyor), yani 3. adımda bekleme genelde
görünmeyebilir — bu normal ve istenen.

---

## 6. Play Console

- Uygulama oluştur, `.aab` yükle
- Gizlilik politikası URL'si: yasal sayfalar `WEB` deposunda mevcut
  (`/yasal/gizlilik-politikasi/`)
- Veri güvenliği formu: uygulama e-posta, profil (boy/kilo/hedef) ve beslenme
  kaydı topluyor; kamera yalnız barkod tarama için kullanılıyor ve görüntü
  saklanmıyor
- İçerik derecelendirme anketi
- Kapalı test (internal testing) ile başla, birkaç cihazda doğrula

---

## Sonraki sürümler

`pubspec.yaml` içindeki `version: 1.0.0+2` satırında **build numarası (+N) her
yüklemede artmalı** — Play aynı numarayı ikinci kez kabul etmez.

```
1.0.0+2  →  1.0.1+3  (yama)
         →  1.1.0+3  (özellik)
```
