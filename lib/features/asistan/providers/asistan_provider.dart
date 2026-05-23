// ---------------------------------------------------------------------------
// AI ASİSTAN DURUM YÖNETİMİ (RIVERPOD)
// ---------------------------------------------------------------------------
// Yapay zekâ asistanı sohbetinin durumunu yönetir: mesaj listesi, yükleme
// durumu ve mesaj gönderme işlemi. Asistanın bağlamı koruması için son
// mesajlardan oluşan bir geçmiş her istekle birlikte gönderilir.
// ---------------------------------------------------------------------------

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api_servisi.dart';
import '../../../shared/models/sohbet_mesaji_model.dart';

/// API'ye gönderilen sohbet geçmişinde tutulacak en fazla mesaj sayısı.
const int _maxHistoryMessages = 10;

/// AI asistan sohbetinin anlık durumunu (mesajlar + yükleme) temsil eder.
class AsistanDurumu {
  /// Sohbetteki tüm mesajlar (kullanıcı + asistan).
  final List<SohbetMesajiModel> messages;

  /// Asistandan yanıt bekleniyor mu?
  final bool isLoading;

  AsistanDurumu({required this.messages, this.isLoading = false});

  AsistanDurumu copyWith({List<SohbetMesajiModel>? messages, bool? isLoading}) {
    return AsistanDurumu(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Sohbet mesajlarının gönderilmesini ve durumun güncellenmesini yöneten kontrolcü.
class AsistanDenetleyici extends StateNotifier<AsistanDurumu> {
  final ApiServisi _api = ApiServisi();

  AsistanDenetleyici()
    : super(
        AsistanDurumu(
          messages: [
            SohbetMesajiModel(
              text:
                  'Merhaba! Ben FitRehber AI Asistanı. Beslenme, antrenman veya genel sağlık konularında sana nasıl yardımcı olabilirim?',
              role: SohbetMesajiRolu.asistan,
              timestamp: DateTime.now(),
              includeInHistory: false,
            ),
          ],
        ),
      );

  /// Kullanıcının yazdığı [text] mesajını asistana gönderir ve yanıtı bekler.
  ///
  /// Boş mesaj veya hâlihazırda yanıt beklenirken çağrılırsa hiçbir şey yapmaz.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    final history = _recentHistory();

    // Kullanıcı mesajını listeye ekle ve yükleme durumunu aç.
    final userMessage = SohbetMesajiModel(
      text: text,
      role: SohbetMesajiRolu.kullanici,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      final response = await _api.asistanaSor(message: text, history: history);

      final aiMessage = SohbetMesajiModel(
        text: response,
        role: SohbetMesajiRolu.asistan,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );
    } catch (e) {
      final errorMessage = SohbetMesajiModel(
        text:
            'Üzgünüm, şu anda yanıt veremiyorum. Lütfen internet bağlantını kontrol et veya daha sonra tekrar dene.\n\nDetay: $e',
        role: SohbetMesajiRolu.asistan,
        timestamp: DateTime.now(),
        includeInHistory: false,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  /// API'ye gönderilecek sohbet geçmişini hazırlar: geçmişe dâhil edilen
  /// mesajların yalnızca son [_maxHistoryMessages] tanesi alınır.
  List<SohbetMesajiModel> _recentHistory() {
    final history = state.messages
        .where((message) => message.includeInHistory)
        .toList();
    if (history.length <= _maxHistoryMessages) return history;
    return history.sublist(history.length - _maxHistoryMessages);
  }
}

/// AI asistan sohbetinin durumunu sağlayan provider.
final asistanProvider =
    StateNotifierProvider<AsistanDenetleyici, AsistanDurumu>((ref) {
      return AsistanDenetleyici();
    });
