// Makale detay ekranı.
// Makale ID'si ile API'den tam içeriği çeker ve gösterir.

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
    setState(() { _yukleniyor = true; _hata = null; });
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
          // Kategori etiketi
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
          // Makale başlığı
          Text(
            _icerik!.baslik,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Yazar ve tarih
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_icerik!.yazarAdi, style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(_icerik!.tarihFormatli, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Divider(height: 32),
          // Makale içeriği
          Html(
            // Tam HTML sayfasından sadece <body> içindeki makale içeriğini çıkar
            data: _icerikTemizle(_icerik!.yazi),
            style: {
              'body': Style(
                fontSize: FontSize(16),
                lineHeight: LineHeight(1.7),
                color: Colors.white,
              ),
              'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.bold, color: Colors.white),
              'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold, color: Colors.white),
              'h3': Style(fontSize: FontSize(18), fontWeight: FontWeight.bold, color: Colors.white),
              'p':  Style(color: Colors.white),
              'li': Style(color: Colors.white),
              'a':  Style(color: Color(0xFFF5A623)),
            },
          ),
        ],
      ),
    );
  }

  // Tam HTML sayfasından sadece içerik kısmını ayıklar.
  // <body> ve </body> etiketleri arasındaki kısmı alır.
  // Script ve style etiketlerini temizler.
  String _icerikTemizle(String html) {
    // <body> ile </body> arasındaki kısmı al
    final bodyBaslangic = html.indexOf('<body');
    final bodyBitis = html.lastIndexOf('</body>');
    
    if (bodyBaslangic == -1 || bodyBitis == -1) return html;
    
    String icerik = html.substring(bodyBaslangic, bodyBitis + 7);
    
    // Script etiketlerini kaldır
    icerik = icerik.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    
    // Style etiketlerini kaldır  
    icerik = icerik.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
    
    return icerik;
  }
}
