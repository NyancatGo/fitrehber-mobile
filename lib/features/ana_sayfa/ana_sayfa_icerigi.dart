// ---------------------------------------------------------------------------
// ANA SAYFA İÇERİĞİ
// ---------------------------------------------------------------------------
// "Ana Sayfa" sekmesinin içeriği: kategori filtre çubuğu ve sonsuz kaydırmalı
// makale (haber) listesi. Performans için iki katmanlı veri akışı kullanır:
//   1. Önce yerel önbellekten yükler (ekran anında dolar),
//   2. Sonra API'den taze veri çekip listeyi günceller ve yeniden önbelleğe yazar.
// İnternet yoksa çevrimdışı bilgi şeridi gösterilir, önbellekteki veri kalır.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_sabitleri.dart';
import '../../shared/api_servisi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/yerel_veritabani_servisi.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/kategori_model.dart';
import '../../shared/sayfalama/sayfalama_yardimcilari.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/widgets/icerik_kart_parcalari.dart';

/// Ana sayfa sekmesinin gövdesi: kategori filtresi + makale listesi.
class AnaSayfaIcerigi extends ConsumerStatefulWidget {
  const AnaSayfaIcerigi({super.key});

  @override
  ConsumerState<AnaSayfaIcerigi> createState() => _AnaSayfaIcerigiDurumu();
}

class _AnaSayfaIcerigiDurumu extends ConsumerState<AnaSayfaIcerigi> {
  /// Backend ile konuşan API servisi.
  final ApiServisi _api = ApiServisi();

  /// Liste kaydırma konumunu izleyen denetleyici (sonsuz kaydırma için).
  final ScrollController _scrollController = ScrollController();

  /// Liste sonuna yaklaşıldığında yeni sayfa yüklenmesini tetikleyen yardımcı.
  final SayfalamaTetikleyici _sayfalamaTetikleyici = SayfalamaTetikleyici();

  /// Filtre çubuğunda gösterilen kategoriler.
  List<KategoriModel> _kategoriler = [];

  /// Ekranda gösterilen makale listesi.
  List<IcerikModel> _icerikler = [];

  /// Seçili kategori kimliği; `null` ise "Tümü" seçilidir.
  int? _secilenKategoriId;

  /// İlk veri yüklemesi sürüyor mu? (iskelet/shimmer gösterilir)
  bool _yukleniyor = true;

  /// Bir sonraki sayfa yükleniyor mu?
  bool _dahaYukleniyor = false;

  /// Yüklenecek daha fazla sayfa var mı?
  bool _dahaVar = true;

  /// Şu an gösterilen sayfa numarası.
  int _page = 1;

  /// Tüm kategorideki toplam içerik sayısı.
  int _totalCount = 0;

  /// İlk yüklemede oluşan hata mesajı (yoksa `null`).
  String? _hata;

