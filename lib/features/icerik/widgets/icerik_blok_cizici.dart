// `yazi_mobil_bloklar` çıktısını native Flutter widget'larına çizer.
// Bu yol HTML/CSS'e bağlı kalmaz; görsel kararlar mobilde verilir. Blok listesi
// boşsa eski HTML çizici geri dönüş yolu olarak kullanılır.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/icerik_blok_model.dart';

/// Blok çizici ve eski HTML geri dönüş yolu aynı paleti kullanır; makale
/// detayında iki yol arasında görsel kopma oluşmaz.
class _BlokRenkleri {
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

class IcerikBlokCizici extends StatelessWidget {
  final List<IcerikBlok> blocks;
  final double contentWidth;

  const IcerikBlokCizici({
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
          .map(
            (b) => Padding(
              padding: EdgeInsets.symmetric(vertical: _spacingFor(b)),
              child: _renderBlock(context, b, isCompact: isCompact),
            ),
          )
          .toList(),
    );
  }

  double _spacingFor(IcerikBlok b) {
    switch (b.tur) {
      case IcerikBlokTuru.baslik:
        return 14;
      case IcerikBlokTuru.bolumBasligi:
        return 16;
      case IcerikBlokTuru.ayirici:
        return 18;
      case IcerikBlokTuru.gorsel:
      case IcerikBlokTuru.bilgiKutusu:
      case IcerikBlokTuru.alinti:
      case IcerikBlokTuru.tablo:
      case IcerikBlokTuru.metrikIzgarasi:
      case IcerikBlokTuru.kartIzgarasi:
        return 12;
      default:
        return 8;
    }
  }

  Widget _renderBlock(
    BuildContext context,
    IcerikBlok b, {
    required bool isCompact,
  }) {
    switch (b.tur) {
      case IcerikBlokTuru.paragraf:
        return _Paragraf(html: b.html, isCompact: isCompact);
      case IcerikBlokTuru.giris:
        return _GirisParagrafi(html: b.html, isCompact: isCompact);
      case IcerikBlokTuru.baslik:
        return _Baslik(text: b.text, level: b.level, isCompact: isCompact);
      case IcerikBlokTuru.gorsel:
        return _Gorsel(
          src: b.src,
          alt: b.alt,
          caption: b.caption,
          aspectRatio: b.aspectRatio,
          isCompact: isCompact,
        );
      case IcerikBlokTuru.alinti:
        return _Alinti(html: b.html, cite: b.cite, isCompact: isCompact);
      case IcerikBlokTuru.liste:
        return _Liste(items: b.items, ordered: b.ordered, isCompact: isCompact);
      case IcerikBlokTuru.tablo:
        return _Tablo(rows: b.rows, isCompact: isCompact);
      case IcerikBlokTuru.ayirici:
        return const _Ayirici();
      case IcerikBlokTuru.bilgiKutusu:
        return _BilgiKutusu(
          tone: b.tone,
          title: b.title,
          children: b.children,
          isCompact: isCompact,
        );
      case IcerikBlokTuru.metrikIzgarasi:
        return _MetrikIzgarasi(items: b.metrics, isCompact: isCompact);
      case IcerikBlokTuru.kartIzgarasi:
        return _KartIzgarasi(items: b.cards, isCompact: isCompact);
      case IcerikBlokTuru.bolumBasligi:
        return _BolumBasligi(
          number: b.number,
          title: b.title,
          level: b.level,
          isCompact: isCompact,
        );
      case IcerikBlokTuru.bilinmeyen:
        // Bilinmeyen blok uygulamayı düşürmez; backend yeni tip eklerse boş geçilir.
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Ortak satır içi HTML çizimi (b, strong, em, i, a, br ...)
// ---------------------------------------------------------------------------

class _SatirIciHtml extends StatelessWidget {
  final String html;
  final TextStyle baseStyle;

  const _SatirIciHtml({required this.html, required this.baseStyle});

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
          color: _BlokRenkleri.link,
          textDecoration: TextDecoration.underline,
        ),
        'strong': Style(
          fontWeight: FontWeight.w800,
          color: _BlokRenkleri.textStrong,
        ),
        'b': Style(
          fontWeight: FontWeight.w800,
          color: _BlokRenkleri.textStrong,
        ),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'code': Style(
          backgroundColor: _BlokRenkleri.surfaceElevated,
          color: _BlokRenkleri.textStrong,
          fontFamily: 'monospace',
          padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
      },
      onLinkTap: (url, _, _) => _openLink(url),
    );
  }
}

// ---------------------------------------------------------------------------
// Paragraf ve giriş metni
// ---------------------------------------------------------------------------

class _Paragraf extends StatelessWidget {
  final String html;
  final bool isCompact;

