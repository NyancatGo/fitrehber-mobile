// ---------------------------------------------------------------------------
// İÇERİK ARAMA EKRANI
// ---------------------------------------------------------------------------
// Kullanıcının başlığa göre içerik (haber + forum sorusu) aradığı ekran.
// Sonuçlar sayfalıdır: liste sonuna gelindiğinde sonraki sayfa otomatik yüklenir.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_sabitleri.dart';
import '../../shared/api_servisi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/sayfalama/sayfalama_yardimcilari.dart';

/// Başlığa göre içerik araması yapılan ekran.
class AramaEkrani extends StatefulWidget {
  const AramaEkrani({super.key});

  @override
  State<AramaEkrani> createState() => _AramaEkraniDurumu();
}

class _AramaEkraniDurumu extends State<AramaEkrani> {
  final ApiServisi _api = ApiServisi();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SayfalamaTetikleyici _sayfalamaTetikleyici = SayfalamaTetikleyici();
  Timer? _debounce;

  List<IcerikModel> _sonuclar = [];
  bool _yukleniyor = false;
  bool _dahaYukleniyor = false;
  bool _dahaVar = false;
  int _page = 1;
  String? _hata;
  String _sonAranan = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_sayfalamaTetikleyici.yuklemeliMi(_scrollController)) {
      _dahaYukle();
    }
  }

  void _aramaDegisti(String deger) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _ara(deger.trim());
    });
  }

  void _aramayiTemizle() {
    // Bekleyen debounce timer'ını iptal et; eski sorgu tetiklenmesin.
    _debounce?.cancel();
    _controller.clear();
    _ara('');
  }

  Future<void> _ara(String sorgu) async {
    if (sorgu.length < 2) {
      setState(() {
        _sonuclar = [];
        _hata = null;
        _yukleniyor = false;
        _dahaVar = false;
        _page = 1;
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
      final response = await _api.icerikleriGetir(
        arama: sorgu,
        page: 1,
        pageSize: ApiSabitleri.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _sonuclar = response.sonuclar;
        _page = 1;
        _dahaVar = response.sonrakiVarMi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _dahaYukle() async {
    if (_dahaYukleniyor || !_dahaVar || _yukleniyor) return;
    if (_sonAranan.length < 2) return;
    setState(() => _dahaYukleniyor = true);
    try {
      final response = await _api.icerikleriGetir(
        arama: _sonAranan,
        page: _page + 1,
        pageSize: ApiSabitleri.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _sonuclar.addAll(response.sonuclar);
        _dahaVar = response.sonrakiVarMi;
      });
    } catch (_) {
      if (mounted) sayfalamaYuklemeHatasiGoster(context, onRetry: _dahaYukle);
    } finally {
      if (mounted) setState(() => _dahaYukleniyor = false);
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
              onPressed: _aramayiTemizle,
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
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _sonuclar.length + (_dahaVar ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _sonuclar.length) {
          return const Padding(
            key: ValueKey('arama-yukleniyor'),
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _sonucKarti(_sonuclar[index]);
      },
    );
  }

  Widget _sonucKarti(IcerikModel icerik) {
    final forumMu = icerik.tur == 'soru';
    return Card(
      key: ValueKey('arama-${icerik.id}'),
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
