# FitRehber Mobile - Sinav UI Revizyon Rehberi

Bu not, hocanin canli sinavda arayuz uzerinden isteyebilecegi degisikliklere hizli tepki vermek icin hazirlandi. Mantik basit: once degisikligin hangi ekrana ait oldugunu bul, sonra metin/renk/spacing/widget seviyesinde en kucuk guvenli duzenlemeyi yap.

## 1. Genel Harita

| Hoca ne derse | Ilk bakilacak dosya |
| --- | --- |
| Genel renk, tema, arka plan, buton ana rengi | `lib/core/theme/uygulama_temasi.dart` |
| Alt menudeki sekme adi/ikonu/sirasi | `lib/features/ana_sayfa/ana_sayfa_ekrani.dart` |
| Giris ekranindaki metin, buton, form rengi | `lib/features/kimlik/giris_ekrani.dart` |
| Kayit ekrani | `lib/features/kimlik/kayit_ekrani.dart` |
| Sifremi unuttum ekrani | `lib/features/kimlik/sifremi_unuttum_ekrani.dart` |
| E-posta dogrulama ekrani | `lib/features/kimlik/eposta_dogrulama_ekrani.dart` |
| Onboarding/ilk kurulum | `lib/features/ilk_kurulum/ilk_kurulum_ekrani.dart` |
| Ana sayfa liste/kategori/kartlar | `lib/features/ana_sayfa/ana_sayfa_icerigi.dart` |
| Ana sayfa ve forum ortak kart parcalari | `lib/shared/widgets/icerik_kart_parcalari.dart` |
| Arama ekrani | `lib/features/arama/arama_ekrani.dart` |
| Forum liste ekrani | `lib/features/forum/forum_ekrani.dart` |
| Soru sorma ekrani | `lib/features/forum/soru_sor_ekrani.dart` |
| Makale/icerik detay ekrani | `lib/features/icerik/icerik_ekrani.dart` |
| Makale govde bloklari | `lib/features/icerik/widgets/icerik_blok_cizici.dart` |
| Yorum karti | `lib/features/icerik/widgets/yorum_karti.dart` |
| Yorum yazma cubugu | `lib/features/icerik/widgets/yorum_giris_cubugu.dart` |
| Beslenme ana ekrani | `lib/features/beslenme/beslenme_ekrani.dart` |
| Beslenme ozet/kalan kalori karti | `lib/features/beslenme/widgets/gunluk_ozet_paneli.dart` |
| Ogun kartlari | `lib/features/beslenme/widgets/ogun_bolumu_karti.dart` |
| Besin arama/ogune ekleme paneli | `lib/features/beslenme/widgets/besin_arama_paneli.dart` |
| Su takibi | `lib/features/beslenme/widgets/su_takip_bolumu.dart` |
| AI asistan ana ekran | `lib/features/asistan/asistan_ekrani.dart` |
| AI sohbet balonu | `lib/features/asistan/widgets/sohbet_balonu.dart` |
| AI dusunuyor animasyonu/metni | `lib/features/asistan/widgets/asistan_dusunuyor_gostergesi.dart` |
| Alt menudeki AI ikonu | `lib/shared/widgets/asistan_ikonu.dart` |
| Profil ana ekran/header | `lib/features/profil/profil_ekrani.dart` |
| Profil duzenleme paneli | `lib/features/profil/widgets/profil_duzenleme_paneli.dart` |
| Profil bildirim ayarlari | `lib/features/profil/widgets/bildirim_ayarlari_paneli.dart` |
| Profil icerik sekmeleri | `lib/features/profil/widgets/profil_icerik_sekmeleri.dart` |

## 2. Sinavda Ilk Refleks

1. Hoca hangi ekrani gosteriyorsa dosyayi direkt ac.
2. Degistirilecek sey metinse dosyada metni ara.
3. Degistirilecek sey renkse once `UygulamaTemasi` mi kullaniliyor, yoksa lokal `Color(0x...)` mi ona bak.
4. Degistirilecek sey konum/mesafe ise `padding`, `margin`, `SizedBox`, `Row`, `Column`, `Expanded` ara.
5. Degistirilecek sey kart/buton sekliyse `borderRadius`, `shape`, `BoxDecoration`, `ElevatedButton.styleFrom`, `FilledButton.styleFrom` ara.
6. Degistirilecek sey ikon ise `Icons.` ara.
7. Degisiklikten sonra hizli kontrol:
   - `flutter analyze`
   - Vakit varsa ilgili test veya `flutter test`

## 3. En Muhtemel Canli Revizyonlar

### Profil background rengini degistir

