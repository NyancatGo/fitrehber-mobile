// ---------------------------------------------------------------------------
// SOHBET BALONU
// ---------------------------------------------------------------------------
// AI asistan ekranındaki tek bir mesajı (kullanıcı veya asistan) gösteren
// balon widget'ı. Asistan mesajları Markdown biçimlendirmesiyle çizilir;
// ayrıca analiz edilen veri rozetlerini (`contextTags`), Besin DB ile
// doğrulanmış "Öğünüme Ekle" eylem kartlarını (`actions`), 👍/👎 geri bildirim
// aksiyonlarını, etkileşimli takip sorusu çiplerini (`suggestions`) ve hata
// durumunda "Tekrar Dene" aksiyonunu barındırır.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../core/theme/uygulama_temasi.dart';
import '../../../shared/models/sohbet_mesaji_model.dart';

/// Sohbetteki tek bir mesajı gösteren balon widget'ı.
class SohbetBalonu extends StatelessWidget {
  final SohbetMesajiModel message;
  final bool showSuggestions;
  final ValueChanged<String>? onSuggestionTap;
  final VoidCallback? onRetry;
  final ValueChanged<int>? onActionApply;
  final void Function(String rating, String? reason)? onFeedback;

  const SohbetBalonu({
    super.key,
    required this.message,
    this.showSuggestions = false,
    this.onSuggestionTap,
    this.onRetry,
    this.onActionApply,
    this.onFeedback,
  });

  void _metniKopyala(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yanıt panoya kopyalandı.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _olumsuzGeriBildirimSor(BuildContext context) {
    if (onFeedback == null) return;
    const nedenler = <(String kod, String etiket)>[
      ('yanlis_bilgi', 'Sayısal / besin bilgisi hatalı'),
      ('alakasiz', 'Soruma veya verilerime uygun değil'),
      ('cok_genel', 'Fazla genel / yüzeysel kaldı'),
      ('cok_uzun', 'Gereğinden fazla uzun'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: UygulamaTemasi.yuzey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yanıtı nasıl geliştirebiliriz?',
                  style: UygulamaTemasi.baslik(fontSize: 17, height: 1.2),
                ),
                const SizedBox(height: 10),
                ...nedenler.map((n) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: UygulamaTemasi.anaRenk,
                    ),
                    title: Text(
                      n.$2,
                      style: const TextStyle(
                        color: UygulamaTemasi.anaMetin,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onFeedback!('down', n.$1);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.isError;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isUser && !isError && message.contextTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: message.contextTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: UygulamaTemasi.anaRenk.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: UygulamaTemasi.anaRenk.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: UygulamaTemasi.anaRenk,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: UygulamaTemasi.anaRenk,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? UygulamaTemasi.anaRenk : UygulamaTemasi.yuzey,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isError
                            ? UygulamaTemasi.hata.withValues(alpha: 0.55)
                            : UygulamaTemasi.cizgi,
                      ),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.86,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet:
                        MarkdownStyleSheet.fromTheme(
                          Theme.of(context),
                        ).copyWith(
                          p: TextStyle(
                            color: isUser
                                ? UygulamaTemasi.anaUstune
                                : UygulamaTemasi.anaMetin,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          strong: TextStyle(
                            color: isUser
                                ? UygulamaTemasi.anaUstune
                                : UygulamaTemasi.anaMetin,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          listBullet: TextStyle(
                            color: isUser
                                ? UygulamaTemasi.anaUstune
                                : UygulamaTemasi.anaMetin,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          code: TextStyle(
                            color: isUser
                                ? UygulamaTemasi.anaUstune
                                : UygulamaTemasi.anaRenk,
                            backgroundColor: UygulamaTemasi.cizgi,
                            fontSize: 13,
                          ),
                        ),
                  ),
                  if (isError && onRetry != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: UygulamaTemasi.anaRenk.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: UygulamaTemasi.anaRenk.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 15,
                              color: UygulamaTemasi.anaRenk,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Tekrar Dene',
                              style: TextStyle(
                                color: UygulamaTemasi.anaRenk,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Eylem Kartları ("Öğünüme Ekle")
            if (!isUser && !isError && message.actions.isNotEmpty)
              for (int i = 0; i < message.actions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildEylemKarti(context, message.actions[i], i),
                ),

            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(
                    color: UygulamaTemasi.ikincilMetin,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isUser && !isError && message.text.trim().isNotEmpty) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _metniKopyala(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: UygulamaTemasi.ikincilMetin,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Kopyala',
                            style: TextStyle(
                              color: UygulamaTemasi.ikincilMetin,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onFeedback != null && message.includeInHistory) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onFeedback!('up', null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Icon(
                          message.feedbackRating == 'up'
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 13.5,
                          color: message.feedbackRating == 'up'
                              ? UygulamaTemasi.anaRenk
                              : UygulamaTemasi.ikincilMetin,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _olumsuzGeriBildirimSor(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Icon(
                          message.feedbackRating == 'down'
                              ? Icons.thumb_down_alt_rounded
                              : Icons.thumb_down_alt_outlined,
                          size: 13.5,
                          color: message.feedbackRating == 'down'
                              ? UygulamaTemasi.hata
                              : UygulamaTemasi.ikincilMetin,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
            if (!isUser &&
                !isError &&
                showSuggestions &&
                message.suggestions.isNotEmpty &&
                onSuggestionTap != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.suggestions.map((soru) {
                  return Material(
                    color: UygulamaTemasi.yuzey,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSuggestionTap!(soru),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: UygulamaTemasi.anaRenk.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tips_and_updates_outlined,
                              size: 14,
                              color: UygulamaTemasi.anaRenk,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                soru,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: UygulamaTemasi.anaMetin,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEylemKarti(
    BuildContext context,
    AsistanEylemKartiModel kart,
    int index,
  ) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.86,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UygulamaTemasi.yuzey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: UygulamaTemasi.anaRenk.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UygulamaTemasi.anaRenk.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  kart.ogunEtiketi,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: UygulamaTemasi.anaRenk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.verified_rounded,
                size: 14,
                color: UygulamaTemasi.anaRenk,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Besin DB Doğrulamalı',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: UygulamaTemasi.ikincilMetin,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kart.baslik,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: UygulamaTemasi.anaMetin,
            ),
          ),
          const SizedBox(height: 8),
          ...kart.besinler.map((kalem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '• ${kalem.isim} (${kalem.gram.toStringAsFixed(0)} g)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: UygulamaTemasi.anaMetin,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${kalem.kalori} kcal • ${kalem.protein.toStringAsFixed(0)}g P',
                    style: const TextStyle(
                      fontSize: 12,
                      color: UygulamaTemasi.ikincilMetin,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: UygulamaTemasi.cizgi, height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Toplam: ${kart.toplamKalori} kcal • ${kart.toplamProtein.toStringAsFixed(0)}g P',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: UygulamaTemasi.anaMetin,
                  ),
                ),
              ),
              if (onActionApply != null)
                ElevatedButton.icon(
                  onPressed: kart.uygulandi ? null : () => onActionApply!(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kart.uygulandi
                        ? UygulamaTemasi.cizgi
                        : UygulamaTemasi.anaRenk,
                    foregroundColor: kart.uygulandi
                        ? UygulamaTemasi.ikincilMetin
                        : UygulamaTemasi.anaUstune,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    kart.uygulandi
                        ? Icons.check_circle_rounded
                        : Icons.add_task_rounded,
                    size: 16,
                  ),
                  label: Text(
                    kart.uygulandi ? 'Öğüne Eklendi' : 'Öğünüme Ekle',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
