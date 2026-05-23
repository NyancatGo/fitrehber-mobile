// ---------------------------------------------------------------------------
// SOHBET MESAJI MODELİ
// ---------------------------------------------------------------------------
// Yapay zekâ asistanı ekranındaki sohbet balonlarının verisini tutar.
// Hem kullanıcının yazdığı mesajları hem de asistanın verdiği yanıtları
// aynı model temsil eder; `role` alanı hangisi olduğunu belirtir.
// ---------------------------------------------------------------------------

/// Bir sohbet mesajının kimden geldiğini belirtir.
enum SohbetMesajiRolu {
  /// Mesajı kullanıcı yazdı.
  kullanici,

  /// Mesajı yapay zekâ asistanı üretti.
  asistan,
}

/// AI asistan sohbetindeki tek bir mesajı temsil eden veri modeli.
class SohbetMesajiModel {
  /// Mesajın metin içeriği.
  final String text;

  /// Mesajın sahibi (kullanıcı mı, asistan mı).
  final SohbetMesajiRolu role;

  /// Mesajın oluşturulduğu an.
  final DateTime timestamp;

  /// Bu mesajın, sonraki API isteklerine "sohbet geçmişi" olarak
  /// eklenip eklenmeyeceği. Örneğin hata baloncukları geçmişe katılmaz.
  final bool includeInHistory;

  SohbetMesajiModel({
    required this.text,
    required this.role,
    required this.timestamp,
    this.includeInHistory = true,
  });

  /// Mesajı kullanıcının yazıp yazmadığını kısa yoldan döndürür.
  bool get isUser => role == SohbetMesajiRolu.kullanici;

  /// Mesajı, AI API'sinin beklediği `{role, content}` biçimine çevirir.
  Map<String, String> toApiJson() {
    return {'role': isUser ? 'user' : 'assistant', 'content': text};
  }
}
