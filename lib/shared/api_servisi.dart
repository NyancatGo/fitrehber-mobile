// ---------------------------------------------------------------------------
// API SERVİSİ
// ---------------------------------------------------------------------------
// Mobil uygulamanın backend ile konuştuğu tek kapı burasıdır.
// Ekranlar doğrudan HTTP isteği atmaz; bu servis JSON'u modele çevirir,
// hataları kullanıcıya uygun Türkçe mesaja indirger ve access token süresi
// dolduğunda isteği bir kez sessizce yeniler.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/api_sabitleri.dart';
import 'api_hatasi.dart';
import 'kimlik_servisi.dart';

export 'api_hatasi.dart';
import 'models/beslenme_model.dart';
import 'models/sohbet_mesaji_model.dart';
import 'models/icerik_model.dart';
import 'models/kategori_model.dart';
import 'models/sayfali_yanit.dart';
import 'models/profil_model.dart';
import 'models/yorum_model.dart';

/// Backend ile konuşan tüm ağ (network) işlemlerinin tek merkezi.
///
/// İçerik, profil, beslenme, yorum ve yapay zekâ uç noktalarına yapılan
/// istekleri kapsar; hata yönetimi ve token yenileme de buradan yürür.
class ApiServisi {
  /// Uygulama genelinde paylaşılan varsayılan API servisi örneği.
  static final ApiServisi instance = ApiServisi();

