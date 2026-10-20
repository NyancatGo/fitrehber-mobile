// ---------------------------------------------------------------------------
// KATEGORİLER EKRANI
// ---------------------------------------------------------------------------
// İçerik kategorilerini listeler ve seçilen kategorinin içeriklerini listeler.
//
// Önceden bu ekran yalnızca "Kategoriler" yazan bir iskeletti (placeholder).
// Artık gerçek veriyi gösteriyor: kategori şeridi + seçili kategorinin
// içerik listesi.
//
// Veri akışı ana sayfa ile aynı mantığı izler: önce yerel önbellek (hızlı
// ilk açılış), sonra API'den taze veri.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_sabitleri.dart';
import '../../shared/api_servisi.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/kategori_model.dart';
import '../../shared/yerel_veritabani_servisi.dart';
import '../../shared/widgets/icerik_kart_parcalari.dart';

/// Kategori listesi ve seçili kategorinin içerikleri.
class KategorilerEkrani extends ConsumerStatefulWidget {
  const KategorilerEkrani({super.key});

  @override
  ConsumerState<KategorilerEkrani> createState() => _KategorilerEkraniState();
}

class _KategorilerEkraniState extends ConsumerState<KategorilerEkrani> {
  final ApiServisi _api = ApiServisi();

  /// Filtre şeridinde gösterilen kategoriler.
  List<KategoriModel> _kategoriler = [];

  /// Seçili kategori kimliği; `null` ise "Tümü".
  int? _secilenKategoriId;

  /// Ekranda gösterilen içerikler.
  List<IcerikModel> _icerikler = [];

  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle({bool kategorileriYenile = false}) async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    // Önce önbellek (ilk açılışı hızlandırır, çevrimdışı da çalışır).
    try {
      final cachedKat = (kategorileriYenile || _kategoriler.isEmpty)
          ? await YerelVeritabaniServisi.getCachedKategoriler()
          : _kategoriler;
      if (cachedKat.isNotEmpty && mounted) {
        setState(() => _kategoriler = cachedKat);
      }
    } catch (_) {
      // Önbellek okunamazsa sorun değil; API'den çekeceğiz.
    }

    // Sonra API'den taze veri.
    try {
      final kategoriler = (kategorileriYenile || _kategoriler.isEmpty)
          ? await _api.kategorileriGetir()
          : _kategoriler;
      final response = await _api.icerikleriGetir(
        kategoriId: _secilenKategoriId,
        page: 1,
        pageSize: ApiSabitleri.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _kategoriler = kategoriler;
        _icerikler = response.sonuclar;
        _yukleniyor = false;
      });
      YerelVeritabaniServisi.cacheKategoriler(kategoriler).ignore();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = _icerikler.isEmpty
            ? 'Kategoriler yüklenemedi. Bağlantınızı kontrol edin.'
            : null;
      });
    }
  }

  void _kategoriSec(int? id) {
    if (_secilenKategoriId == id) return;
    setState(() => _secilenKategoriId = id);
    _verileriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => _verileriYukle(kategorileriYenile: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _kategoriSeridi(),
          const Divider(height: 1),
          Expanded(child: _icerikAlani()),
        ],
      ),
    );
  }

  /// Üstteki yatay kaydırmalı kategori şeridi.
  Widget _kategoriSeridi() {
    if (_kategoriler.isEmpty) return const SizedBox(height: 56);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _kategoriButonu(null, 'Tümü'),
          ..._kategoriler.map((k) => _kategoriButonu(k.id, k.isim)),
        ],
      ),
    );
  }

  Widget _kategoriButonu(int? id, String isim) {
    final secili = _secilenKategoriId == id;
    return Padding(
      key: ValueKey('kategori-sekme-${id ?? 'tumu'}'),
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _kategoriSec(id),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: secili
                ? const Color(0xFFF5A623)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: secili
                  ? const Color(0xFFF5A623)
                  : const Color(0xFF334155),
            ),
          ),
          child: Text(
            isim,
            style: TextStyle(
              color: secili ? Colors.black : Colors.white,
              fontSize: 13,
              fontWeight: secili ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  /// Seçili kategorinin içerik listesi.
  Widget _icerikAlani() {
    if (_yukleniyor && _icerikler.isEmpty) {
      return const IcerikShimmerListe();
    }
    if (_hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 12),
              Text(
                _hata!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _verileriYukle(kategorileriYenile: true),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (_icerikler.isEmpty) {
      return const Center(
        child: Text(
          'Bu kategoride henüz içerik yok.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _icerikler.length,
      itemBuilder: (context, index) => _icerikKarti(_icerikler[index]),
    );
  }

  Widget _icerikKarti(IcerikModel icerik) {
    return Card(
      key: ValueKey('kategori-icerik-${icerik.id}'),
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
                IcerikKapakResmi(url: icerik.resimUrl!),
              IcerikEtiket(
                text: icerik.kategoriAdi,
                color: const Color(0xFFF5A623),
              ),
              const SizedBox(height: 8),
              Text(
                icerik.baslik,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (icerik.ozet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  icerik.ozet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
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
