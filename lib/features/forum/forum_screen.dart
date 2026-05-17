import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/kategori_model.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<KategoriModel> _kategoriler = [];
  List<IcerikModel> _sorular = [];
  int? _secilenKategoriId;
  bool _yukleniyor = true;
  bool _dahaYukleniyor = false;
  bool _dahaVar = true;
  int _page = 1;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _verileriYukle();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 280) {
      _dahaYukle();
    }
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final kategoriler = await _api.getKategoriler();
      final sorular = await _api.getIcerikler(
        kategoriId: _secilenKategoriId,
        tur: 'soru',
        page: 1,
      );

      if (!mounted) return;
      setState(() {
        _kategoriler = kategoriler;
        _sorular = sorular;
        _page = 1;
        _dahaVar = sorular.length >= ApiConstants.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _dahaYukle() async {
    if (_dahaYukleniyor || !_dahaVar || _yukleniyor) return;
    setState(() => _dahaYukleniyor = true);
    try {
      final batch = await _api.getIcerikler(
        kategoriId: _secilenKategoriId,
        tur: 'soru',
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _sorular.addAll(batch);
        _dahaVar = batch.length >= ApiConstants.pageSize;
      });
    } catch (_) {
      // Sonraki sayfa hatası sessiz geçilir.
    } finally {
      if (mounted) setState(() => _dahaYukleniyor = false);
    }
  }

  void _kategoriSec(int? id) {
    setState(() => _secilenKategoriId = id);
    _verileriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forum')),
      body: Column(
        children: [
          _kategoriCubugu(),
          Expanded(child: _forumAlani()),
        ],
      ),
    );
  }

  Widget _kategoriCubugu() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _kategoriButon(null, 'Tümü'),
          ..._kategoriler.map((kategori) {
            return _kategoriButon(kategori.id, kategori.isim);
          }),
        ],
      ),
    );
  }

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

  Widget _forumAlani() {
    if (_yukleniyor) return _shimmerListe();
    if (_hata != null) return _hataWidget();
    if (_sorular.isEmpty) {
      return RefreshIndicator(
        onRefresh: _verileriYukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Henüz forum sorusu yok.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _verileriYukle,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _sorular.length + (_dahaVar ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _sorular.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _soruKarti(_sorular[index]);
        },
      ),
    );
  }

  Widget _shimmerListe() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1D27),
      highlightColor: const Color(0xFF2A2D37),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          height: 118,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _hataWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
      ),
    );
  }

  Widget _soruKarti(IcerikModel soru) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/makale/${soru.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (soru.resimUrl != null && soru.resimUrl!.isNotEmpty)
                _kapakResmi(soru.resimUrl!),
              Row(
                children: [
                  _etiket('Soru', const Color(0xFF22D3EE)),
                  const SizedBox(width: 8),
                  _etiket(soru.kategoriAdi, const Color(0xFFF5A623)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                soru.baslik,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: GestureDetector(
                      onTap: soru.yazarId == null
                          ? null
                          : () => context.push('/profil/${soru.yazarId}'),
                      child: Text(
                        soru.yazarAdi,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF22D3EE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: Color(0xFF22D3EE),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${soru.yorumSayisi} cevap',
                    style: const TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    soru.tarihFormatli,
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

  Widget _etiket(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
