// API servis katmanı — tüm veri çekme işlemleri burada.
// Her fonksiyon ilgili endpoint'e istek atar ve modele dönüştürür.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';
import 'models/chat_message_model.dart';
import 'models/icerik_model.dart';
import 'models/kategori_model.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      validateStatus: (status) => true,
      headers: {'Accept': 'application/json'},
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
        'kategori': ?kategoriId,
        'tur': ?tur,
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

  // AI Asistan'a soru sorar (JWT token ile)
  Future<String> askAi({
    required String message,
    required List<ChatMessageModel> history,
  }) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw 'AI Asistan için giriş yapmalısın.';
    }

    final response = await _dio.post(
      ApiConstants.aiChat,
      data: {
        'message': message,
        'history': history.map((message) => message.toApiJson()).toList(),
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final answer = response.data['answer']?.toString().trim();
      if (answer != null && answer.isNotEmpty) return answer;
      throw 'Backend boş cevap döndü.';
    }

    throw _hataAyikla(response.data, response.statusCode);
  }

  String _hataAyikla(dynamic data, int? statusCode) {
    if (statusCode == 401) return 'AI Asistan için giriş yapmalısın.';
    if (statusCode == 429) {
      return 'Çok kısa sürede fazla soru sordun. Lütfen biraz bekleyip tekrar dene.';
    }

    if (data is Map<String, dynamic>) {
      final detail = data['detail'] ?? data['hata'] ?? data['message'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
    }

    return 'AI cevabı alınamadı. (Hata: $statusCode)';
  }
}
