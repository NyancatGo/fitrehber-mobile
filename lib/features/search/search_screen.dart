// İçerik arama ekranı.
// Başlığa göre API'de arama yapar (haber + forum sorusu birlikte).

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<IcerikModel> _sonuclar = [];
  bool _yukleniyor = false;
  String? _hata;
  String _sonAranan = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _aramaDegisti(String deger) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _ara(deger.trim());
    });
  }

  Future<void> _ara(String sorgu) async {
    if (sorgu.length < 2) {
      setState(() {
        _sonuclar = [];
        _hata = null;
        _yukleniyor = false;
        _sonAranan = sorgu;
      });
      return;
    }
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _sonAranan = sorgu;
    });
    try {
      final response = await _api.getIcerikler(arama: sorgu);
      if (!mounted) return;
      setState(() => _sonuclar = response.results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'İçerik ara...',
            border: InputBorder.none,
          ),
          onChanged: _aramaDegisti,
          onSubmitted: (deger) => _ara(deger.trim()),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _ara('');
              },
            ),
        ],
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
            Text(_hata!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _ara(_sonAranan),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_sonAranan.length < 2) {
      return const Center(
        child: Text(
          'Aramak için en az 2 harf yaz.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_sonuclar.isEmpty) {
      return Center(
        child: Text(
          '"$_sonAranan" için sonuç bulunamadı.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sonuclar.length,
      itemBuilder: (context, index) => _sonucKarti(_sonuclar[index]),
    );
  }

  Widget _sonucKarti(IcerikModel icerik) {
    final forumMu = icerik.tur == 'soru';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: icerik.resimUrl != null && icerik.resimUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: icerik.resimUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (c, u) =>
                      Container(color: const Color(0xFF2A2D37)),
                  errorWidget: (c, u, e) => const Icon(Icons.image),
                ),
              )
            : Icon(
                forumMu ? Icons.forum_outlined : Icons.article_outlined,
                color: const Color(0xFF22D3EE),
              ),
        title: Text(
          icerik.baslik,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${forumMu ? 'Forum' : icerik.kategoriAdi} · ${icerik.tarihFormatli}',
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () => context.push('/makale/${icerik.id}'),
      ),
    );
  }
}
