import 'dart:async';

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

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _aramaController = TextEditingController();

  List<KategoriModel> _kategoriler = [];
  List<IcerikModel> _sorular = [];
  int? _secilenKategoriId;
  bool _yukleniyor = true;
  bool _dahaYukleniyor = false;
  bool _dahaVar = true;
  int _page = 1;
  String? _hata;
  Timer? _aramaDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _aramaController.addListener(_aramaDegisti);
    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaDebounce?.cancel();
    _aramaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 280) {
      _dahaYukle();
    }
  }

  void _aramaDegisti() {
    _aramaDebounce?.cancel();
    _aramaDebounce = Timer(const Duration(milliseconds: 360), _verileriYukle);
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
        arama: _aramaController.text.trim(),
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
        arama: _aramaController.text.trim(),
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _sorular.addAll(batch);
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

  Future<void> _soruSor() async {
    final yeniSoru = await context.push<IcerikModel>('/forum/soru-sor');
    if (yeniSoru == null || !mounted) return;
    setState(() => _sorular.insert(0, yeniSoru));
  }

  Future<void> _hizliBegen(IcerikModel soru) async {
    final index = _sorular.indexWhere((item) => item.id == soru.id);
    if (index == -1) return;
    final onceki = _sorular[index];
    setState(() {
      _sorular[index] = onceki.copyWith(
        begendim: !onceki.begendim,
        begeniSayisi: (onceki.begeniSayisi + (onceki.begendim ? -1 : 1))
            .clamp(0, 1 << 30)
            .toInt(),
      );
    });

    try {
      final sonuc = await _api.toggleIcerikBegeni(soru.id);
      if (!mounted) return;
      final currentIndex = _sorular.indexWhere((item) => item.id == soru.id);
      if (currentIndex == -1) return;
      final sayi = sonuc['begeni_sayisi'];
      setState(() {
        _sorular[currentIndex] = _sorular[currentIndex].copyWith(
          begendim: sonuc['begendim'] == true,
          begeniSayisi: sayi is int
              ? sayi
              : int.tryParse(sayi?.toString() ?? '') ??
                    _sorular[currentIndex].begeniSayisi,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _sorular[index] = onceki);
      _snack(e.toString());
    }
  }

  Future<void> _hizliKaydet(IcerikModel soru) async {
    final index = _sorular.indexWhere((item) => item.id == soru.id);
    if (index == -1) return;
    final onceki = _sorular[index];
    setState(() {
      _sorular[index] = onceki.copyWith(kaydedildi: !onceki.kaydedildi);
    });

    try {
      final sonuc = await _api.toggleIcerikKaydet(soru.id);
      if (!mounted) return;
      final currentIndex = _sorular.indexWhere((item) => item.id == soru.id);
      if (currentIndex == -1) return;
      setState(() {
        _sorular[currentIndex] = _sorular[currentIndex].copyWith(
          kaydedildi: sonuc['kaydedildi'] == true,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _sorular[index] = onceki);
      _snack(e.toString());
    }
  }

  Future<void> _soruSil(IcerikModel soru) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderasyon'),
        content: const Text('Bu soru silinsin mi?'),
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
      await _api.icerikSil(soru.id);
      if (!mounted) return;
      setState(() => _sorular.removeWhere((item) => item.id == soru.id));
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
      appBar: AppBar(title: const Text('Forum')),
      floatingActionButton: _SoruSorFab(onTap: _soruSor),
      body: Column(
        children: [
          _aramaKutusu(),
          _kategoriCubugu(),
          Expanded(child: _forumAlani(canModerate, currentUserId)),
        ],
      ),
    );
  }

  Widget _aramaKutusu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TextField(
          controller: _aramaController,
          decoration: InputDecoration(
            hintText: 'Forumda ara',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _aramaController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Temizle',
                    onPressed: () {
                      _aramaController.clear();
                      _verileriYukle();
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
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

  Widget _forumAlani(bool canModerate, int? currentUserId) {
    if (_yukleniyor) return _shimmerListe();
    if (_hata != null) return _hataWidget();
    if (_sorular.isEmpty) {
      return RefreshIndicator(
        onRefresh: _verileriYukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Henuz forum sorusu yok.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _verileriYukle,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
          return _soruKarti(_sorular[index], canModerate, currentUserId);
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
            borderRadius: BorderRadius.circular(8),
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

  Widget _soruKarti(IcerikModel soru, bool canModerate, int? currentUserId) {
    final canDelete = canModerate || currentUserId == soru.yazarId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
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
                  const Spacer(),
                  if (canDelete)
                    PopupMenuButton<String>(
                      tooltip: 'Moderasyon',
                      onSelected: (value) {
                        if (value == 'delete') _soruSil(soru);
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
                  Text(
                    soru.tarihFormatli,
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
                    icon: soru.begendim
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: '${soru.begeniSayisi}',
                    color: soru.begendim
                        ? const Color(0xFFEF4444)
                        : Colors.white70,
                    onTap: () => _hizliBegen(soru),
                  ),
                  const SizedBox(width: 8),
                  _QuickActionButton(
                    tooltip: 'Kaydet',
                    icon: soru.kaydedildi
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    label: '',
                    color: soru.kaydedildi
                        ? const Color(0xFFF5A623)
                        : Colors.white70,
                    onTap: () => _hizliKaydet(soru),
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

class _SoruSorFab extends StatelessWidget {
  final VoidCallback onTap;

  const _SoruSorFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Soru Sor',
        onPressed: onTap,
        icon: const Icon(Icons.edit_note_outlined, color: Colors.white),
      ),
    );
  }
}
