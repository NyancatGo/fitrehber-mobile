import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/api_constants.dart';
import 'models/beslenme_model.dart';
import 'models/chat_message_model.dart';
import 'models/icerik_model.dart';
import 'models/kategori_model.dart';
import 'models/paginated_response.dart';
import 'models/profil_model.dart';
import 'models/yorum_model.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      validateStatus: (status) => true,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<KategoriModel>> getKategoriler() async {
    final response = await _dio.get(ApiConstants.kategoriler);
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

  Future<PaginatedResponse<IcerikModel>> getIcerikler({
    int? kategoriId,
    String? tur,
    String? arama,
    int? page,
    int pageSize = ApiConstants.pageSize,
  }) async {
    final response = await _dio.get(
      ApiConstants.icerikler,
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
  PaginatedResponse<T> _sayfaliYanitaCevir<T>(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return PaginatedResponse<T>.fromJson(data, fromJson);
  }

  Future<IcerikModel> getIcerikDetay(int id) async {
    final response = await _dio.get('${ApiConstants.icerikler}$id/');
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

  Future<List<YorumModel>> getYorumlar(
    int icerikId, {
    bool onlyRoots = false,
    int? odakId,
    int depthLimit = 2,
  }) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      ApiConstants.yorumlar(icerikId),
      queryParameters: {
        'page_size': 200,
        'depth_limit': depthLimit,
        'odak': ?odakId,
        if (onlyRoots) 'only_roots': 'true',
      },
      options: (token != null && token.isNotEmpty) ? _authOptions(token) : null,
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, YorumModel.fromJson).results;
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Yorumlar yüklenemedi.',
    );
  }

  /// Belirli bir yoruma verilen direkt yanıtları getirir (lazy load için).
  Future<List<YorumModel>> getYanitlar(int yorumId) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      ApiConstants.yorumYanitlari(yorumId),
      options: (token != null && token.isNotEmpty) ? _authOptions(token) : null,
    );
    if (response.statusCode == 200) {
      return _sayfaliYanitaCevir(response.data, YorumModel.fromJson).results;
    }
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş.',
      defaultMessage: 'Yanıtlar yüklenemedi.',
    );
  }

  /// Yorum beğenisini açar/kapatır. Dönen map: {begendim, begeni_sayisi}.
  Future<YorumModel> yorumEkle(
    int icerikId, {
    required String mesaj,
    int? parentId,
  }) async {
    final token = await _accessTokenOrThrow(
      'Yorum yazmak icin giris yapmalisin.',
    );
    final response = await _dio.post(
      ApiConstants.yorumlar(icerikId),
      data: {'mesaj': mesaj, 'parent': ?parentId},
      options: _authOptions(token),
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

  Future<IcerikModel> soruSor({
    required String baslik,
    required String yazi,
    required int kategoriId,
    XFile? resim,
  }) async {
    final token = await _accessTokenOrThrow(
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
      ApiConstants.icerikler,
      data: formData,
      options: _authOptions(token, multipart: true),
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

  Future<Map<String, dynamic>> toggleYorumBegeni(int yorumId) async {
    final token = await _accessTokenOrThrow('Beğenmek için giriş yapmalısın.');
    final response = await _dio.post(
      ApiConstants.yorumBegen(yorumId),
      options: _authOptions(token),
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

  Future<Map<String, dynamic>> toggleIcerikBegeni(int icerikId) async {
    final token = await _accessTokenOrThrow('Begenmek icin giris yapmalisin.');
    final response = await _dio.post(
      ApiConstants.icerikBegen(icerikId),
      options: _authOptions(token),
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

  Future<Map<String, dynamic>> toggleIcerikKaydet(int icerikId) async {
    final token = await _accessTokenOrThrow('Kaydetmek icin giris yapmalisin.');
    final response = await _dio.post(
      ApiConstants.icerikKaydet(icerikId),
      options: _authOptions(token),
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

  Future<void> icerikSil(int icerikId) async {
    final token = await _accessTokenOrThrow('Bu islem icin giris yapmalisin.');
    final response = await _dio.delete(
      '${ApiConstants.icerikler}$icerikId/',
      options: _authOptions(token),
    );
    if (response.statusCode == 204) return;
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Bu islem icin giris yapmalisin.',
      defaultMessage: 'Icerik silinemedi.',
    );
  }

  Future<void> yorumSil(int yorumId) async {
    final token = await _accessTokenOrThrow('Bu islem icin giris yapmalisin.');
    final response = await _dio.delete(
      ApiConstants.yorumDetay(yorumId),
      options: _authOptions(token),
    );
    if (response.statusCode == 204) return;
    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Bu islem icin giris yapmalisin.',
      defaultMessage: 'Yorum silinemedi.',
    );
  }

  Future<ProfilModel> getProfilById(int userId) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      ApiConstants.profilDetay(userId),
      options: (token != null && token.isNotEmpty) ? _authOptions(token) : null,
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

  Future<PaginatedResponse<IcerikModel>> getProfilIcerikleri(
    int userId, {
    int? page,
    int pageSize = ApiConstants.pageSize,
  }) async {
    final response = await _dio.get(
      ApiConstants.profilIcerikleri(userId),
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

  Future<PaginatedResponse<IcerikModel>> getProfilKaydedilenler(
    int userId, {
    int? page,
    int pageSize = ApiConstants.pageSize,
  }) async {
    final token = await _accessTokenOrThrow(
      'Kaydedilenleri görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiConstants.profilKaydedilenler(userId),
      queryParameters: {'page': ?page, 'page_size': pageSize},
      options: _authOptions(token),
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

  Future<PaginatedResponse<YorumOzetModel>> getProfilBegeniler(
    int userId, {
    int? page,
    int pageSize = ApiConstants.pageSize,
  }) async {
    final token = await _accessTokenOrThrow(
      'Beğenilenleri görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiConstants.profilBegeniler(userId),
      queryParameters: {'page': ?page, 'page_size': pageSize},
      options: _authOptions(token),
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

  Future<ProfilModel> getProfil() async {
    final token = await _accessTokenOrThrow(
      'Profilini görmek için giriş yapmalısın.',
    );
    final cachedProfile = await _readCachedProfile();
    final userId = cachedProfile?.id ?? _readUserIdFromToken(token);

    if (userId == null || userId <= 0) {
      throw 'Profil bilgisi için kullanıcı id alınamadı. Lütfen çıkış yapıp tekrar giriş yap.';
    }

    final response = await _dio.get(
      ApiConstants.profilDetay(userId),
      options: _authOptions(token),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final profile = ProfilModel.fromJson(
        response.data as Map<String, dynamic>,
      );
      return profile.copyWith(
        email: profile.email.isEmpty ? cachedProfile?.email : null,
        firstName: profile.firstName.isEmpty ? cachedProfile?.firstName : null,
        lastName: profile.lastName.isEmpty ? cachedProfile?.lastName : null,
      );
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil bilgileri alınamadı.',
    );
  }

  Future<ProfilModel> updateProfil(Map<String, dynamic> data) async {
    final token = await _accessTokenOrThrow(
      'Profilini güncellemek için giriş yapmalısın.',
    );
    final cachedProfile = await _readCachedProfile();
    final userId = cachedProfile?.id ?? _readUserIdFromToken(token);

    if (userId == null || userId <= 0) {
      throw 'Profil güncellemesi için kullanıcı id alınamadı. Lütfen çıkış yapıp tekrar giriş yap.';
    }

    final cleanedData = Map<String, dynamic>.from(data)
      ..removeWhere(
        (key, value) =>
            value == null &&
            !{'boy', 'kilo', 'hedef_kilo', 'dogum_tarihi'}.contains(key),
      );

    final response = await _dio.patch(
      ApiConstants.profilDetay(userId),
      data: cleanedData,
      options: _authOptions(token),
    );

    if ((response.statusCode == 200 || response.statusCode == 202) &&
        response.data is Map<String, dynamic>) {
      return ProfilModel.fromJson(response.data as Map<String, dynamic>);
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil güncellenemedi.',
    );
  }

  Future<ProfilModel> profilFotoYukle(XFile foto) async {
    final token = await _accessTokenOrThrow(
      'Profil fotografini guncellemek icin giris yapmalisin.',
    );
    final cachedProfile = await _readCachedProfile();
    final userId = cachedProfile?.id ?? _readUserIdFromToken(token);

    if (userId == null || userId <= 0) {
      throw 'Profil fotografi icin kullanici id alinamadi. Lutfen cikis yapip tekrar giris yap.';
    }

    final response = await _dio.patch(
      ApiConstants.profilDetay(userId),
      data: FormData.fromMap({
        'foto': MultipartFile.fromBytes(
          await foto.readAsBytes(),
          filename: foto.name,
        ),
      }),
      options: _authOptions(token, multipart: true),
    );

    if ((response.statusCode == 200 || response.statusCode == 202) &&
        response.data is Map<String, dynamic>) {
      return ProfilModel.fromJson(response.data as Map<String, dynamic>);
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum suren dolmus. Lutfen tekrar giris yap.',
      defaultMessage: 'Profil fotografi guncellenemedi.',
    );
  }

  Future<ProfilModel> completeOnboarding(Map<String, dynamic> data) async {
    final token = await _accessTokenOrThrow(
      'Profil kurulumunu tamamlamak için giriş yapmalısın.',
    );

    final response = await _dio.patch(
      ApiConstants.profilOnboard,
      data: data,
      options: _authOptions(token),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return ProfilModel.fromJson(response.data as Map<String, dynamic>);
    }

    throw _hataAyikla(
      response.data,
      response.statusCode,
      unauthorizedMessage: 'Oturum süren dolmuş. Lütfen tekrar giriş yap.',
      defaultMessage: 'Profil kurulumu tamamlanamadı.',
    );
  }

  Future<GunlukBeslenmeModel> getBeslenmeSu(String tarih) async {
    final token = await _accessTokenOrThrow(
      'Beslenme verilerini görmek için giriş yapmalısın.',
    );
    final response = await _dio.get(
      ApiConstants.beslenmeSu,
      queryParameters: {'tarih': tarih},
      options: _authOptions(token),
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

  Future<GunlukBeslenmeModel> suEkle({
    required String tarih,
    required int miktarMl,
  }) async {
    final token = await _accessTokenOrThrow(
      'Su eklemek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiConstants.beslenmeSu,
      data: {'tarih': tarih, 'su_ml': miktarMl},
      options: _authOptions(token),
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
      defaultMessage: 'Su eklenemedi.',
    );
  }

  Future<GunlukBeslenmeModel> kaloriEkle({
    required String tarih,
    required int kaloriKcal,
    double proteinG = 0,
    double karbonhidratG = 0,
    double yagG = 0,
  }) async {
    final token = await _accessTokenOrThrow(
      'Kalori eklemek için giriş yapmalısın.',
    );
    final response = await _dio.post(
      ApiConstants.beslenmeSu,
      data: {
        'tarih': tarih,
        'kalori_kcal': kaloriKcal,
        'protein_g': proteinG,
        'karbonhidrat_g': karbonhidratG,
        'yag_g': yagG,
      },
      options: _authOptions(token),
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

  Future<String> askAi({
    required String message,
    required List<ChatMessageModel> history,
  }) async {
    final token = await _accessTokenOrThrow(
      'AI Asistan için giriş yapmalısın.',
    );

    final response = await _dio.post(
      ApiConstants.aiChat,
      data: {
        'message': message,
        'history': history.map((message) => message.toApiJson()).toList(),
      },
      options: _authOptions(token),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final answer = response.data['answer']?.toString().trim();
      if (answer != null && answer.isNotEmpty) return answer;
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

  Future<ProfilModel?> _readCachedProfile() async {
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

  int? _readUserIdFromToken(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final rawId = decoded['user_id'] ?? decoded['id'] ?? decoded['sub'];
        if (rawId is int) return rawId;
        return int.tryParse(rawId?.toString() ?? '');
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String> _accessTokenOrThrow(String message) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) throw message;
    return token;
  }

  Options _authOptions(String token, {bool multipart = false}) {
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        if (!multipart) 'Content-Type': 'application/json',
      },
    );
  }

  String _hataAyikla(
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

    if (data is Map<String, dynamic>) {
      final detail =
          data['detail'] ??
          data['hata'] ??
          data['message'] ??
          data['error'] ??
          data['non_field_errors'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
    }

    return '$defaultMessage (Hata: $statusCode)';
  }
}
