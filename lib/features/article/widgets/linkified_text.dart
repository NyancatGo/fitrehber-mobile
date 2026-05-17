// Yorum metnini render eder; içindeki URL'leri tıklanabilir bağlantıya çevirir.
// TapGestureRecognizer nesneleri widget yaşam döngüsüyle birlikte temizlenir.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final Color linkColor;

  const LinkifiedText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.linkColor,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  // Metindeki http(s):// veya www. ile başlayan bağlantıları yakalar.
  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _linkAc(String ham) async {
    // Sondaki noktalama işaretlerini bağlantıdan ayıkla.
    var temiz = ham;
    while (temiz.isNotEmpty && '.,;:!?)]}'.contains(temiz[temiz.length - 1])) {
      temiz = temiz.substring(0, temiz.length - 1);
    }
    final tamUrl = temiz.startsWith('www.') ? 'https://$temiz' : temiz;
    final uri = Uri.tryParse(tamUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // Her yeniden derlemede eski recognizer'ları bırak.
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final matches = _urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      return Text(widget.text, style: widget.baseStyle);
    }

    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in matches) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: widget.text.substring(index, match.start)),
        );
      }
      final linkMetni = widget.text.substring(match.start, match.end);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _linkAc(linkMetni);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: linkMetni,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
            fontWeight: FontWeight.w700,
          ),
          recognizer: recognizer,
        ),
      );
      index = match.end;
    }
    if (index < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(index)));
    }

    return Text.rich(TextSpan(style: widget.baseStyle, children: spans));
  }
}