  const _Paragraf({required this.html, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return _SatirIciHtml(
      html: html,
      baseStyle: TextStyle(
        color: _BlokRenkleri.text,
        fontSize: isCompact ? 16 : 17,
        fontWeight: FontWeight.w500,
        height: 1.72,
      ),
    );
  }
}

class _GirisParagrafi extends StatelessWidget {
  final String html;
  final bool isCompact;

  const _GirisParagrafi({required this.html, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _BlokRenkleri.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _BlokRenkleri.link.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      child: _SatirIciHtml(
        html: html,
        baseStyle: TextStyle(
          color: _BlokRenkleri.textStrong,
          fontSize: isCompact ? 17 : 18,
          fontWeight: FontWeight.w600,
          height: 1.68,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Başlık
// ---------------------------------------------------------------------------

class _Baslik extends StatelessWidget {
  final String text;
  final int level;
  final bool isCompact;

  const _Baslik({
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
          color: _BlokRenkleri.textStrong,
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
// Bölüm başlığı — numaralı rozet + başlık
// ---------------------------------------------------------------------------

class _BolumBasligi extends StatelessWidget {
  final String number;
  final String title;
  final int level;
  final bool isCompact;

  const _BolumBasligi({
    required this.number,
    required this.title,
    required this.level,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = switch (level) {
      2 => isCompact ? 22.0 : 26.0,
      3 => isCompact ? 19.0 : 21.0,
      _ => isCompact ? 17.0 : 18.0,
    };
    final badgeSize = isCompact ? 40.0 : 46.0;
    final badgeFontSize = isCompact ? 18.0 : 20.0;

    final titleWidget = Text(
      title,
      style: TextStyle(
        color: _BlokRenkleri.textStrong,
        fontSize: titleSize,
        fontWeight: FontWeight.w900,
        height: 1.25,
        letterSpacing: -0.3,
      ),
    );

    if (number.isEmpty) {
      // Numara yoksa bölüm başlığı özel bir başlık gibi çizilir; sol çizgi
      // vurgusu normal heading'den ayırt edilmesini sağlar.
      return Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: _BlokRenkleri.primary, width: 3),
          ),
        ),
        child: titleWidget,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _BlokRenkleri.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            number,
            style: TextStyle(
              color: Colors.white,
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: titleWidget),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Görsel
// ---------------------------------------------------------------------------

class _Gorsel extends StatelessWidget {
  final String src;
  final String alt;
  final String caption;
  final double? aspectRatio;
  final bool isCompact;

  /// Backend oran göndermediyse güvenli varsayılan; oran gelirse layout ona uyar.
  static const double _defaultAspectRatio = 16 / 9;

  const _Gorsel({
    required this.src,
    required this.alt,
    required this.caption,
    required this.aspectRatio,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return const SizedBox.shrink();
    // AspectRatio yükleme/hata sırasında alanı sabit tutar; sayfa zıplamaz.
    final ratio = aspectRatio ?? _defaultAspectRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: ratio,
            child: CachedNetworkImage(
              imageUrl: src,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: _BlokRenkleri.surfaceSoft,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _BlokRenkleri.primary,
                ),
              ),
              errorWidget: (_, url, error) => Container(
                alignment: Alignment.center,
                color: _BlokRenkleri.surfaceSoft,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: _BlokRenkleri.muted,
                ),
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption,
            style: TextStyle(
              color: _BlokRenkleri.muted,
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
// Alıntı
// ---------------------------------------------------------------------------

class _Alinti extends StatelessWidget {
  final String html;
  final String cite;
  final bool isCompact;

  const _Alinti({
    required this.html,
    required this.cite,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: _BlokRenkleri.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: _BlokRenkleri.primary.withValues(alpha: 0.7),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SatirIciHtml(
            html: html,
            baseStyle: TextStyle(
              color: _BlokRenkleri.textStrong,
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
                color: _BlokRenkleri.muted,
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
// Liste (ul/ol)
// ---------------------------------------------------------------------------

class _Liste extends StatelessWidget {
  final List<IcerikListeOgesi> items;
  final bool ordered;
  final bool isCompact;

  const _Liste({
    required this.items,
    required this.ordered,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final fontSize = isCompact ? 16.0 : 17.0;
    final markerStyle = TextStyle(
      color: _BlokRenkleri.link,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.72,
    );
    final textStyle = TextStyle(
      color: _BlokRenkleri.text,
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
              SizedBox(width: 22, child: Text(marker, style: markerStyle)),
              Expanded(
                child: _SatirIciHtml(
                  html: items[i].html.isNotEmpty
                      ? items[i].html
                      : items[i].text,
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
// Tablo — mobilde yatay scroll yerine satır-kart çizimi
// ---------------------------------------------------------------------------

class _Tablo extends StatelessWidget {
  final List<List<IcerikTabloHucresi>> rows;
  final bool isCompact;

  const _Tablo({required this.rows, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // İlk satır tamamen header hücrelerinden oluşuyorsa etiket olarak kullanılır.
    final hasHeader = rows.first.every((c) => c.header);
    final headers = hasHeader ? rows.first.map((c) => c.text).toList() : null;
    final bodyRows = hasHeader ? rows.skip(1).toList() : rows;

    return Container(
      decoration: BoxDecoration(
        color: _BlokRenkleri.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _BlokRenkleri.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < bodyRows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: i > 0
                    ? Border(top: BorderSide(color: _BlokRenkleri.line))
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
                    padding: EdgeInsets.only(top: j > 0 ? 6 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (label != null) ...[
                          SizedBox(
                            width: 110,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: _BlokRenkleri.muted,
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
                              color: _BlokRenkleri.text,
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
// Ayırıcı
// ---------------------------------------------------------------------------

class _Ayirici extends StatelessWidget {
  const _Ayirici();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(height: 1, color: _BlokRenkleri.line),
    );
  }
}

// ---------------------------------------------------------------------------
// Bilgi kutusu — tona göre renk + ikon
// ---------------------------------------------------------------------------

class _BilgiKutusu extends StatelessWidget {
  final BilgiKutusuTonu tone;
  final String title;
  final List<IcerikBlok> children;
  final bool isCompact;

  const _BilgiKutusu({
    required this.tone,
    required this.title,
    required this.children,
    required this.isCompact,
  });

  ({Color fg, Color bg, IconData icon}) _toneStyle() {
    switch (tone) {
      case BilgiKutusuTonu.uyari:
        return (
          fg: _BlokRenkleri.warn,
          bg: _BlokRenkleri.warnSoft,
          icon: Icons.warning_amber_rounded,
        );
      case BilgiKutusuTonu.basari:
        return (
          fg: _BlokRenkleri.success,
          bg: _BlokRenkleri.successSoft,
          icon: Icons.check_circle_outline,
        );
      case BilgiKutusuTonu.kaynak:
        return (
          fg: _BlokRenkleri.source,
          bg: _BlokRenkleri.sourceSoft,
          icon: Icons.menu_book_outlined,
        );
      case BilgiKutusuTonu.icindekiler:
        return (
          fg: _BlokRenkleri.toc,
          bg: _BlokRenkleri.tocSoft,
          icon: Icons.list_alt_outlined,
        );
      case BilgiKutusuTonu.bilgi:
        return (
          fg: _BlokRenkleri.primary,
          bg: _BlokRenkleri.surfaceElevated,
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
            ...children.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _renderChild(c, isCompact: isCompact),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _defaultTitle(BilgiKutusuTonu tone) {
    switch (tone) {
      case BilgiKutusuTonu.uyari:
        return 'Uyarı';
      case BilgiKutusuTonu.basari:
        return 'Önemli';
      case BilgiKutusuTonu.kaynak:
        return 'Kaynaklar';
      case BilgiKutusuTonu.icindekiler:
        return 'İçindekiler';
      case BilgiKutusuTonu.bilgi:
        return 'Bilgi';
    }
  }

  Widget _renderChild(IcerikBlok child, {required bool isCompact}) {
    // Bilgi kutusu içeriği genelde paragraf/liste olur; derin iç içelik beklemeyiz.
    if (child.tur == IcerikBlokTuru.paragraf) {
      return _Paragraf(html: child.html, isCompact: isCompact);
    }
    if (child.tur == IcerikBlokTuru.liste) {
      return _Liste(
        items: child.items,
        ordered: child.ordered,
        isCompact: isCompact,
      );
    }
    return _Paragraf(html: child.text, isCompact: isCompact);
  }
}

// ---------------------------------------------------------------------------
// Metrik ızgarası — büyük değer + küçük açıklama kartları
// ---------------------------------------------------------------------------

class _MetrikIzgarasi extends StatelessWidget {
  final List<IcerikMetrikOgesi> items;
  final bool isCompact;

  const _MetrikIzgarasi({required this.items, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Telefonda 2 kolon, geniş ekranda en fazla 4 kolon; kartlar dengeli kalır.
        final maxWidth = constraints.maxWidth;
        final int cols;
        if (items.length == 1) {
          cols = 1;
        } else if (items.length == 2) {
          cols = 2;
        } else if (isCompact) {
          cols = 2;
        } else {
          cols = items.length <= 4 ? items.length : 4;
        }
        const gap = 10.0;
        final cardWidth = (maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (m) => SizedBox(
                  width: cardWidth.clamp(80.0, maxWidth),
                  child: _MetrikKarti(item: m, isCompact: isCompact),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetrikKarti extends StatelessWidget {
  final IcerikMetrikOgesi item;
  final bool isCompact;

  const _MetrikKarti({required this.item, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _BlokRenkleri.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _BlokRenkleri.line.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _BlokRenkleri.link,
              fontSize: isCompact ? 22 : 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          if (item.label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _BlokRenkleri.muted,
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kart ızgarası — başlık ve açıklama içeren içerik kartları
// ---------------------------------------------------------------------------

class _KartIzgarasi extends StatelessWidget {
  final List<IcerikKartOgesi> items;
  final bool isCompact;

  const _KartIzgarasi({required this.items, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // Mobilde kartlar tek kolon kalır; açıklamalar uzun olabilir.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _KartOgesi(item: c, isCompact: isCompact),
            ),
          )
          .toList(),
    );
  }
}

class _KartOgesi extends StatelessWidget {
  final IcerikKartOgesi item;
  final bool isCompact;

  const _KartOgesi({required this.item, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _BlokRenkleri.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _BlokRenkleri.line.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item.title,
                style: TextStyle(
                  color: _BlokRenkleri.textStrong,
                  fontSize: isCompact ? 16 : 17,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ...item.body.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SatirIciHtml(
                html: p.html.isNotEmpty ? p.html : p.text,
                baseStyle: TextStyle(
                  color: _BlokRenkleri.text,
                  fontSize: isCompact ? 15 : 16,
                  fontWeight: FontWeight.w500,
                  height: 1.65,
                ),
              ),
            ),
          ),
          if (item.list.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...List.generate(item.list.length, (i) {
              final li = item.list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: _BlokRenkleri.link,
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w800,
                          height: 1.65,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _SatirIciHtml(
                        html: li.html.isNotEmpty ? li.html : li.text,
                        baseStyle: TextStyle(
                          color: _BlokRenkleri.text,
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w500,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satır içi link akışı TapGestureRecognizer gerektirdiği için import sabit kalır.
// ---------------------------------------------------------------------------

// ignore_for_file: unused_element
class _BosTiklamaTaniyici extends TapGestureRecognizer {}
