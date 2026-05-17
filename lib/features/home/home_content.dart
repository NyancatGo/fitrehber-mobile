import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/api_constants.dart';
import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/kategori_model.dart';
import '../../shared/session_controller.dart';

class HomeContent extends ConsumerStatefulWidget {
  const HomeContent({super.key});

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<KategoriModel> _kategoriler = [];
  List<IcerikModel> _icerikler = [];
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
      final icerikler = await _api.getIcerikler(
        kategoriId: _secilenKategoriId,
        tur: 'haber',
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _kategoriler = kategoriler;
        _icerikler = icerikler;
        _page = 1;
        _dahaVar = icerikler.length >= ApiConstants.pageSize;
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
        tur: 'haber',
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _icerikler.addAll(batch);
        _dahaVar = batch.length >= ApiConstants.pageSize;
      });
    } catch (_) {
      // Sonraki sayfa hatasi sessiz gecilir.
    } finally {
      if (mounted) setState(() => _dahaYukleniyor = false);
    }
  }

  void _kategoriSec(int? id) {
    setState(() => _secilenKategoriId = id);
    _verileriYukle();
  }

  Future<void> _hizliBegen(IcerikModel icerik) async {
    final index = _icerikler.indexWhere((item) => item.id == icerik.id);
    if (index == -1) return;
    final onceki = _icerikler[index];
    setState(() {
      _icerikler[index] = onceki.copyWith(
        begendim: !onceki.begendim,
        begeniSayisi: (onceki.begeniSayisi + (onceki.begendim ? -1 : 1))
            .clamp(0, 1 << 30)
            .toInt(),
      );
    });

    try {
      final sonuc = await _api.toggleIcerikBegeni(icerik.id);
      if (!mounted) return;
      final currentIndex = _icerikler.indexWhere(
        (item) => item.id == icerik.id,
      );
      if (currentIndex == -1) return;
      final sayi = sonuc['begeni_sayisi'];
      setState(() {
        _icerikler[currentIndex] = _icerikler[currentIndex].copyWith(
          begendim: sonuc['begendim'] == true,
          begeniSayisi: sayi is int
              ? sayi
              : int.tryParse(sayi?.toString() ?? '') ??
                    _icerikler[currentIndex].begeniSayisi,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _icerikler[index] = onceki);
      _snack(e.toString());
    }
  }

  Future<void> _hizliKaydet(IcerikModel icerik) async {
    final index = _icerikler.indexWhere((item) => item.id == icerik.id);
    if (index == -1) return;
    final onceki = _icerikler[index];
    setState(() {
      _icerikler[index] = onceki.copyWith(kaydedildi: !onceki.kaydedildi);
    });

    try {
      final sonuc = await _api.toggleIcerikKaydet(icerik.id);
      if (!mounted) return;
      final currentIndex = _icerikler.indexWhere(
        (item) => item.id == icerik.id,
      );
      if (currentIndex == -1) return;
      setState(() {
        _icerikler[currentIndex] = _icerikler[currentIndex].copyWith(
          kaydedildi: sonuc['kaydedildi'] == true,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _icerikler[index] = onceki);
      _snack(e.toString());
    }
  }

  Future<void> _icerikSil(IcerikModel icerik) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderasyon'),
        content: const Text('Bu icerik silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.icerikSil(icerik.id);
      if (!mounted) return;
      setState(() => _icerikler.removeWhere((item) => item.id == icerik.id));
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionControllerProvider).profile;
    final canModerate =
        profile?.isStaff == true || profile?.isSuperuser == true;
    final currentUserId = profile?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FitRehber',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/arama'),
          ),
        ],
      ),
      body: Column(
        children: [
          _kategoriCubugu(),
          Expanded(child: _icerikAlani(canModerate, currentUserId)),
        ],
      ),
    );
  }

  Widget _kategoriCubugu() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _kategoriButon(null, 'Tumu'),
          ..._kategoriler.map((k) => _kategoriButon(k.id, k.isim)),
        ],
      ),
    );
  }

  Widget _kategoriButon(int? id, String isim) {
    final secili = _secilenKategoriId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _kategoriSec(id),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: secili
                ? const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                  )
                : null,
            color: secili ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: secili
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            isim,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: secili ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _icerikAlani(bool canModerate, int? currentUserId) {
    if (_yukleniyor) return _shimmerListe();
    if (_hata != null) return _hataWidget();
    if (_icerikler.isEmpty) {
      return RefreshIndicator(
        onRefresh: _verileriYukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Henuz icerik yok.')),
          ],
        ),
      );
    }
    return _makaleListe(canModerate, currentUserId);
  }

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
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

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

  Widget _makaleListe(bool canModerate, int? currentUserId) {
    return RefreshIndicator(
      onRefresh: _verileriYukle,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _icerikler.length + (_dahaVar ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _icerikler.length) {
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
          return _makaleKarti(_icerikler[index], canModerate, currentUserId);
        },
      ),
    );
  }

  Widget _makaleKarti(
    IcerikModel icerik,
    bool canModerate,
    int? currentUserId,
  ) {
    final canDelete = canModerate || currentUserId == icerik.yazarId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/makale/${icerik.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icerik.resimUrl != null && icerik.resimUrl!.isNotEmpty)
                _kapakResmi(icerik.resimUrl!),
              Row(
                children: [
                  _etiket(icerik.kategoriAdi, const Color(0xFFF5A623)),
                  const Spacer(),
                  if (canDelete)
                    PopupMenuButton<String>(
                      tooltip: 'Moderasyon',
                      onSelected: (value) {
                        if (value == 'delete') _icerikSil(icerik);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(width: 8),
                              Text('Sil'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                icerik.baslik,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
                      onTap: icerik.yazarId == null
                          ? null
                          : () => context.push('/profil/${icerik.yazarId}'),
                      child: Text(
                        icerik.yazarAdi,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF22D3EE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    icerik.tarihFormatli,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _QuickActionButton(
                    tooltip: 'Begen',
                    icon: icerik.begendim
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: '${icerik.begeniSayisi}',
                    color: icerik.begendim
                        ? const Color(0xFFEF4444)
                        : Colors.white70,
                    onTap: () => _hizliBegen(icerik),
                  ),
                  const SizedBox(width: 8),
                  _QuickActionButton(
                    tooltip: 'Kaydet',
                    icon: icerik.kaydedildi
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: '',
                    color: icerik.kaydedildi
                        ? const Color(0xFFF5A623)
                        : Colors.white70,
                    onTap: () => _hizliKaydet(icerik),
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
        color: color.withValues(alpha: 0.2),
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

class _QuickActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Tooltip(
        message: tooltip,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
