import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ArticleContentRenderer extends StatelessWidget {
  final String html;
  final double contentWidth;

  const ArticleContentRenderer({
    super.key,
    required this.html,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = contentWidth.isFinite && contentWidth > 0
        ? contentWidth
        : MediaQuery.sizeOf(context).width;
    final renderer = _ArticleRenderer(width: width);
    final fragment = html_parser.parseFragment(html);
    final children = renderer.renderNodes(fragment.nodes);

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ArticleColors {
  static const text = Color(0xFFE5E7EB);
  static const textStrong = Color(0xFFF8FAFC);
  static const muted = Color(0xFFA1A8B3);
  static const line = Color(0xFF2F3A4E);
  static const surface = Color(0xFF111827);
  static const surfaceSoft = Color(0xFF151D2B);
  static const surfaceElevated = Color(0xFF1A2333);
  static const primary = Color(0xFF3B82F6);
  static const primarySoft = Color(0xFF142C4B);
  static const link = Color(0xFFF5A623);
  static const warn = Color(0xFFF59E0B);
  static const warnSoft = Color(0xFF332414);
}

class _ArticleRenderer {
  final double width;

  _ArticleRenderer({required this.width});

  bool get isCompact => width < 640;
  bool get isWide => width >= 700;

  TextStyle get bodyStyle => TextStyle(
    color: _ArticleColors.text,
    fontSize: isCompact ? 16 : 17,
    height: 1.72,
    fontWeight: FontWeight.w500,
  );

  TextStyle get leadStyle => bodyStyle.copyWith(
    color: _ArticleColors.textStrong,
    fontSize: isCompact ? 17 : 18,
    height: 1.68,
  );

  TextStyle get mutedStyle => bodyStyle.copyWith(
    color: _ArticleColors.muted,
    fontSize: isCompact ? 14 : 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  List<Widget> renderNodes(Iterable<dom.Node> nodes, {bool tight = false}) {
    final widgets = <Widget>[];

    for (final node in nodes) {
      final widget = _renderNode(node, tight: tight);
      if (widget != null) widgets.add(widget);
    }

    return widgets;
  }

  Widget? _renderNode(dom.Node node, {bool tight = false}) {
    if (node is dom.Text) {
      final text = _normalizeText(node.text);
      if (text.trim().isEmpty) return null;
      return _textBlock(text.trim(), tight: tight);
    }

    if (node is! dom.Element) return null;

    final tag = node.localName;
    if (tag == null || tag == 'script' || tag == 'style') {
      return null;
    }

    if (_hasClass(node, 'article-body')) return _plainChildren(node);
    if (_hasClass(node, 'box-title') ||
        _hasClass(node, 'source-link') ||
        _hasClass(node, 'source-meta') ||
        _hasClass(node, 'source-original')) {
      return _paragraph(node, tight: true);
    }
    if (_hasClass(node, 'box-toc')) return _toc(node);
    if (_hasClass(node, 'box-summary')) {
      return _accentPanel(
        child: _childrenColumn(node, tight: true),
        color: _ArticleColors.primarySoft,
        accent: _ArticleColors.primary,
        margin: EdgeInsets.only(bottom: isCompact ? 22 : 30),
      );
    }
    if (_hasClass(node, 'facts')) return _facts(node);
    if (_hasClass(node, 'highlight-warn')) {
      return _accentPanel(
        child: _childrenColumn(node, tight: true),
        color: _ArticleColors.warnSoft,
        accent: _ArticleColors.warn,
      );
    }
    if (_hasClass(node, 'highlight')) {
      return _accentPanel(
        child: _childrenColumn(node, tight: true),
        color: _ArticleColors.primarySoft,
        accent: _ArticleColors.primary,
      );
    }
    if (_hasClass(node, 'quote')) return _quote(node);
    if (_hasClass(node, 'fraction-list')) return _fractionList(node);
    if (_hasClass(node, 'fraction-item')) return _fractionItem(node);
    if (_hasClass(node, 'grid')) return _grid(node);
    if (_hasClass(node, 'card')) return _card(node);
    if (_hasClass(node, 'sources')) return _sources(node);
    if (_hasClass(node, 'source-item')) return _sourceItem(node);
    if (_hasClass(node, 'final-note')) return _finalNote(node);
    if (_hasClass(node, 'box')) return _box(node);
    if (_hasClass(node, 'media') || tag == 'figure') return _figure(node);

    switch (tag) {
      case 'h1':
        return _heading(node, 1, tight: tight);
      case 'h2':
        return _heading(node, 2, tight: tight);
      case 'h3':
        return _heading(node, 3, tight: tight);
      case 'h4':
        return _heading(node, 4, tight: tight);
      case 'p':
        return _paragraph(node, tight: tight);
      case 'ul':
        return _list(node, ordered: false, tight: tight);
      case 'ol':
        return _list(node, ordered: true, tight: tight);
      case 'li':
        return _listItem(node, 0, ordered: false);
      case 'img':
        return _image(node);
      case 'figcaption':
        return _caption(node);
      case 'blockquote':
        return _quote(node);
      case 'table':
        return _table(node);
      case 'br':
        return SizedBox(height: isCompact ? 8 : 10);
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'nav':
        return _plainChildren(node);
      default:
        return _paragraph(node, tight: tight);
    }
  }

  Widget _plainChildren(dom.Element element) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: renderNodes(element.nodes),
    );
  }

  Widget _childrenColumn(dom.Element element, {bool tight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: renderNodes(element.nodes, tight: tight),
    );
  }

  Widget _toc(dom.Element element) {
    final title = element.querySelector('.box-title');
    final list = element.querySelector('ol') ?? element.querySelector('ul');

    return _accentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            _richTextBlock(
              title,
              bodyStyle.copyWith(
                color: _ArticleColors.textStrong,
                fontSize: isCompact ? 18 : 20,
                fontWeight: FontWeight.w800,
              ),
              margin: EdgeInsets.only(bottom: isCompact ? 8 : 12),
            ),
          if (list != null) _list(list, ordered: list.localName == 'ol'),
        ],
      ),
      color: _ArticleColors.surfaceSoft,
      accent: _ArticleColors.primary,
      margin: EdgeInsets.only(bottom: isCompact ? 24 : 32),
    );
  }

  Widget _box(dom.Element element) {
    return _panel(
      child: _childrenColumn(element, tight: true),
      color: _ArticleColors.surfaceSoft,
      margin: EdgeInsets.only(bottom: isCompact ? 20 : 28),
    );
  }

  Widget _card(dom.Element element) {
    return _panel(
      child: _childrenColumn(element, tight: true),
      color: _ArticleColors.surfaceSoft,
      padding: EdgeInsets.all(isCompact ? 15 : 18),
      margin: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
    );
  }

  Widget _facts(dom.Element element) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 18 : 26),
      padding: EdgeInsets.all(isCompact ? 18 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061126), Color(0xFF0F1F45)],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 22),
        border: Border.all(color: const Color(0xFF1F3E72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: _childrenColumn(element, tight: true),
    );
  }

  Widget _quote(dom.Element element) {
    return _accentPanel(
      child: _childrenColumn(element, tight: true),
      color: _ArticleColors.surface,
      accent: _ArticleColors.primary,
    );
  }

  Widget _fractionList(dom.Element element) {
    final items = element.children
        .where((child) => _hasClass(child, 'fraction-item'))
        .toList();
    final children = items.isNotEmpty
        ? items.map(_fractionItem).toList()
        : renderNodes(element.nodes, tight: true);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _fractionItem(dom.Element element) {
    final badge = element.querySelector('.fraction-badge');
    final contentNodes = element.nodes.where((node) {
      return node is! dom.Element || !_hasClass(node, 'fraction-badge');
    });

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 10 : 12),
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: _ArticleColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ArticleColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roundBadge(badge?.text.trim() ?? ''),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: renderNodes(contentNodes, tight: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(dom.Element element) {
    final cards = element.children.where((child) => _hasClass(child, 'card'));

    if (!isWide || cards.length < 2) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: renderNodes(element.nodes, tight: true),
        ),
      );
    }

    final gap = isCompact ? 12.0 : 16.0;
    final cardWidth = (width - gap) / 2;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 20),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards
            .map((card) => SizedBox(width: cardWidth, child: _card(card)))
            .toList(),
      ),
    );
  }

  Widget _sources(dom.Element element) {
    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 24 : 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: renderNodes(element.nodes, tight: true),
      ),
    );
  }

  Widget _sourceItem(dom.Element element) {
    return _panel(
      child: _childrenColumn(element, tight: true),
      color: _ArticleColors.surface,
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      margin: EdgeInsets.only(bottom: isCompact ? 10 : 12),
    );
  }

  Widget _finalNote(dom.Element element) {
    return _accentPanel(
      child: _childrenColumn(element, tight: true),
      color: _ArticleColors.primarySoft,
      accent: _ArticleColors.primary,
      margin: EdgeInsets.only(top: isCompact ? 18 : 24),
    );
  }

  Widget _heading(dom.Element element, int level, {bool tight = false}) {
    final marginTop = tight
        ? (level <= 2 ? 10.0 : 8.0)
        : switch (level) {
            1 => isCompact ? 20.0 : 28.0,
            2 => isCompact ? 26.0 : 38.0,
            3 => isCompact ? 22.0 : 28.0,
            _ => isCompact ? 16.0 : 20.0,
          };
    final marginBottom = tight ? 8.0 : (level <= 2 ? 14.0 : 10.0);
    final style = switch (level) {
      1 => bodyStyle.copyWith(
        color: _ArticleColors.textStrong,
        fontSize: isCompact ? 26 : 32,
        height: 1.2,
        fontWeight: FontWeight.w900,
      ),
      2 => bodyStyle.copyWith(
        color: _ArticleColors.textStrong,
        fontSize: isCompact ? 24 : 30,
        height: 1.25,
        fontWeight: FontWeight.w900,
      ),
      3 => bodyStyle.copyWith(
        color: _ArticleColors.textStrong,
        fontSize: isCompact ? 21 : 25,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      _ => bodyStyle.copyWith(
        color: _ArticleColors.textStrong,
        fontSize: isCompact ? 18 : 20,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
    };

    if (level == 2 && !tight) {
      return Padding(
        padding: EdgeInsets.only(top: marginTop, bottom: marginBottom),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _ArticleColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _richText(element, style)),
            ],
          ),
        ),
      );
    }

    return _richTextBlock(
      element,
      style,
      margin: EdgeInsets.only(top: marginTop, bottom: marginBottom),
    );
  }

  Widget _paragraph(dom.Element element, {bool tight = false}) {
    final isLead = _hasClass(element, 'lead');
    final isTitle = _hasClass(element, 'box-title');
    final isLink =
        element.localName == 'a' || _hasClass(element, 'source-link');
    final isMeta = _hasClass(element, 'source-meta');
    final isOriginal = _hasClass(element, 'source-original');
    final style = isTitle
        ? bodyStyle.copyWith(
            color: _ArticleColors.textStrong,
            fontSize: isCompact ? 18 : 20,
            fontWeight: FontWeight.w800,
          )
        : isLink
        ? bodyStyle.copyWith(
            color: _ArticleColors.link,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            decorationColor: _ArticleColors.link,
          )
        : isMeta
        ? mutedStyle.copyWith(fontSize: isCompact ? 13 : 14)
        : isOriginal
        ? mutedStyle
        : isLead
        ? leadStyle
        : bodyStyle;

    return _richTextBlock(
      element,
      style,
      margin: EdgeInsets.symmetric(vertical: tight ? 5 : 8),
    );
  }

  Widget _list(
    dom.Element element, {
    required bool ordered,
    bool tight = false,
  }) {
    final items = element.children
        .where((child) => child.localName == 'li')
        .toList();
    if (items.isEmpty) return _plainChildren(element);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tight ? 6 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            _listItem(items[i], i, ordered: ordered),
        ],
      ),
    );
  }

  Widget _listItem(dom.Element element, int index, {required bool ordered}) {
    final marker = ordered ? '${index + 1}.' : '•';

    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ordered ? 34 : 24,
            child: Text(
              marker,
              style: bodyStyle.copyWith(
                color: ordered
                    ? _ArticleColors.text
                    : _ArticleColors.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _richText(element, bodyStyle)),
        ],
      ),
    );
  }

  Widget _figure(dom.Element element) {
    final image = element.querySelector('img');
    final caption = element.querySelector('figcaption');
    final extraChildren = element.children.where((child) {
      return child.localName != 'img' && child.localName != 'figcaption';
    }).toList();

    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 22 : 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (extraChildren.isNotEmpty)
            ...renderNodes(extraChildren, tight: true),
          if (image != null) _image(image, insideFigure: true),
          if (caption != null) _caption(caption),
        ],
      ),
    );
  }

  Widget _image(dom.Element element, {bool insideFigure = false}) {
    final src = element.attributes['src']?.trim();
    final alt = element.attributes['alt']?.trim() ?? '';

    if (src == null || src.isEmpty) {
      return const SizedBox.shrink();
    }

    final aspectRatio = _imageAspectRatio(element);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(insideFigure ? 14 : 12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.network(
          src,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _imagePlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _imagePlaceholder(progress: loadingProgress);
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ArticleColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _ArticleColors.line),
            ),
            child: Text(
              alt.isNotEmpty ? alt : 'Gorsel yuklenemedi',
              textAlign: TextAlign.center,
              style: mutedStyle,
            ),
          ),
        ),
      ),
    );

    if (!insideFigure) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 18),
        child: image,
      );
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFECE8DE),
        borderRadius: BorderRadius.circular(insideFigure ? 16 : 12),
        border: Border.all(color: const Color(0xFFE5DED1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: image,
    );
  }

  Widget _imagePlaceholder({ImageChunkEvent? progress}) {
    final expected = progress?.expectedTotalBytes;
    final loaded = progress?.cumulativeBytesLoaded;
    final value = expected != null && loaded != null && expected > 0
        ? loaded / expected
        : null;

    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      color: const Color(0xFFECE8DE),
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: 3,
          color: _ArticleColors.primary,
          backgroundColor: Colors.black.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _caption(dom.Element element) {
    return _richTextBlock(
      element,
      mutedStyle.copyWith(fontSize: isCompact ? 13 : 14, height: 1.45),
      textAlign: TextAlign.center,
      margin: EdgeInsets.only(top: isCompact ? 10 : 12),
    );
  }

  Widget _table(dom.Element element) {
    final rows = element.querySelectorAll('tr');
    if (rows.isEmpty) return _plainChildren(element);
    final columns = _tableColumns(rows);

    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 16 : 22),
      decoration: BoxDecoration(
        color: _ArticleColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ArticleColors.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: bodyStyle.copyWith(
            color: _ArticleColors.textStrong,
            fontWeight: FontWeight.w800,
          ),
          dataTextStyle: bodyStyle,
          dividerThickness: 0.6,
          columns: columns,
          rows: _tableRows(rows, columns.length),
        ),
      ),
    );
  }

  List<DataColumn> _tableColumns(List<dom.Element> rows) {
    final headerCells = rows.first.children
        .where((cell) => cell.localName == 'th' || cell.localName == 'td')
        .toList();
    final count = headerCells.isEmpty ? 1 : headerCells.length;

    return List.generate(count, (index) {
      final label = index < headerCells.length
          ? headerCells[index].text.trim()
          : '';
      return DataColumn(label: Text(label.isEmpty ? ' ' : label));
    });
  }

  List<DataRow> _tableRows(List<dom.Element> rows, int columnCount) {
    final bodyRows = rows.skip(1).toList();
    if (bodyRows.isEmpty) return const [];

    return bodyRows.map((row) {
      final cells = row.children
          .where((cell) => cell.localName == 'td' || cell.localName == 'th')
          .toList();
      final tableCells = List.generate(columnCount, (index) {
        if (index >= cells.length) return const DataCell(Text(''));
        return DataCell(Text(_normalizeText(cells[index].text).trim()));
      });

      return DataRow(cells: tableCells);
    }).toList();
  }

  Widget _accentPanel({
    required Widget child,
    required Color color,
    required Color accent,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.symmetric(vertical: isCompact ? 14 : 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
        border: Border.all(color: _ArticleColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: ColoredBox(color: accent),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 21 : 27,
              isCompact ? 16 : 22,
              isCompact ? 16 : 22,
              isCompact ? 16 : 22,
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required Widget child,
    required Color color,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.symmetric(vertical: isCompact ? 12 : 18),
      padding: padding ?? EdgeInsets.all(isCompact ? 16 : 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 18),
        border: Border.all(color: _ArticleColors.line),
      ),
      child: child,
    );
  }

  Widget _roundBadge(String text) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }

  Widget _textBlock(String text, {bool tight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tight ? 4 : 7),
      child: Text(text, style: bodyStyle),
    );
  }

  Widget _richTextBlock(
    dom.Element element,
    TextStyle style, {
    EdgeInsetsGeometry? margin,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: _richText(element, style, textAlign: textAlign),
    );
  }

  Widget _richText(
    dom.Element element,
    TextStyle style, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: style,
        children: _inlineSpans(element.nodes, style),
      ),
    );
  }

  List<InlineSpan> _inlineSpans(Iterable<dom.Node> nodes, TextStyle style) {
    final spans = <InlineSpan>[];

    for (final node in nodes) {
      if (node is dom.Text) {
        final text = _normalizeText(node.text);
        if (text.isNotEmpty) spans.add(TextSpan(text: text));
        continue;
      }

      if (node is! dom.Element) continue;
      final tag = node.localName;
      if (tag == 'br') {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      var childStyle = style;
      if (tag == 'strong' || tag == 'b') {
        childStyle = childStyle.copyWith(
          color: _ArticleColors.textStrong,
          fontWeight: FontWeight.w900,
        );
      } else if (tag == 'em' || tag == 'i') {
        childStyle = childStyle.copyWith(fontStyle: FontStyle.italic);
      } else if (tag == 'a') {
        childStyle = childStyle.copyWith(
          color: _ArticleColors.link,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: _ArticleColors.link,
        );
      } else if (tag == 'code') {
        childStyle = childStyle.copyWith(
          color: _ArticleColors.textStrong,
          backgroundColor: _ArticleColors.surfaceElevated,
          fontFamily: 'monospace',
        );
      } else if (_hasClass(node, 'source-meta')) {
        childStyle = mutedStyle.copyWith(fontSize: isCompact ? 13 : 14);
      } else if (_hasClass(node, 'source-link')) {
        childStyle = childStyle.copyWith(
          color: _ArticleColors.link,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: _ArticleColors.link,
        );
      }

      spans.addAll(_inlineSpans(node.nodes, childStyle));
    }

    return spans;
  }

  bool _hasClass(dom.Element element, String className) {
    return element.classes.contains(className);
  }

  double _imageAspectRatio(dom.Element element) {
    final widthAttr = double.tryParse(element.attributes['width'] ?? '');
    final heightAttr = double.tryParse(element.attributes['height'] ?? '');

    if (widthAttr != null &&
        heightAttr != null &&
        widthAttr > 0 &&
        heightAttr > 0) {
      return widthAttr / heightAttr;
    }

    return 1200 / 700;
  }

  String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
}
