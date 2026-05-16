import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/ai_assistant_provider.dart';
import 'widgets/ai_thinking_indicator.dart';
import 'widgets/chat_bubble.dart';
import '../../core/theme/app_theme.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiAssistantState>(aiAssistantProvider, (previous, next) {
      if (previous == null) return;
      if (previous.messages.length != next.messages.length ||
          previous.isLoading != next.isLoading) {
        _scrollToBottom();
      }
    });

    final aiState = ref.watch(aiAssistantProvider);
    final messages = aiState.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitRehber AI'),
        centerTitle: true,
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'AI Asistan sadece tavsiye niteliğindedir. Tıbbi bir teşhis veya tedavi sunmaz.',
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Mesaj Listesi
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              itemCount: messages.length + (aiState.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const AiThinkingIndicator();
                }

                return ChatBubble(message: messages[index]);
              },
            ),
          ),

          // Giriş Alanı
          _buildInputArea(aiState.isLoading),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: isLoading
                      ? 'Lütfen bekleyin...'
                      : 'Beslenme, antrenman, sağlık...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: isLoading ? AppTheme.surface : AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: isLoading ? AppTheme.textSecondary : Colors.white,
                  size: 22,
                ),
                onPressed: isLoading
                    ? null
                    : () {
                        final text = _controller.text.trim();
                        if (text.isNotEmpty) {
                          ref
                              .read(aiAssistantProvider.notifier)
                              .sendMessage(text);
                          _controller.clear();
                          _scrollToBottom();
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
