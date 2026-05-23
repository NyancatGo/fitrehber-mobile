// ---------------------------------------------------------------------------
// SOHBET BALONU
// ---------------------------------------------------------------------------
// AI asistan ekranındaki tek bir mesajı (kullanıcı veya asistan) gösteren
// balon widget'ı. Asistan mesajları Markdown biçimlendirmesiyle çizilir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../core/theme/uygulama_temasi.dart';
import '../../../shared/models/sohbet_mesaji_model.dart';

/// Sohbetteki tek bir mesajı gösteren balon widget'ı.
class SohbetBalonu extends StatelessWidget {
  final SohbetMesajiModel message;

  const SohbetBalonu({super.key, required this.message});

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
              color: message.isUser
                  ? UygulamaTemasi.anaRenk
                  : UygulamaTemasi.yuzey,
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
                          : UygulamaTemasi.anaMetin,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    strong: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : UygulamaTemasi.anaMetin,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    listBullet: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : UygulamaTemasi.anaMetin,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    code: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : UygulamaTemasi.anaRenk,
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
              color: UygulamaTemasi.ikincilMetin,
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
