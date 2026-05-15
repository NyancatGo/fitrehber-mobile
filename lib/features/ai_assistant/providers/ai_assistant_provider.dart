import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/api_service.dart';
import '../../../shared/models/chat_message_model.dart';

const int _maxHistoryMessages = 10;

// Mesaj geçmişini ve yükleme durumunu tutacak state
class AiAssistantState {
  final List<ChatMessageModel> messages;
  final bool isLoading;

  AiAssistantState({required this.messages, this.isLoading = false});

  AiAssistantState copyWith({
    List<ChatMessageModel>? messages,
    bool? isLoading,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Riverpod Notifier
class AiAssistantNotifier extends StateNotifier<AiAssistantState> {
  final ApiService _api = ApiService();

  AiAssistantNotifier()
    : super(
        AiAssistantState(
          messages: [
            ChatMessageModel(
              text:
                  'Merhaba! Ben FitRehber AI Asistanı. Beslenme, antrenman veya genel sağlık konularında sana nasıl yardımcı olabilirim?',
              role: ChatMessageRole.assistant,
              timestamp: DateTime.now(),
              includeInHistory: false,
            ),
          ],
        ),
      );

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    final history = _recentHistory();

    // Kullanıcı mesajını listeye ekle ve yükleme durumunu aç.
    final userMessage = ChatMessageModel(
      text: text,
      role: ChatMessageRole.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      final response = await _api.askAi(message: text, history: history);

      final aiMessage = ChatMessageModel(
        text: response,
        role: ChatMessageRole.assistant,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );
    } catch (e) {
      final errorMessage = ChatMessageModel(
        text:
            'Üzgünüm, şu anda yanıt veremiyorum. Lütfen internet bağlantını kontrol et veya daha sonra tekrar dene.\n\nDetay: $e',
        role: ChatMessageRole.assistant,
        timestamp: DateTime.now(),
        includeInHistory: false,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  List<ChatMessageModel> _recentHistory() {
    final history = state.messages
        .where((message) => message.includeInHistory)
        .toList();
    if (history.length <= _maxHistoryMessages) return history;
    return history.sublist(history.length - _maxHistoryMessages);
  }
}

// Provider tanımı
final aiAssistantProvider =
    StateNotifierProvider<AiAssistantNotifier, AiAssistantState>((ref) {
      return AiAssistantNotifier();
    });
