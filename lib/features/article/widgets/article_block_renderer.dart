// Mobil-native makale renderer. API'nin `yazi_mobil_bloklar` cıktısını alır,
// her bloku semantik bir Flutter widget olarak cizer.
//
// HTML parse etmez (sadece inline "html" alanını flutter_html'e teslim eder).
// Bootstrap class'ları, koyu temaya uymayan inline style'lar bu katmanda yok;
// tüm görsel kararlar burada native olarak verilir.
//
// Eski `ArticleContentRenderer` bos blok listesi durumunda fallback olarak
// `IcerikDetayEkrani`'nda devreye girer — bu widget yalnizca yeni blok modeli
// ile calisir.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/article_block.dart';

/// Tüm renkler tek noktada — eski ArticleContentRenderer ile aynı palet,
/// böylece blok renderer ile HTML fallback arasında görsel atlama olmaz.
class _BlockColors {
  static const text = Color(0xFFE5E7EB);
  static const textStrong = Color(0xFFF8FAFC);
  static const muted = Color(0xFFA1A8B3);
  static const line = Color(0xFF2F3A4E);
  static const surfaceSoft = Color(0xFF151D2B);
  static const surfaceElevated = Color(0xFF1A2333);
  static const primary = Color(0xFF3B82F6);
  static const link = Color(0xFFF5A623);
  static const warn = Color(0xFFF59E0B);
  static const warnSoft = Color(0xFF332414);
  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0xFF14271A);
  static const source = Color(0xFF60A5FA);
  static const sourceSoft = Color(0xFF0F1F3A);
  static const toc = Color(0xFFA855F7);
  static const tocSoft = Color(0xFF1F1530);
}

class ArticleBlockRenderer extends StatelessWidget {
  final List<ArticleBlock> blocks;
  final double contentWidth;

  const ArticleBlockRenderer({
    super.key,
    required this.blocks,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    final width = contentWidth.isFinite && contentWidth > 0
        ? contentWidth
        : MediaQuery.sizeOf(context).width;
    final isCompact = width < 640;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks
          .map((b) => Padding(
                padding: EdgeInsets.symmetric(vertical: _spacingFor(b)),
                child: _renderBlock(context, b, isCompact: isCompact),
              ))
          .toList(),
    );
  }

  double _spacingFor(ArticleBlock b) {
    switch (b.type) {
      case ArticleBlockType.heading:
        return 14;
      case ArticleBlockType.divider:
        return 18;
      case ArticleBlockType.figure:
      case ArticleBlockType.infoBox:
      case ArticleBlockType.quote:
      case ArticleBlockType.table:
        return 12;
      default:
        return 8;
    }
  }

  Widget _renderBlock(BuildContext context, ArticleBlock b,
      {required bool isCompact}) {
    switch (b.type) {
      case ArticleBlockType.paragraph:
        return _Paragraph(html: b.html, isCompact: isCompact);
      case ArticleBlockType.lead:
        return _Lead(html: b.html, isCompact: isCompact);
      case ArticleBlockType.heading:
        return _Heading(text: b.text, level: b.level, isCompact: isCompact);
      case ArticleBlockType.figure:
        return _Figure(
          src: b.src,
          alt: b.alt,
          caption: b.caption,
          isCompact: isCompact,
        );
      case ArticleBlockType.quote:
        return _Quote(html: b.html, cite: b.cite, isCompact: isCompact);
      case ArticleBlockType.list:
        return _List(items: b.items, ordered: b.ordered, isCompact: isCompact);
      case ArticleBlockType.table:
        return _Table(rows: b.rows, isCompact: isCompact);
      case ArticleBlockType.divider:
        return const _Divider();
      case ArticleBlockType.infoBox:
        return _InfoBox(
          tone: b.tone,
          title: b.title,
          children: b.children,
          isCompact: isCompact,
        );
      case ArticleBlockType.unknown:
        // Bilinmeyen blok → bos widget, log olarak bırakılabilir.
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Ortak: inline HTML render (b, strong, em, i, a, br ...)
// ---------------------------------------------------------------------------

class _InlineHtml extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;

  const _InlineHtml({
    required this.html,
    required this.baseStyle,
  });

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) return const SizedBox.shrink();
    return Html(
      data: html,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: baseStyle.color,
          fontSize: FontSize(baseStyle.fontSize ?? 16),
          fontWeight: baseStyle.fontWeight,
          lineHeight: LineHeight(baseStyle.height ?? 1.7),
        ),
        'a': Style(
          color: _BlockColors.link,
          textDecoration: TextDecoration.underline,
        ),
        'strong': Style(
          fontWeight: FontWeight.w800,
          color: _BlockColors.textStrong,
        ),
        'b': Style(
          fontWeight: FontWeight.w800,
          color: _BlockColors.textStrong,
        ),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'code': Style(
          backgroundColor: _BlockColors.surfaceElevated,
          color: _BlockColors.textStrong,
          fontFamily: 'monospace',
          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
      },
      onLinkTap: (url, _, _) => _openLink(url),
    );
  }
}