  ApiServisi({
    Dio? dio,
    FlutterSecureStorage? storage,
    KimlikServisi? kimlikServisi,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               validateStatus: (status) => true,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 30),
               headers: {'Accept': 'application/json'},
             ),
           ),
       _storage = storage ?? const FlutterSecureStorage(),
       _kimlikServisi = kimlikServisi ?? KimlikServisi.instance {
    // onRequest: tokenin omru dolmak uzereyse istek ATILMADAN once yenilenir
    // (proaktif yenileme). onResponse: 401 gelirse bir kez sessizce yeniler.
    // Basarisiz olursa 401 ust katmana doner, oturum kapatma kararini UI/state verir.
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onResponse: _onResponse),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final KimlikServisi _kimlikServisi;

  /// Proaktif token yenileme: access tokenin omru dolmak uzereyse istek
  /// gonderilmeden once yenilenir.
  ///
  /// Onceki davranista her uygulama acilisinda ilk istek 401 aliyor, sonra
  /// yenileme yapiliyor ve istek tekrarlaniyordu (gereksiz tur + gecikme).
  /// Sure bilinmiyorsa hicbir sey yapilmaz — o durumda 401 interceptor'i
  /// devreye girer.
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (!options.path.contains('/auth/')) {
        await _kimlikServisi.accessTokenGerekiyorsaYenile();
      }
    } catch (_) {
      // Yenileme basarisiz olursa istek yine de atilsin; 401 interceptor'i
      // ikinci sansi verecek.
    }
    handler.next(options);
  }

  /// 401 yanıtı gelince access token'ı yenileyip isteği bir kez tekrar dener.
  ///
  /// `validateStatus: (_) => true` nedeniyle 401 bir `DioException` değil,
  /// normal `Response` olarak gelir. `__token_retried` sonsuz döngüyü engeller.
  Future<void> _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode != 401) {
      handler.next(response);
      return;
    }

    final reqOpts = response.requestOptions;
    // Zaten yenilenmiş istek veya auth uç noktası için tekrar deneme.
    if (reqOpts.extra['__token_retried'] == true ||
        reqOpts.path.contains('/auth/')) {
      handler.next(response);
      return;
    }

    final refreshed = await _kimlikServisi.accessTokenYenile();
    if (!refreshed) {
      handler.next(response);
      return;
    }

    final newToken = await _storage.read(key: 'access_token');
    if (newToken == null || newToken.isEmpty) {
      handler.next(response);
      return;
    }

    reqOpts.headers['Authorization'] = 'Bearer $newToken';
    reqOpts.extra['__token_retried'] = true;
    try {
      final retry = await _dio.fetch<dynamic>(reqOpts);
      handler.resolve(retry);
    } catch (_) {
      // Yeniden deneme ağ/multipart gibi sebeplerle düşerse orijinal 401 korunur.
      handler.next(response);
    }
  }

  /// Tüm içerik kategorilerini getirir.
  Future<List<KategoriModel>> kategorileriGetir() async {
    final response = await _dio.get(ApiSabitleri.kategoriler);
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((e) => KategoriModel.fromJson(e))
          .toList();
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Kategoriler yüklenemedi.',
    );
  }

  /// Makale/içerik listesini sayfalı biçimde getirir.
  ///
  /// İsteğe bağlı [kategoriId], [tur] ve [arama] parametreleriyle sonuçlar
  /// filtrelenebilir; [page] ile istenen sayfa belirtilir.
  Future<SayfaliYanit<IcerikModel>> icerikleriGetir({
    int? kategoriId,
    String? tur,
    String? arama,
    int? page,
    int pageSize = ApiSabitleri.pageSize,
  }) async {
    final response = await _dio.get(
      ApiSabitleri.icerikler,
      queryParameters: {
        'kategori': ?kategoriId,
        if (tur != null && tur.isNotEmpty) 'tur': tur,
        if (arama != null && arama.isNotEmpty) 'search': arama,
        'page': ?page,
        'page_size': pageSize,
      },
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, IcerikModel.fromJson);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Makaleler yüklenemedi.',
    );
  }

  /// API yanıtı düz liste ([...]) veya sayfalı ({results: [...]}) olabilir;
  /// sayfalama bilgisini kaybetmeden tek modele indirger.
  SayfaliYanit<T> _sayfaliYanitaCevir<T>(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return SayfaliYanit<T>.fromJson(data, fromJson);
  }

  /// Tek bir makalenin/içeriğin tüm detayını getirir.
  Future<IcerikModel> icerikDetayiniGetir(int id) async {
    final response = await _dio.get('${ApiSabitleri.icerikler}$id/');
    if (response.statusCode == 200) {
      return IcerikModel.fromJson(response.data);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Makale yüklenemedi.',
    );
  }

  /// Bir içeriğe ait yorumları getirir.
  ///
  /// [onlyRoots] yalnızca kök yorumları, [odakId] belirli bir yorumu öne
  /// çıkararak, [depthLimit] ise kaç seviye yanıtın çekileceğini belirler.
  Future<List<YorumModel>> yorumlariGetir(
    int icerikId, {
    bool onlyRoots = false,
    int? odakId,
    int depthLimit = 2,
  }) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      ApiSabitleri.yorumlar(icerikId),
      queryParameters: {
        'page_size': 200,
        'depth_limit': depthLimit,
        'odak': ?odakId,
        if (onlyRoots) 'only_roots': 'true',
      },
      options: (token != null && token.isNotEmpty)
          ? _kimlikSecenekleri(token)
          : null,
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, YorumModel.fromJson).sonuclar;
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Yorumlar yüklenemedi.',
    );
  }

  /// Belirli bir yoruma verilen direkt yanıtları gerektiğinde yükler.
  Future<List<YorumModel>> yanitlariGetir(int yorumId) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      ApiSabitleri.yorumYanitlari(yorumId),
      options: (token != null && token.isNotEmpty)
          ? _kimlikSecenekleri(token)
          : null,
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, YorumModel.fromJson).sonuclar;
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Yanıtlar yüklenemedi.',
    );
  }

  /// Bir içeriğe yeni yorum ekler.
  ///
  /// [parentId] verilirse yorum, o yoruma verilen bir yanıt olur; verilmezse
  /// kök (üst düzey) yorum olarak eklenir.
  Future<YorumModel> yorumEkle(
    int icerikId, {
    required String mesaj,
    int? parentId,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Yorum yazmak icin giris yapmalisin.',
    );
    final response = await _dio.post(
      ApiSabitleri.yorumlar(icerikId),
      data: {'mesaj': mesaj, 'parent': ?parentId},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 201 && response.data is Map) {
      return YorumModel.fromJson(Map<String, dynamic>.from(response.data));
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Yorum yazmak icin giris yapmalisin.',
      defaultMessage: 'Yorum gonderilemedi.',
    );
  }

  /// Foruma yeni bir soru/içerik gönderir.
  ///
  /// İsteğe bağlı [resim] varsa istek `multipart/form-data` olarak yollanır.
  Future<IcerikModel> soruSor({
    required String baslik,
    required String yazi,
    required int kategoriId,
    XFile? resim,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Soru sormak icin giris yapmalisin.',
    );
    final formData = FormData.fromMap({
      'baslik': baslik,
      'yazi': yazi,
      'kategori': kategoriId,
      if (resim != null)
        'resim': MultipartFile.fromBytes(
          await resim.readAsBytes(),
          filename: resim.name,
        ),
    });
    final response = await _dio.post(
      ApiSabitleri.icerikler,
      data: formData,
      options: _kimlikSecenekleri(token, multipart: true),
    );
    if (response.statusCode == 201 && response.data is Map) {
      return IcerikModel.fromJson(Map<String, dynamic>.from(response.data));
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Soru sormak icin giris yapmalisin.',
      defaultMessage: 'Soru paylasilamadi.',
    );
  }

  /// Bir yorumun beğenisini açar/kapatır. Dönen harita: `{begendim, begeni_sayisi}`.
  Future<Map<String, dynamic>> yorumBegenisiniDegistir(int yorumId) async {
    final token = await _accessTokenYoksaHataVer(
      'Beğenmek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.yorumBegen(yorumId),
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Beğenmek için giriş yapmalısın.',
      defaultMessage: 'Beğeni işlemi başarısız.',
    );
  }

  /// Bir içeriğin beğenisini açar/kapatır. Dönen harita: `{begendim, begeni_sayisi}`.
  Future<Map<String, dynamic>> icerikBegenisiniDegistir(int icerikId) async {
    final token = await _accessTokenYoksaHataVer(
      'Begenmek icin giris yapmalisin.',
    );
    final response = await _dio.post(
      ApiSabitleri.icerikBegen(icerikId),
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Begenmek icin giris yapmalisin.',
      defaultMessage: 'Begeni islemi basarisiz.',
    );
  }

  /// Bir içeriği kaydetme durumunu açar/kapatır (yer imi ekler/kaldırır).
  Future<Map<String, dynamic>> icerikKaydiniDegistir(int icerikId) async {
    final token = await _accessTokenYoksaHataVer(
      'Kaydetmek icin giris yapmalisin.',
    );
    final response = await _dio.post(
      ApiSabitleri.icerikKaydet(icerikId),
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Kaydetmek icin giris yapmalisin.',
      defaultMessage: 'Kaydetme islemi basarisiz.',
    );
  }

  /// Bir içeriği siler (yalnızca yetkili kullanıcı).
  Future<void> icerikSil(int icerikId) async {
    final token = await _accessTokenYoksaHataVer(
      'Bu islem icin giris yapmalisin.',
    );
    final response = await _dio.delete(
      '${ApiSabitleri.icerikler}$icerikId/',
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 204) return;
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Bu islem icin giris yapmalisin.',
      defaultMessage: 'Icerik silinemedi.',
    );
  }

  /// Bir yorumu siler (yalnızca yorumu yazan veya yetkili kullanıcı).
  Future<void> yorumSil(int yorumId) async {
    final token = await _accessTokenYoksaHataVer(
      'Bu islem icin giris yapmalisin.',
    );
    final response = await _dio.delete(
      ApiSabitleri.yorumDetay(yorumId),
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 204) return;
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Bu islem icin giris yapmalisin.',
      defaultMessage: 'Yorum silinemedi.',
    );
  }

  /// Kimliği verilen kullanıcının profilini getirir.
  Future<ProfilModel> idIleProfilGetir(int userId) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      ApiSabitleri.profilDetay(userId),
      options: (token != null && token.isNotEmpty)
          ? _kimlikSecenekleri(token)
          : null,
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return ProfilModel.fromJson(response.data as Map<String, dynamic>);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil bilgileri alınamadı.',
    );
  }

  /// Bir kullanıcının paylaştığı içerikleri sayfalı biçimde getirir.
  Future<SayfaliYanit<IcerikModel>> profilIcerikleriniGetir(
    int userId, {
    int? page,
    int pageSize = ApiSabitleri.pageSize,
  }) async {
    final response = await _dio.get(
      ApiSabitleri.profilIcerikleri(userId),
      queryParameters: {'page': ?page, 'page_size': pageSize},
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, IcerikModel.fromJson);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Paylaşımlar yüklenemedi.',
    );
  }

  /// Bir kullanıcının kaydettiği içerikleri sayfalı biçimde getirir.
  Future<SayfaliYanit<IcerikModel>> profilKaydedilenleriGetir(
    int userId, {
    int? page,
    int pageSize = ApiSabitleri.pageSize,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Kaydedilenleri görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiSabitleri.profilKaydedilenler(userId),
      queryParameters: {'page': ?page, 'page_size': pageSize},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, IcerikModel.fromJson);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Kaydedilenler yüklenemedi.',
    );
  }

  /// Bir kullanıcının beğendiği yorumları sayfalı biçimde getirir.
  Future<SayfaliYanit<YorumOzetModel>> profilBegenileriniGetir(
    int userId, {
    int? page,
    int pageSize = ApiSabitleri.pageSize,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Beğenilenleri görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiSabitleri.profilBegeniler(userId),
      queryParameters: {'page': ?page, 'page_size': pageSize},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, YorumOzetModel.fromJson);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Beğenilenler yüklenemedi.',
    );
  }

  /// Oturum açan kullanıcının kendi profilini getirir.
  ///
  /// Kendi profilim ucu kullanılır: kullanıcı id URL'de değil, sunucu
  /// JWT'den belirliyor. Önceden istemci JWT'yi çözüp id çıkarıyordu; bu
  /// hem istemciyi JWT iç yapısına bağımlı kılıyordu hem de claim şekli
  /// değişince sessizce bozuluyordu.
  ///
  /// İlk kurulum bitmediyse boş profil döner; ad/soyad önbellekten taşınır.
  Future<ProfilModel> profiliGetir() async {
    final token = await _accessTokenYoksaHataVer(
      'Profilini görmek için giriş yapmalısın.',
    );
    final cachedProfile = await _onbellektekiProfiliOku();

    final response = await _dio.get(
      ApiSabitleri.profil,
      options: _kimlikSecenekleri(token),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final rawProfile = ProfilModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      final profile = rawProfile.copyWith(
        email: rawProfile.email.isEmpty ? cachedProfile?.email : null,
        firstName: rawProfile.firstName.isEmpty
            ? cachedProfile?.firstName
            : null,
        lastName: rawProfile.lastName.isEmpty ? cachedProfile?.lastName : null,
      );
      await _profiliOnbellegeYaz(profile);
      return profile;
    }

    if (response.statusCode == 404 || _ilkKurulumGerekliMi(response.data)) {
      // İlk kurulum tamamlanmamışsa Google'dan gelen ad/soyad kaybolmasın;
      // boş profil oluştururken önbellekteki kullanıcı bilgisini taşırız.
      final profile = ProfilModel.empty(
        id: cachedProfile?.id ?? 0,
        username: cachedProfile?.username,
        email: cachedProfile?.email ?? '',
        firstName: cachedProfile?.firstName ?? '',
        lastName: cachedProfile?.lastName ?? '',
      );
      await _profiliOnbellegeYaz(profile);
      return profile;
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil bilgileri alınamadı.',
    );
  }

  /// Oturum açan kullanıcının profil bilgilerini günceller.
  Future<ProfilModel> profiliGuncelle(Map<String, dynamic> data) async {
    final token = await _accessTokenYoksaHataVer(
      'Profilini güncellemek için giriş yapmalısın.',
    );

    final cleanedData = Map<String, dynamic>.from(data)
      ..removeWhere(
        (key, value) =>
            value == null && !{'boy', 'kilo', 'hedef_kilo'}.contains(key),
      );
    cleanedData.remove('dogum_tarihi');

    final response = await _dio.patch(
      ApiSabitleri.profil,
      data: cleanedData,
      options: _kimlikSecenekleri(token),
    );

    if ((response.statusCode == 200 || response.statusCode == 202) &&
        response.data is Map<String, dynamic>) {
      final profile = ProfilModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _profiliOnbellegeYaz(profile);
      return profile;
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil güncellenemedi.',
    );
  }

  /// Kullanıcının profil fotoğrafını yükler/günceller.
  Future<ProfilModel> profilFotoYukle(XFile foto) async {
    final token = await _accessTokenYoksaHataVer(
      'Profil fotografini guncellemek icin giris yapmalisin.',
    );
    final response = await _dio.patch(
      ApiSabitleri.profil,
      data: FormData.fromMap({
        'foto': MultipartFile.fromBytes(
          await foto.readAsBytes(),
          filename: foto.name,
        ),
      }),
      options: _kimlikSecenekleri(token, multipart: true),
    );

    if ((response.statusCode == 200 || response.statusCode == 202) &&
        response.data is Map<String, dynamic>) {
      final profile = ProfilModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _profiliOnbellegeYaz(profile);
      return profile;
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum suren dolmus. Lutfen tekrar giris yap.',
      defaultMessage: 'Profil fotografi guncellenemedi.',
    );
  }

  /// İlk kurulum adımındaki profil bilgilerini kaydeder.
  Future<ProfilModel> ilkKurulumuTamamla(Map<String, dynamic> data) async {
    final token = await _accessTokenYoksaHataVer(
      'Profil kurulumunu tamamlamak için giriş yapmalısın.',
    );

    final response = await _dio.patch(
      ApiSabitleri.profilOnboard,
      data: data,
      options: _kimlikSecenekleri(token),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final profile = ProfilModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _profiliOnbellegeYaz(profile);
      return profile;
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil kurulumu tamamlanamadı.',
    );
  }

  /// Verilen tarihin günlük beslenme ve su takibi özetini getirir.
  Future<GunlukBeslenmeModel> beslenmeSuyuGetir(String tarih) async {
    final token = await _accessTokenYoksaHataVer(
      'Beslenme verilerini görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiSabitleri.beslenmeSu,
      queryParameters: {'tarih': tarih},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return GunlukBeslenmeModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Beslenme verisi yüklenemedi.',
    );
  }

  /// Besin veritabanında metne göre arama yapar.
  Future<List<BesinModel>> besinAra(String sorgu) async {
    final token = await _accessTokenYoksaHataVer(
      'Besin aramak için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiSabitleri.besinler,
      queryParameters: {'q': sorgu},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .whereType<Map>()
          .map((item) => BesinModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Besin araması yapılamadı.',
    );
  }

  /// Offline/cache aramasında zayıf veya boş sonuç oluştuğunu sessizce bildirir.
  Future<void> besinAramaLoguGonder({
    required String query,
    required int resultCount,
  }) async {
    final temizQuery = query.trim();
    if (temizQuery.isEmpty) return;

    final token = await _accessTokenYoksaHataVer(
      'Besin arama sinyali göndermek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.besinlerAramaLog,
      data: {
        'query': temizQuery,
        'result_count': resultCount,
        'source': 'mobile',
      },
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 201 ||
        response.statusCode == 204 ||
        response.statusCode == 429) {
      return;
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Besin arama sinyali gönderilemedi.',
    );
  }

  /// Kullanıcının 100 g referanslı besin önerisini moderasyon kuyruğuna yollar.
  Future<Map<String, dynamic>> besinKatkiGonder({
    required String isim,
    required int kalori100g,
    required double protein100g,
    required double karbonhidrat100g,
    required double yag100g,
    String? marka,
    String? barkod,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Besin önerisi göndermek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.besinlerKatki,
      data: {
        'isim': isim.trim(),
        if (marka != null && marka.trim().isNotEmpty) 'marka': marka.trim(),
        if (barkod != null && barkod.trim().isNotEmpty) 'barkod': barkod.trim(),
        'kalori_100g': kalori100g,
        'protein_100g': protein100g,
        'karbonhidrat_100g': karbonhidrat100g,
        'yag_100g': yag100g,
      },
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 201 && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Besin önerisi gönderilemedi.',
    );
  }

  /// Barkodu sunucuda sorgular. Sunucu önce DB'ye, yoksa OpenFoodFacts'a bakar.
  Future<Map<String, dynamic>> besinBarkodSorgula(String barkod) async {
    final token = await _accessTokenYoksaHataVer(
      'Barkod sorgulamak için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.besinlerBarkodSorgula,
      data: {'barkod': barkod.trim()},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Barkod sorgulanamadı.',
    );
  }

  /// Sunucudaki besin veritabanını senkronlamak için TEK sayfa çeker.
  ///
  /// [since] verilirse yalnız o andan sonra değişen besinler döner (delta);
  /// boşsa tüm veritabanı (ilk tam senkron). Dönen map:
  /// `{ foods: List<Map>, serverTime: String?, hasMore: bool, count: int }`.
  Future<Map<String, dynamic>> besinSenkronSayfasi({
    String? since,
    int offset = 0,
    int limit = 1000,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Besinleri senkronlamak için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiSabitleri.besinlerSync,
      queryParameters: {
        if (since != null && since.isNotEmpty) 'since': since,
        'offset': offset,
        'limit': limit,
      },
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map) {
      final data = Map<String, dynamic>.from(response.data as Map);
      final foods = (data['results'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return {
        'foods': foods,
        'serverTime': data['server_time']?.toString(),
        'hasMore': data['has_more'] == true,
        'count': (data['count'] as num?)?.toInt() ?? foods.length,
      };
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Besin senkronu yapılamadı.',
    );
  }

  /// Bir öğüne yeni besin kaydı ekler.
  Future<void> ogunEkle({
    required String tarih,
    required String ogunTipi,
    int? besinId,
    String? besinIsim,
    required double miktar,
    int kalori = 0,
    double protein = 0,
    double karbonhidrat = 0,
    double yag = 0,
    int? porsiyonId,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Öğün eklemek için giriş yapmalısın.',
    );
    // Bu uç nokta ya `besin_id` ya da `besin_isim` bekler; null alan göndermek
    // backend'in XOR validasyonunda gereksiz 400 hatası üretebilir.
    final payload = <String, dynamic>{
      'tarih': tarih,
      'ogun_tipi': ogunTipi,
      'miktar': miktar,
      'kalori': kalori,
      'protein': protein,
      'karbonhidrat': karbonhidrat,
      'yag': yag,
      'porsiyon_id': porsiyonId,
    };
    if (besinId != null) payload['besin_id'] = besinId;
    if (besinIsim != null && besinIsim.trim().isNotEmpty) {
      payload['besin_isim'] = besinIsim.trim();
    }

    final response = await _dio.post(
      ApiSabitleri.beslenmeEkle,
      data: payload,
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 201 || response.statusCode == 200) return;
    if (kDebugMode) {
      debugPrint('[ogunEkle] FAIL ${response.statusCode}');
      debugPrint('[ogunEkle] body=${response.data}');
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Öğün eklenemedi.',
    );
  }

  /// Bir öğün kaydını siler.
  Future<void> ogunSil(int id) async {
    final token = await _accessTokenYoksaHataVer(
      'Öğün silmek için giriş yapmalısın.',
    );
    final response = await _dio.delete(
      ApiSabitleri.beslenmeSil(id),
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 204) return;
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Öğün silinemedi.',
    );
  }

  /// Tek atomic PATCH ile öğün miktarını günceller.
  ///
  /// Doğrulanmış besinde makrolar sunucuda yeniden hesaplanır; özel besin için
  /// istemci makro göndermezse sunucu eski değeri yeni miktara göre ölçekler.
  Future<void> ogunGuncelle({
    required int id,
    required double miktar,
    int? kalori,
    double? protein,
    double? karbonhidrat,
    double? yag,
    int? porsiyonId,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Öğün güncellemek için giriş yapmalısın.',
    );
    final payload = <String, dynamic>{
      'miktar': miktar,
      'porsiyon_id': porsiyonId,
    };
    if (kalori != null) payload['kalori'] = kalori;
    if (protein != null) payload['protein'] = protein;
    if (karbonhidrat != null) payload['karbonhidrat'] = karbonhidrat;
    if (yag != null) payload['yag'] = yag;

    final response = await _dio.patch(
      ApiSabitleri.beslenmeGuncelle(id),
      data: payload,
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200) return;
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Öğün güncellenemedi.',
    );
  }

  /// Verilen tarihe içilen su miktarını (ml) ekler.
  Future<GunlukBeslenmeModel> suEkle({
    required String tarih,
    required int miktarMl,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Su eklemek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.beslenmeSu,
      data: {'tarih': tarih, 'su_ml': miktarMl},
      options: _kimlikSecenekleri(token),
    );
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        response.data is Map<String, dynamic>) {
      return GunlukBeslenmeModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    if (kDebugMode) {
      debugPrint('[suEkle] FAIL ${response.statusCode}');
      debugPrint('[suEkle] body=${response.data}');
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Su eklenemedi.',
    );
  }

  /// Bir önceki günün öğünlerini seçili (boş) güne kopyalar. Kopyalanan kayıt
  /// sayısını döner; hata (kaynak boş / hedef dolu / gelecek) durumunda fırlatır.
  Future<int> ogunleriKopyala(String tarih) async {
    final token = await _accessTokenYoksaHataVer(
      'Öğün kopyalamak için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.beslenmeKopyala,
      data: {'tarih': tarih},
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 201 && response.data is Map) {
      final data = Map<String, dynamic>.from(response.data as Map);
      return (data['kopyalanan'] as num?)?.toInt() ?? 0;
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Öğünler kopyalanamadı.',
    );
  }

  /// Kullanıcının son kullandığı benzersiz besinleri (hızlı yeniden ekleme)
  /// ham map listesi olarak döner: { besin_id, isim, miktar, kalori, ... }.
  Future<List<Map<String, dynamic>>> sonKullanilanBesinler() async {
    final token = await _accessTokenYoksaHataVer(
      'Son besinleri görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiSabitleri.sonBesinler,
      options: _kimlikSecenekleri(token),
    );
    if (response.statusCode == 200 && response.data is Map) {
      final data = Map<String, dynamic>.from(response.data as Map);
      return (data['sonuclar'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Son besinler alınamadı.',
    );
  }

  /// Verilen tarihe doğrudan kalori ve makro besin değeri ekler.
  Future<GunlukBeslenmeModel> kaloriEkle({
    required String tarih,
    required int kaloriKcal,
    double proteinG = 0,
    double karbonhidratG = 0,
    double yagG = 0,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'Kalori eklemek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiSabitleri.beslenmeSu,
      data: {
        'tarih': tarih,
        'kalori_kcal': kaloriKcal,
        'protein_g': proteinG,
        'karbonhidrat_g': karbonhidratG,
        'yag_g': yagG,
      },
      options: _kimlikSecenekleri(token),
    );
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        response.data is Map<String, dynamic>) {
      return GunlukBeslenmeModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Kalori eklenemedi.',
    );
  }

  /// Yapay zekâ asistanına mesaj gönderir ve yanıtla birlikte önerilen
  /// takip sorularını (`suggestions`) ve kullanılan veri etiketlerini
  /// (`contextTags`) döndürür.
  Future<AsistanYanitModel> asistanaDetayliSor({
    required String message,
    required List<SohbetMesajiModel> history,
    String? clientContext,
  }) async {
    final token = await _accessTokenYoksaHataVer(
      'AI Asistan için giriş yapmalısın.',
    );

    final payload = <String, dynamic>{
      'message': message,
      'history': history.map((m) => m.toApiJson()).toList(),
    };
    if (clientContext != null && clientContext.trim().isNotEmpty) {
      payload['client_context'] = clientContext.trim();
    }

    final response = await _dio.post(
      ApiSabitleri.aiChat,
      data: payload,
      options: _kimlikSecenekleri(token),
    );

    if (response.statusCode == 200 && response.data is Map) {
      final map = Map<String, dynamic>.from(response.data as Map);
      final parsed = AsistanYanitModel.fromJson(map);
      if (parsed.answer.isNotEmpty) return parsed;
      throw 'Backend boş cevap döndü.';
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'AI Asistan için giriş yapmalısın.',
      rateLimitMessage:
          'Çok kısa sürede fazla soru sordun. Lütfen biraz bekleyip tekrar dene.',
      defaultMessage: 'AI cevabı alınamadı.',
    );
  }

  /// Yapay zekâ asistanına bir mesaj gönderir ve cevabını döndürür.
  ///
  /// [history] önceki sohbet mesajlarıdır; asistanın bağlamı koruması için
  /// her istekte birlikte gönderilir.
  Future<String> asistanaSor({
    required String message,
    required List<SohbetMesajiModel> history,
    String? clientContext,
  }) async {
    final yanit = await asistanaDetayliSor(
      message: message,
      history: history,
      clientContext: clientContext,
    );
    return yanit.answer;
  }

  /// AI asistan yanıtı için 👍/👎 değerlendirmesi veya eylem kartı uygulama
  /// sinyali gönderir. Hata durumunda akışı bozmamak için `false` döner.
  Future<bool> asistanGeriBildirimGonder({
    required String messageId,
    String? rating,
    String? reason,
    bool actionApplied = false,
  }) async {
    if (messageId.trim().isEmpty) return false;
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null || token.trim().isEmpty) return false;

      final response = await _dio.post(
        ApiSabitleri.aiFeedback,
        data: {
          'message_id': messageId.trim(),
          if (rating != null && rating.isNotEmpty) 'rating': rating,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (actionApplied) 'action_applied': true,
        },
        options: _kimlikSecenekleri(token),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ProfilModel?> _onbellektekiProfiliOku() async {
    final rawUser = await _storage.read(key: 'current_user');
    if (rawUser == null || rawUser.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return ProfilModel.fromJson(decoded);
      }
      if (decoded is Map) {
        return ProfilModel.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  bool _ilkKurulumGerekliMi(dynamic data) {
    if (data is! Map) return false;
    final code = data['code']?.toString();
    if (code == 'onboarding_required') return true;
    final detail = data['detail'];
    if (detail is Map) {
      return detail['code']?.toString() == 'onboarding_required';
    }
    return false;
  }

  Future<void> _profiliOnbellegeYaz(ProfilModel profile) async {
    await _storage.write(
      key: 'current_user',
      value: jsonEncode({
        'id': profile.id,
        'username': profile.username,
        'email': profile.email,
        'first_name': profile.firstName,
        'last_name': profile.lastName,
        'is_staff': profile.isStaff,
        'is_superuser': profile.isSuperuser,
        'is_onboarded': profile.isOnboarded,
      }),
    );
  }

  // NOT: `_tokendenKullaniciIdOku` KALDIRILDI.
  // Kendi profilimize ulasmak icin JWT'yi istemcide cozup `user_id`
  // cikarmaya gerek kalmadi: artik `GET /api/profil/` ucu kimligi
  // dogrudan sunucudan aliyor. Boylece istemci, SimpleJWT claim
  // yapisina (user_id/id/sub) bagimli olmaktan kurtuldu.

  /// Güvenli depoda access token yoksa 401 eşdeğeri bir [ApiHatasi] fırlatır.
  ///
  /// Düz `String` fırlatmak, çevrimdışı kuyruğun bu durumu "kalıcı veri
  /// hatası" sanıp bekleyen öğünleri düşürmesine yol açıyordu. Oturum yokluğu
  /// geçici bir durumdur: kullanıcı tekrar giriş yapınca işlem gönderilebilir.
  Future<String> _accessTokenYoksaHataVer(String message) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw ApiHatasi(message, statusCode: 401);
    }
    return token;
  }

  Options _kimlikSecenekleri(String token, {bool multipart = false}) {
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        if (!multipart) 'Content-Type': 'application/json',
      },
    );
  }

  static const Map<String, String> _alanEtiketleri = {
    'baslik': 'Başlık',
    'yazi': 'İçerik',
    'mesaj': 'Yorum',
    'kategori': 'Kategori',
    'miktar': 'Miktar',
    'tarih': 'Tarih',
    'ogun_tipi': 'Öğün',
    'besin_isim': 'Besin adı',
    'kalori': 'Kalori',
    'kalori_100g': 'Kalori (100g)',
    'protein_100g': 'Protein (100g)',
    'karbonhidrat_100g': 'Karbonhidrat (100g)',
    'yag_100g': 'Yağ (100g)',
    'su_ml': 'Su miktarı',
    'boy': 'Boy',
    'height': 'Boy',
    'kilo': 'Kilo',
    'weight': 'Kilo',
    'hedef_kilo': 'Hedef kilo',
    'target_weight': 'Hedef kilo',
    'dogum_tarihi': 'Doğum tarihi',
    'birth_date': 'Doğum tarihi',
    'fitness_hedefi': 'Hedef',
    'goal': 'Hedef',
    'cinsiyet': 'Cinsiyet',
    'gender': 'Cinsiyet',
    'username': 'Kullanıcı adı',
    'email': 'E-posta',
    'password': 'Şifre',
    'foto': 'Fotoğraf',
    'resim': 'Görsel',
  };

  /// Başarısız yanıtı, HTTP durum kodunu taşıyan tipli bir [ApiHatasi]'na çevirir.
  ///
  /// Durum kodu korunduğu için üst katmanlar (ör. çevrimdışı outbox) geçici
  /// (401/429/5xx) ve kalıcı (400/403/404 ...) hataları metin eşleştirmesi
  /// yapmadan ayırt edebilir.
  ApiHatasi _hataAyikla(
    dynamic data,
    int? statusCode, {
    required String unauthorizedMessage,
    required String defaultMessage,
    String? rateLimitMessage,
  }) {
    return ApiHatasi(
      _hataMesajiOlustur(
        data,
        statusCode,
        unauthorizedMessage: unauthorizedMessage,
        defaultMessage: defaultMessage,
        rateLimitMessage: rateLimitMessage,
      ),
      statusCode: statusCode,
    );
  }

  String _hataMesajiOlustur(
    dynamic data,
    int? statusCode, {
    required String unauthorizedMessage,
    required String defaultMessage,
    String? rateLimitMessage,
  }) {
    if (statusCode == 401) return unauthorizedMessage;
    if (statusCode == 429 && rateLimitMessage != null) {
      return rateLimitMessage;
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final detail =
          map['detail'] ??
          map['hata'] ??
          map['message'] ??
          map['error'] ??
          map['non_field_errors'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail is List ? detail.join(' ') : detail.toString();
      }
      // DRF alan hatalarını Türkçe alan etiketleriyle tek okunabilir mesaja indiriyoruz.
      final fieldErrors = map.entries
          .where((e) => e.value != null)
          .map((e) {
            final v = e.value;
            final msg = v is List ? v.join(', ') : v.toString();
            final etiket = _alanEtiketleri[e.key] ?? e.key;
            return '$etiket: $msg';
          })
          .join(' | ');
      if (fieldErrors.isNotEmpty) {
        return '$defaultMessage ($fieldErrors)';
      }
    }

    return '$defaultMessage (Hata: $statusCode)';
  }
}
