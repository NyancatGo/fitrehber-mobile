enum ChatMessageRole { user, assistant }

class ChatMessageModel {
  final String text;
  final ChatMessageRole role;
  final DateTime timestamp;
  final bool includeInHistory;

  ChatMessageModel({
    required this.text,
    required this.role,
    required this.timestamp,
    this.includeInHistory = true,
  });

  bool get isUser => role == ChatMessageRole.user;

  Map<String, String> toApiJson() {
    return {'role': isUser ? 'user' : 'assistant', 'content': text};
  }
}
