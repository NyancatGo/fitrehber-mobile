import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/chat_message_model.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: message.isUser ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isUser ? 16 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 16),
              ),
              border: message.isUser
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    strong: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    listBullet: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    code: TextStyle(
                      color: message.isUser ? Colors.white : AppTheme.primary,
                      backgroundColor: Colors.black.withValues(alpha: 0.18),
                      fontSize: 13,
                    ),
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatTime(message.timestamp),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