Dosya: `lib/features/profil/profil_ekrani.dart`

Bakilacak yer:

- `_ProfilBasligi`
- `decoration: const BoxDecoration`
- `gradient: LinearGradient`
- `colors: [Color(...), Color(...), Color(...)]`

Ornek cevap:

"Profil ust alanini `_ProfilBasligi` widget'i ciziyor. Background burada `LinearGradient` ile verilmis. Renk degisikligi icin sadece gradient colors listesini degistirmem yeterli."

### Profil avatar halkasinin rengini degistir

Dosya: `lib/features/profil/profil_ekrani.dart`

Bakilacak yer:

- `_ProfilAvatar`
- `gradient: const LinearGradient`
- `boxShadow`

### AI ekranindaki basligi degistir

Dosya: `lib/features/asistan/asistan_ekrani.dart`

Bakilacak yer:

- `AppBar(title: const Text('FitRehber AI'))`

### AI karsilama metnini degistir

Dosya: `lib/features/asistan/asistan_ekrani.dart`

Bakilacak yer:

- `'Merhaba, $name! 👋'`
- `'Hedef: $goalText'`
- `'Bugunku tuketim bilgilerin...'`
- `'Hizli Baslangic'`

### AI hizli soru kartlarini degistir

Dosya: `lib/features/asistan/asistan_ekrani.dart`

Bakilacak yer:

- `_kartlar(String hedef)`
- `_HizliKart(...)`
- `ikon`, `renk`, `soru`

En guvenli yol: Var olan `_HizliKart` satirini kopyala, sadece `ikon`, `renk`, `soru` degistir.

### AI mesaj balonlarini degistir

Dosya: `lib/features/asistan/widgets/sohbet_balonu.dart`

Bakilacak yer:

- `color: message.isUser ? ... : ...`
- `borderRadius`
- `maxWidth: MediaQuery.of(context).size.width * 0.8`
- `MarkdownStyleSheet`

### AI dusunuyor metnini/animasyonunu degistir

Dosya: `lib/features/asistan/widgets/asistan_dusunuyor_gostergesi.dart`

Bakilacak yer:

- `'FitRehber hazirlaniyor'`
- `_BrandPulse`
- `_ThinkingDots`
- `UygulamaTemasi.anaRenk`

### Giris ekranindaki logo/metin/buton rengini degistir

Dosya: `lib/features/kimlik/giris_ekrani.dart`

Bakilacak yer:

- `Icons.fitness_center`
- `'FitRehber'`
- `'Hesabina giris yap'`
- `TextFormField`
- `ElevatedButton.styleFrom`
- `backgroundColor: const Color(0xFFF5A623)`

### Bottom navigation sekme adini veya ikonunu degistir

Dosya: `lib/features/ana_sayfa/ana_sayfa_ekrani.dart`

Bakilacak yer:

- `NavigationBar`
- `NavigationDestination`
- `icon`, `selectedIcon`, `label`

Ornek: "AI Asistan" yazisini "Asistan" yapmak icin sadece ilgili `label` degisir.

### Beslenme ekraninda kalori kartini degistir

Dosya: `lib/features/beslenme/widgets/gunluk_ozet_paneli.dart`

Bakilacak yer:

- `GunlukOzetPaneli`
- `gradient`
- `'Kalan Kalori'`
- `_MiniMakroBar`
- `_MiniHalkaPainter`

### Beslenme ogun kartlarinin renklerini degistir

Dosya: `lib/features/beslenme/widgets/ogun_bolumu_karti.dart`

Bakilacak yer:

- `OgunBolumuKarti`
- `_ogunRengi(String ogunTipi)`
- `_ogunIkonu(String ogunTipi)`
- `_ogunBasligi(String ogunTipi)`

### Su takibi butonlarini degistir

Dosya: `lib/features/beslenme/widgets/su_takip_bolumu.dart`

Bakilacak yer:

- `SuTakipBolumu`
- `_SuButon`
- 250 / 500 / 750 / 1000 ml butonlari

### Forumdaki arama kutusunu veya kategori butonlarini degistir

Dosya: `lib/features/forum/forum_ekrani.dart`

Bakilacak yer:

- `hintText: 'Forumda ara'`
- `_kategoriCubugu`
- `_kategoriButon`
- `_soruKarti`
- `FloatingActionButton`

### Soru sorma ekranindaki baslik veya neon gradient degistir

Dosya: `lib/features/forum/soru_sor_ekrani.dart`

Bakilacak yer:

- `'Topluluga sor'`
- `_NeonTextField`
- `_resimAlani`
- `gradient: const LinearGradient(colors: [...])`

