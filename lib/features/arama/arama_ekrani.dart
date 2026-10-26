// ---------------------------------------------------------------------------
// İÇERİK ARAMA EKRANI
// ---------------------------------------------------------------------------
// Kullanıcının başlığa göre içerik (haber + forum sorusu) aradığı ekran.
// Sonuçlar sayfalıdır: liste sonuna gelindiğinde sonraki sayfa otomatik yüklenir.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_sabitleri.dart';
import '../../core/theme/uygulama_temasi.dart';
import '../../shared/api_servisi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/sayfalama/sayfalama_yardimcilari.dart';
import '../../shared/widgets/icerik_kart_parcalari.dart';

/// Başlığa göre içerik araması yapılan ekran.
class AramaEkrani extends ConsumerStatefulWidget {
  const AramaEkrani({super.key});

  @override
  ConsumerState<AramaEkrani> createState() => _AramaEkraniDurumu();
}

class _AramaEkraniDurumu extends ConsumerState<AramaEkrani> {
  ApiServisi get _api => ref.read(apiServisiProvider);
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
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'İçerik ara...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: _aramayiTemizle,
                  );
                },
              ),
            ),
            onChanged: _aramaDegisti,
            onSubmitted: (deger) => _ara(deger.trim()),
          ),
        ),
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (_yukleniyor) {
      return const IcerikShimmerListe(itemHeight: 96);
    }
    if (_hata != null) {
      return HataGorunumu(mesaj: _hata!, onRetry: () => _ara(_sonAranan));
    }
    if (_sonAranan.length < 2) {
      return const BosDurumGorunumu(
        ikon: Icons.search_rounded,
        mesaj: 'Aramak için en az 2 harf yaz.',
        altMesaj: 'Makale ve forum sorularında başlığa göre arama yapabilirsin.',
      );
    }
    if (_sonuclar.isEmpty) {
      return BosDurumGorunumu(
        ikon: Icons.search_off_rounded,
        mesaj: '"$_sonAranan" için sonuç bulunamadı.',
        altMesaj: 'Farklı bir anahtar kelimeyle tekrar deneyebilirsin.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
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
        return RepaintBoundary(child: _sonucKarti(_sonuclar[index]));
      },
    );
  }

  Widget _sonucKarti(IcerikModel icerik) {
    final forumMu = icerik.tur == 'soru';
    return Card(
      key: ValueKey('arama-${icerik.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        ),
        leading: icerik.resimUrl != null && icerik.resimUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: icerik.resimUrl!,
                  memCacheWidth: 160,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: UygulamaTemasi.cizgi),
                  errorWidget: (c, u, e) => const Icon(Icons.image),
                ),
              )
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: UygulamaTemasi.anaRenk.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  forumMu ? Icons.forum_outlined : Icons.article_outlined,
                  color: UygulamaTemasi.anaRenk,
                  size: 20,
                ),
              ),
        title: Text(
          icerik.baslik,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            height: 1.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${forumMu ? 'Forum' : icerik.kategoriAdi} · ${icerik.tarihFormatli}',
            style: const TextStyle(
              fontSize: 12,
              color: UygulamaTemasi.ikincilMetin,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: UygulamaTemasi.ikincilMetin,
          size: 20,
        ),
        onTap: () => context.push('/makale/${icerik.id}'),
      ),
    );
  }
}
