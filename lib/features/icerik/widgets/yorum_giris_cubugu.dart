import 'package:flutter/material.dart';

/// Yorum/yanıt yazma çubuğu.
/// Metin değiştikçe yalnızca gönder butonu yeniden derlenir; gradient,
/// gölge ve yanıt banner'ı her tuşta gereksiz yere rebuild olmaz.
class YorumGirisCubugu extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyToUsername;
  final bool isSending;
  final VoidCallback onCancelReply;
  final ValueChanged<String> onSend;

  const YorumGirisCubugu({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.replyToUsername,
    required this.isSending,
    required this.onCancelReply,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Material(
          color: const Color(0xFF0F1420),
          elevation: 18,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: replyToUsername == null
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(replyToUsername),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22D3EE,
                            ).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF22D3EE,
                              ).withValues(alpha: 0.24),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.reply_rounded,
                                color: Color(0xFF22D3EE),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '@$replyToUsername kullanicisine yanit veriliyor',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFBFF6FF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Yaniti iptal et',
                                onPressed: onCancelReply,
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: replyToUsername == null
                              ? 'Yorum yaz...'
                              : 'Yanıtını yaz...',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Yalnızca bu buton metin/gönderim durumuna göre rebuild olur.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final canSend =
                            value.text.trim().isNotEmpty && !isSending;
                        return _GonderButonu(
                          canSend: canSend,
                          isSending: isSending,
                          onSend: () => onSend(controller.text.trim()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GonderButonu extends StatelessWidget {
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  const _GonderButonu({
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: canSend
            ? const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
              )
            : null,
        color: canSend ? null : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        boxShadow: canSend
            ? [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.24),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: IconButton(
        tooltip: 'Gonder',
        onPressed: canSend ? onSend : null,
        icon: isSending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded),
      ),
    );
  }
}