  /// İnternet yokken önbellekten gösteriliyorsa `true` (çevrimdışı şeridi).
  bool _cevrimdisi = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _verileriYukle(kategorileriYenile: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_sayfalamaTetikleyici.yuklemeliMi(_scrollController)) {
      _dahaYukle();
    }
  }

  /// Kategori ve içerik verilerini yükler.
  ///
  /// Önce önbellekten hızlı bir görünüm sunar, ardından API'den taze veri
  /// çekip ekranı günceller. [kategorileriYenile] `true` ise kategori listesi
  /// de yeniden çekilir.
  Future<void> _verileriYukle({bool kategorileriYenile = false}) async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    // Önce önbellekten yükle (ilk açılışı hızlandırır).
    try {
      final cachedKat = (kategorileriYenile || _kategoriler.isEmpty)
          ? await YerelVeritabaniServisi.getCachedKategoriler()
          : _kategoriler;
      final cachedIce = await YerelVeritabaniServisi.getCachedIcerikler();
      if (cachedIce.isNotEmpty && mounted) {
        setState(() {
          if (cachedKat.isNotEmpty) _kategoriler = cachedKat;
          _icerikler = cachedIce;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      // Önbellek okunamadıysa sessizce geç.
    }

    // Sonra API'den güncel veri çek.
    try {
      final kategoriler = (kategorileriYenile || _kategoriler.isEmpty)
          ? await _api.kategorileriGetir()
          : _kategoriler;
      final response = await _api.icerikleriGetir(
        kategoriId: _secilenKategoriId,
        tur: 'haber',
        page: 1,
        pageSize: ApiSabitleri.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _kategoriler = kategoriler;
        _icerikler = response.sonuclar;
        _page = 1;
        _totalCount = response.toplam;
        _dahaVar = response.sonrakiVarMi;
        _cevrimdisi = false;
      });
      // Güncel veriyi önbelleğe yaz.
      YerelVeritabaniServisi.cacheIcerikler(response.sonuclar).ignore();
      YerelVeritabaniServisi.cacheKategoriler(kategoriler).ignore();
    } catch (e) {
      if (!mounted) return;
      if (_icerikler.isNotEmpty) {
        // Önbellekten yüklenmiş veri var → çevrimdışı banner göster.
        setState(() => _cevrimdisi = true);
      } else {
        setState(() => _hata = kullaniciDostuHata(e));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  /// Listenin sonuna gelindiğinde bir sonraki sayfayı yükler (sonsuz kaydırma).
  Future<void> _dahaYukle() async {
    if (_dahaYukleniyor || !_dahaVar || _yukleniyor) return;
    setState(() => _dahaYukleniyor = true);
    try {
      final response = await _api.icerikleriGetir(
        kategoriId: _secilenKategoriId,
        tur: 'haber',
        page: _page + 1,
        pageSize: ApiSabitleri.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _icerikler.addAll(response.sonuclar);
        _dahaVar = response.sonrakiVarMi;
      });
    } catch (_) {
      if (mounted) sayfalamaYuklemeHatasiGoster(context, onRetry: _dahaYukle);
    } finally {
      if (mounted) setState(() => _dahaYukleniyor = false);
    }
  }

  void _kategoriSec(int? id) {
    setState(() => _secilenKategoriId = id);
    _verileriYukle();
  }

  Future<void> _yenile() => _verileriYukle(kategorileriYenile: true);

  /// Bir içeriği hızlıca beğenir/beğeniyi geri alır.
  ///
  /// "İyimser güncelleme" uygular: arayüz hemen değişir, API isteği başarısız
  /// olursa eski durum geri yüklenir — böylece kullanıcı beklemez.
  Future<void> _hizliBegen(IcerikModel icerik) async {
    final index = _icerikler.indexWhere((item) => item.id == icerik.id);
    if (index == -1) return;
    // Hata olursa geri dönebilmek için içeriğin önceki halini saklıyoruz.
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
      final sonuc = await _api.icerikBegenisiniDegistir(icerik.id);
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
      _snack(kullaniciDostuHata(e));
    }
  }

  /// Bir içeriği hızlıca kaydeder/kaydı geri alır (iyimser güncellemeyle).
  Future<void> _hizliKaydet(IcerikModel icerik) async {
    final index = _icerikler.indexWhere((item) => item.id == icerik.id);
    if (index == -1) return;
    final onceki = _icerikler[index];
    setState(() {
      _icerikler[index] = onceki.copyWith(kaydedildi: !onceki.kaydedildi);
    });

    try {
      final sonuc = await _api.icerikKaydiniDegistir(icerik.id);
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
      _snack(kullaniciDostuHata(e));
    }
  }

  /// Bir içeriği, onay penceresi gösterdikten sonra siler (moderasyon yetkisi).
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
      _snack(kullaniciDostuHata(e));
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
    final profile = ref.watch(oturumDenetleyiciProvider).profile;
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
          if (_cevrimdisi)
            MaterialBanner(
              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.9),
              content: const Text(
                'Çevrimdışı modda çalışıyorsunuz. Gösterilen veriler önbellekten.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => _verileriYukle(kategorileriYenile: true),
                  child: const Text(
                    'Tekrar Dene',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          _kategoriCubugu(),
          Expanded(child: _icerikAlani(canModerate, currentUserId)),
        ],
      ),
    );
  }

  /// Ekranın üstündeki yatay kaydırmalı kategori filtre çubuğunu oluşturur.
  Widget _kategoriCubugu() {
    return Semantics(
      label: 'Toplam içerik sayısı $_totalCount',
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _kategoriButon(null, 'Tumu'),
            ..._kategoriler.map((k) => _kategoriButon(k.id, k.isim)),
          ],
        ),
      ),
    );
  }

  Widget _kategoriButon(int? id, String isim) {
    final secili = _secilenKategoriId == id;
    return Padding(
      key: ValueKey('kategori-${id ?? 'tumu'}'),
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

  /// İçerik alanını duruma göre oluşturur: yükleniyor / hata / boş / liste.
  Widget _icerikAlani(bool canModerate, int? currentUserId) {
    if (_yukleniyor) return const IcerikShimmerListe();
    if (_hata != null) {
      return HataGorunumu(mesaj: _hata!, onRetry: () => _verileriYukle());
    }
    if (_icerikler.isEmpty) {
      return RefreshIndicator(
        onRefresh: _yenile,
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

  Widget _makaleListe(bool canModerate, int? currentUserId) {
    return RefreshIndicator(
      onRefresh: _yenile,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _icerikler.length + (_dahaVar ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _icerikler.length) {
            return const Padding(
              key: ValueKey('home-yukleniyor'),
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

  /// Tek bir makaleyi temsil eden kartı oluşturur (kapak, başlık, özet,
  /// yazar, beğen/kaydet butonları ve yetkiliyse silme menüsü).
  Widget _makaleKarti(
    IcerikModel icerik,
    bool canModerate,
    int? currentUserId,
  ) {
    final canDelete = canModerate || currentUserId == icerik.yazarId;

    return Card(
      key: ValueKey('icerik-${icerik.id}'),
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
              Row(
                children: [
                  IcerikEtiket(
                    text: icerik.kategoriAdi,
                    color: const Color(0xFFF5A623),
                  ),
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
              if (icerik.ozet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  icerik.ozet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
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
                  HizliAksiyonButonu(
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
                  HizliAksiyonButonu(
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
}
