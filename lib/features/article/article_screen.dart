import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';

class ArticleScreen extends StatefulWidget {
  final int id;
  const ArticleScreen({super.key, required this.id});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final ApiService _api = ApiService();
  IcerikModel? _icerik;
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _icerikYukle();
  }

  Future<void> _icerikYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final icerik = await _api.getIcerikDetay(widget.id);
      setState(() => _icerik = icerik);
    } catch (e) {
      setState(() => _hata = e.toString());
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _icerik?.baslik ?? 'Makale',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_hata!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _icerikYukle,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_icerik == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _icerik!.kategoriAdi,
              style: const TextStyle(
                color: Color(0xFFF5A623),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _icerik!.baslik,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _icerik!.yazarAdi,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                _icerik!.tarihFormatli,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const Divider(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width - 40;

              return SizedBox(
                width: double.infinity,
                child: Html(
                  data: _icerik!.yaziTemiz,
                  style: {
                    'html': Style(
                      display: Display.block,
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    'body': Style(
                      display: Display.block,
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.7),
                      color: Colors.white,
                      whiteSpace: WhiteSpace.normal,
                    ),
                    'div': Style(
                      display: Display.block,
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    'main': Style(display: Display.block),
                    'article': Style(display: Display.block),
                    'section': Style(display: Display.block),
                    'figure': Style(
                      display: Display.block,
                      width: Width(contentWidth),
                      margin: Margins.symmetric(vertical: 16),
                      padding: HtmlPaddings.zero,
                    ),
                    'figcaption': Style(
                      margin: Margins.only(top: 8),
                      fontSize: FontSize(13),
                      lineHeight: LineHeight(1.4),
                      color: Colors.grey,
                      textAlign: TextAlign.center,
                    ),
                    'img': Style(
                      display: Display.block,
                      width: Width(contentWidth),
                      height: Height.auto(),
                      margin: Margins.symmetric(vertical: 12),
                    ),
                    'h1': Style(
                      fontSize: FontSize(22),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      lineHeight: LineHeight(1.25),
                      margin: Margins.only(top: 18, bottom: 10),
                    ),
                    'h2': Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      lineHeight: LineHeight(1.3),
                      margin: Margins.only(top: 18, bottom: 10),
                    ),
                    'h3': Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      lineHeight: LineHeight(1.35),
                      margin: Margins.only(top: 16, bottom: 8),
                    ),
                    'h4': Style(
                      fontSize: FontSize(17),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      lineHeight: LineHeight(1.35),
                      margin: Margins.only(top: 14, bottom: 8),
                    ),
                    'p': Style(
                      display: Display.block,
                      margin: Margins.symmetric(vertical: 8),
                      color: Colors.white,
                    ),
                    'ul': Style(
                      display: Display.block,
                      margin: Margins.symmetric(vertical: 8),
                      padding: HtmlPaddings.only(left: 20),
                    ),
                    'ol': Style(
                      display: Display.block,
                      margin: Margins.symmetric(vertical: 8),
                      padding: HtmlPaddings.only(left: 20),
                    ),
                    'li': Style(
                      color: Colors.white,
                      lineHeight: LineHeight(1.6),
                      margin: Margins.only(bottom: 8),
                      display: Display.listItem,
                    ),
                    'blockquote': Style(
                      display: Display.block,
                      margin: Margins.symmetric(vertical: 12),
                      padding: HtmlPaddings.only(left: 14, top: 8, bottom: 8),
                      color: Colors.white70,
                      border: const Border(
                        left: BorderSide(color: Color(0xFFF5A623), width: 3),
                      ),
                    ),
                    'pre': Style(
                      display: Display.block,
                      margin: Margins.symmetric(vertical: 12),
                      padding: HtmlPaddings.all(12),
                      fontSize: FontSize(14),
                      lineHeight: LineHeight(1.5),
                      whiteSpace: WhiteSpace.normal,
                      backgroundColor: const Color(0xFF1A1D27),
                    ),
                    'code': Style(
                      fontSize: FontSize(14),
                      whiteSpace: WhiteSpace.normal,
                      backgroundColor: const Color(0xFF1A1D27),
                    ),
                    'table': Style(
                      display: Display.block,
                      margin: Margins.symmetric(vertical: 12),
                    ),
                    'th': Style(
                      padding: HtmlPaddings.all(8),
                      color: Colors.white,
                    ),
                    'td': Style(
                      padding: HtmlPaddings.all(8),
                      color: Colors.white,
                    ),
                    'a': Style(
                      color: Color(0xFFF5A623),
                      display: Display.inline,
                    ),
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