### Arama ekranindaki placeholder/metin/kart degistir

Dosya: `lib/features/arama/arama_ekrani.dart`

Bakilacak yer:

- `hintText: 'Icerik ara...'`
- `'Aramak icin en az 2 harf yaz.'`
- `_sonucKarti`
- `Card`
- `ListTile`

### Makale detayindaki yorum basligi/yazma cubugu degistir

Dosyalar:

- `lib/features/icerik/icerik_ekrani.dart`
- `lib/features/icerik/widgets/yorum_giris_cubugu.dart`
- `lib/features/icerik/widgets/yorum_karti.dart`

Bakilacak yer:

- `_yorumBasligi`
- `YorumGirisCubugu`
- `YorumKarti`

## 4. Degisiklik Tiplerine Gore Mini Tarif

### Renk degistirme

Genel renk ise:

```dart
// lib/core/theme/uygulama_temasi.dart
static const Color anaRenk = Color(0xFFF5A623);
```

Ekrana ozel renk ise:

```dart
const Color(0xFF22D3EE)
```

veya

```dart
colors: [Color(0xFF22D3EE), Color(0xFF6366F1)]
```

aranir.

### Metin degistirme

Komutla hizli bul:

```powershell
rg -n "FitRehber AI|Hizli Baslangic|Profil|Forumda ara" lib
```

Sonra sadece ilgili string degistirilir.

### Bosluk/konum degistirme

Aranacak kelimeler:

- `padding`
- `margin`
- `SizedBox(height: ...)`
- `SizedBox(width: ...)`
- `mainAxisAlignment`
- `crossAxisAlignment`
- `Expanded`

### Kart koselerini degistirme

Aranacak kelimeler:

- `borderRadius: BorderRadius.circular(...)`
- `RoundedRectangleBorder`
- `shape:`

### Buton tasarimini degistirme

Aranacak kelimeler:

- `ElevatedButton.styleFrom`
- `FilledButton.styleFrom`
- `backgroundColor`
- `foregroundColor`
- `padding`
- `shape`

### Yeni kucuk UI parcasi ekleme

En guvenli yol sifirdan buyuk widget yazmak degil, yakin bir yapidan kopyalamak:

- AI karti icin `_HizliKart`
- Profil bilgi satiri icin `_BilgiSatiri`
- Beslenme metrikleri icin `_KaloriMetrik`
- Forum kategori butonu icin `_kategoriButon`

## 5. Sunumda Soylenecek Kisa Teknik Cevaplar

### "Bu rengi nereden degistiriyorsun?"

"Eger genel marka rengi ise `UygulamaTemasi.anaRenk`ten degistiririm. Ama bu ekran profil header gibi ozel bir alan oldugu icin lokal `LinearGradient` renkleri var; sadece o widget'in renk listesini degistirmek daha dogru."

### "Bu yaziyi nereden degistiriyorsun?"

"Bu metin statik bir UI metni. Dosyada string olarak duruyor. Ekran adina gore ilgili dosyaya girip metni degistiriyorum. API'den gelen veri olsaydi model/API tarafina bakmam gerekirdi."

### "Buraya yeni bir buton ekle."

"Mevcut tasarim dilini bozmamak icin ayni ekrandaki mevcut buton stilini kopyalayip yeni aksiyona baglarim. Once gorsel eklerim, sonra fonksiyon gerekiyorsa `onPressed` icini doldururum."

### "Bu ekran neden bozulmadan farkli telefonlarda calisir?"

"Ekranlarda `ListView`, `SingleChildScrollView`, `Expanded`, `Flexible`, `AspectRatio` ve `MediaQuery` kullaniyoruz. Sabit yukseklikte tasma yaratacak yapilari olabildigince sinirladik."

### "Degisiklikten sonra nasil kontrol ediyorsun?"

"Once hot reload ile ekrani kontrol ederim. Sonra kod kalitesi icin `flutter analyze`, vakit varsa ilgili widget/model testleri veya `flutter test` calistiririm."

## 6. Canli Sinavda Paniklememek Icin Kural

Hoca tasarimsal bir degisiklik istediginde bunu 4 siniftan birine koy:

1. Metin degisikligi: exact text ara.
2. Renk degisikligi: `Color`, `gradient`, `UygulamaTemasi` ara.
3. Layout degisikligi: `padding`, `SizedBox`, `Row`, `Column`, `Expanded` ara.
4. Parca ekleme/silme: ilgili ekranda benzer widget'i kopyala.

Bu dort refleks sinavdaki revizyonlarin buyuk cogunu cozer.
