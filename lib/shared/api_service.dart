// API servis katmanı — tüm veri çekme işlemleri burada.
// Her fonksiyon ilgili endpoint'e istek atar ve modele dönüştürür.

import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'models/icerik_model.dart';
import 'models/kategori_model.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    validateStatus: (status) => true,
    headers: {'Accept': 'application/json'},
  ));

  // Tüm kategorileri çeker
  Future<List<KategoriModel>> getKategoriler() async {
    final response = await _dio.get(ApiConstants.kategoriler);
    if (response.statusCode == 200) {
      return (response.data as List)
          .map((e) => KategoriModel.fromJson(e))
          .toList();
    }
    throw 'Kategoriler yüklenemedi.';
  }

  // Makaleleri çeker — opsiyonel kategori ve tür filtresi destekler
  Future<List<IcerikModel>> getIcerikler({
    int? kategoriId,
    String? tur,
    String? arama,
  }) async {
    final response = await _dio.get(
      ApiConstants.icerikler,
      queryParameters: {
        if (kategoriId != null) 'kategori': kategoriId,
        if (tur != null) 'tur': tur,
        if (arama != null && arama.isNotEmpty) 'search': arama,
      },
    );
    if (response.statusCode == 200) {
      return (response.data as List)
          .map((e) => IcerikModel.fromJson(e))
          .toList();
    }
    throw 'Makaleler yüklenemedi.';
  }

  // Tek bir makalenin detayını çeker
  Future<IcerikModel> getIcerikDetay(int id) async {
    final response = await _dio.get('${ApiConstants.icerikler}$id/');
    if (response.statusCode == 200) {
      return IcerikModel.fromJson(response.data);
    }
    throw 'Makale yüklenemedi.';
  }
}
