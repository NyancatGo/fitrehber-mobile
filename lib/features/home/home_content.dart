// Ana sayfa içeriği.
// Üstte kategori filtreleri, altta makale listesi gösterilir.
// Veriler API'den çekilir; yüklenirken shimmer, hata olursa hata mesajı gösterilir.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/kategori_model.dart';
import '../article/article_screen.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final ApiService _api = ApiService();

  List<KategoriModel> _kategoriler = [];
  List<IcerikModel> _icerikler = [];
  int? _secilenKategoriId; // null = tümü
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _verileriYukle(); // Ekran açılınca verileri çek
  }

  // API'den kategori ve makale listesini çeker
  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final kategoriler = await _api.getKategoriler();
      final icerikler = await _api.getIcerikler(
        kategoriId: _secilenKategoriId,
        tur: 'haber',
      );
      setState(() {
        _kategoriler = kategoriler;
        _icerikler = icerikler;
      });
    } catch (e) {
      setState(() => _hata = e.toString());
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  // Kategori seçilince filtreyi güncelle ve yeniden yükle
  void _kategoriSec(int? id) {
    setState(() => _secilenKategoriId = id);
    _verileriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FitRehber',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      body: Column(
        children: [
          // Kategori filtre çubuğu
          _kategoriCubugu(),
          // Makale listesi
          Expanded(child: _icerikAlani()),
        ],
      ),
    );
  }

  // Yatay kaydırılabilir kategori butonları
  Widget _kategoriCubugu() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // "Tümü" butonu
          _kategoriButon(null, 'Tümü'),
          // Her kategori için buton
          ..._kategoriler.map((k) => _kategoriButon(k.id, k.isim)),
        ],
      ),
    );
  }

  // Tek bir kategori butonu
  Widget _kategoriButon(int? id, String isim) {
    final secili = _secilenKategoriId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(isim),
        selected: secili,
        onSelected: (_) => _kategoriSec(id),
      ),
    );
  }

  // Yükleniyor/hata/liste durumuna göre içerik alanı
  Widget _icerikAlani() {
    if (_yukleniyor) return _shimmerListe();
    if (_hata != null) return _hataWidget();
    if (_icerikler.isEmpty) {
      return const Center(child: Text('Henüz içerik yok.'));
    }
    return _makaleListe();
  }

  // Yüklenirken gösterilen iskelet animasyonu
  Widget _shimmerListe() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1D27),
      highlightColor: const Color(0xFF2A2D37),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Hata durumunda gösterilen widget
  Widget _hataWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_hata!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _verileriYukle,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  // Makale listesi
  Widget _makaleListe() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _icerikler.length,
      itemBuilder: (context, index) => _makaleKarti(_icerikler[index]),
    );
  }

  // Tek bir makale kartı
  Widget _makaleKarti(IcerikModel icerik) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Makale detay ekranına git
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ArticleScreen(id: icerik.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icerik.resimUrl != null && icerik.resimUrl!.isNotEmpty) ...[
                _kapakResmi(icerik.resimUrl!),
              ],
              // Kategori etiketi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  icerik.kategoriAdi,
                  style: const TextStyle(
                    color: Color(0xFFF5A623),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Makale başlığı
              Text(
                icerik.baslik,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Yazar ve tarih
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    icerik.yazarAdi,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    icerik.tarihFormatli,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kapakResmi(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) => Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      placeholder: (context, url) => Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(color: const Color(0xFF2A2D37)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
}