// ---------------------------------------------------------------------------
// Paragraph & Lead
// ---------------------------------------------------------------------------

class _Paragraph extends StatelessWidget {
  final String html;
  final bool isCompact;

  const _Paragraph({required this.html, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return _InlineHtml(
      html: html,
      baseStyle: TextStyle(
        color: _BlockColors.text,
        fontSize: isCompact ? 16 : 17,
        fontWeight: FontWeight.w500,
        height: 1.72,
      ),
    );
  }
}

class _Lead extends StatelessWidget {
  final String html;
  final bool isCompact;

  const _Lead({required this.html, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _BlockColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _BlockColors.link.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      child: _InlineHtml(
        html: html,
        baseStyle: TextStyle(
          color: _BlockColors.textStrong,
          fontSize: isCompact ? 17 : 18,
          fontWeight: FontWeight.w600,
          height: 1.68,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Heading
// ---------------------------------------------------------------------------

class _Heading extends StatelessWidget {
  final String text;
  final int level;
  final bool isCompact;

  const _Heading({
    required this.text,
    required this.level,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final size = switch (level) {
      2 => isCompact ? 22.0 : 26.0,
      3 => isCompact ? 19.0 : 21.0,
      _ => isCompact ? 17.0 : 18.0,
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 2 ? 6 : 2, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          color: _BlockColors.textStrong,
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 1.3,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Figure
// ---------------------------------------------------------------------------

class _Figure extends StatelessWidget {
  final String src;
  final String alt;
  final String caption;
  final bool isCompact;

  const _Figure({
    required this.src,
    required this.alt,
    required this.caption,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: src,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              height: 200,
              color: _BlockColors.surfaceSoft,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: _BlockColors.primary,
              ),
            ),
            errorWidget: (_, url, error) => Container(
              height: 120,
              alignment: Alignment.center,
              color: _BlockColors.surfaceSoft,
              child: const Icon(Icons.broken_image_outlined,
                  color: _BlockColors.muted),
            ),
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: TextStyle(
              color: _BlockColors.muted,
              fontSize: isCompact ? 13 : 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quote
// ---------------------------------------------------------------------------

class _Quote extends StatelessWidget {
  final String html;
  final String cite;
  final bool isCompact;

  const _Quote({
    required this.html,
    required this.cite,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: _BlockColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: _BlockColors.primary.withValues(alpha: 0.7),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineHtml(
            html: html,
            baseStyle: TextStyle(
              color: _BlockColors.textStrong,
              fontSize: isCompact ? 16 : 17,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.65,
            ),
          ),
          if (cite.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '— $cite',
              style: TextStyle(
                color: _BlockColors.muted,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List (ul/ol)
// ---------------------------------------------------------------------------

class _List extends StatelessWidget {
  final List<ArticleListItem> items;
  final bool ordered;
  final bool isCompact;

  const _List({
    required this.items,
    required this.ordered,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final fontSize = isCompact ? 16.0 : 17.0;
    final markerStyle = TextStyle(
      color: _BlockColors.link,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.72,
    );
    final textStyle = TextStyle(
      color: _BlockColors.text,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: 1.72,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(items.length, (i) {
        final marker = ordered ? '${i + 1}.' : '•';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(marker, style: markerStyle),
              ),
              Expanded(
                child: _InlineHtml(
                  html: items[i].html.isNotEmpty ? items[i].html : items[i].text,
                  baseStyle: textStyle,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Table — basit kart bazlı render (mobil için yatay scroll yerine row-card)
// ---------------------------------------------------------------------------

class _Table extends StatelessWidget {
  final List<List<ArticleTableCell>> rows;
  final bool isCompact;

  const _Table({required this.rows, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Header row: row[0] tüm cell'ler header ise (th)
    final hasHeader = rows.first.every((c) => c.header);
    final headers = hasHeader ? rows.first.map((c) => c.text).toList() : null;
    final bodyRows = hasHeader ? rows.skip(1).toList() : rows;

    return Container(
      decoration: BoxDecoration(
        color: _BlockColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _BlockColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < bodyRows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: i > 0
                    ? Border(top: BorderSide(color: _BlockColors.line))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(bodyRows[i].length, (j) {
                  final cell = bodyRows[i][j];
                  final label = headers != null && j < headers.length
                      ? headers[j]
                      : null;
                  return Padding(
                    padding: EdgeInsets.only(
                        top: j > 0 ? 6 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label != null) ...[
                          SizedBox(
                            width: 110,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: _BlockColors.muted,
                                fontSize: isCompact ? 13 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            cell.text,
                            style: TextStyle(
                              color: _BlockColors.text,
                              fontSize: isCompact ? 14 : 15,
                              fontWeight: cell.header
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 1,
        color: _BlockColors.line,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InfoBox — tone'a göre renk + ikon
// ---------------------------------------------------------------------------

class _InfoBox extends StatelessWidget {
  final InfoBoxTone tone;
  final String title;
  final List<ArticleBlock> children;
  final bool isCompact;

  const _InfoBox({
    required this.tone,
    required this.title,
    required this.children,
    required this.isCompact,
  });

  ({Color fg, Color bg, IconData icon}) _toneStyle() {
    switch (tone) {
      case InfoBoxTone.warning:
        return (
          fg: _BlockColors.warn,
          bg: _BlockColors.warnSoft,
          icon: Icons.warning_amber_rounded,
        );
      case InfoBoxTone.success:
        return (
          fg: _BlockColors.success,
          bg: _BlockColors.successSoft,
          icon: Icons.check_circle_outline,
        );
      case InfoBoxTone.source:
        return (
          fg: _BlockColors.source,
          bg: _BlockColors.sourceSoft,
          icon: Icons.menu_book_outlined,
        );
      case InfoBoxTone.toc:
        return (
          fg: _BlockColors.toc,
          bg: _BlockColors.tocSoft,
          icon: Icons.list_alt_outlined,
        );
      case InfoBoxTone.info:
        return (
          fg: _BlockColors.primary,
          bg: _BlockColors.surfaceElevated,
          icon: Icons.info_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _toneStyle();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.fg.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(s.icon, color: s.fg, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : _defaultTitle(tone),
                  style: TextStyle(
                    color: s.fg,
                    fontSize: isCompact ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...children.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _renderChild(c, isCompact: isCompact),
                )),
          ],
        ],
      ),
    );
  }

  String _defaultTitle(InfoBoxTone tone) {
    switch (tone) {
      case InfoBoxTone.warning:
        return 'Uyarı';
      case InfoBoxTone.success:
        return 'Önemli';
      case InfoBoxTone.source:
        return 'Kaynaklar';
      case InfoBoxTone.toc:
        return 'İçindekiler';
      case InfoBoxTone.info:
        return 'Bilgi';
    }
  }

  Widget _renderChild(ArticleBlock child, {required bool isCompact}) {
    // InfoBox icindeki child'lar genelde paragraph veya list. Recursive
    // ama derinligi 1 — infoBox icinde infoBox beklemeyiz.
    if (child.type == ArticleBlockType.paragraph) {
      return _Paragraph(html: child.html, isCompact: isCompact);
    }
    if (child.type == ArticleBlockType.list) {
      return _List(
        items: child.items,
        ordered: child.ordered,
        isCompact: isCompact,
      );
    }
    return _Paragraph(html: child.text, isCompact: isCompact);
  }
}

// ---------------------------------------------------------------------------
// Unused dummy — keep static analyzer happy if url_launcher import drifts
// ---------------------------------------------------------------------------

// ignore_for_file: unused_element
class _NoopGestureRecognizer extends TapGestureRecognizer {}
