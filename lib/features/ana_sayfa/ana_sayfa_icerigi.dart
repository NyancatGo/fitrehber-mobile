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
import '../../core/theme/uygulama_temasi.dart';
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
  ApiServisi get _api => ref.read(apiServisiProvider);

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
            style: FilledButton.styleFrom(backgroundColor: UygulamaTemasi.hata),
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
        title: const Text('FitRehber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Ara',
            onPressed: () => context.push('/arama'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_cevrimdisi)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: UygulamaTemasi.yuzey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: UygulamaTemasi.cizgi),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: UygulamaTemasi.anaRenk,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Çevrimdışı modda çalışıyorsunuz. Gösterilen veriler önbellekten.',
                        style: TextStyle(
                          color: UygulamaTemasi.anaMetin,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _verileriYukle(kategorileriYenile: true),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
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
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: UygulamaTemasi.cizgi)),
        ),
        child: SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _kategoriButon(null, 'Tümü'),
              ..._kategoriler.map((k) => _kategoriButon(k.id, k.isim)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kategoriButon(int? id, String isim) {
    final secili = _secilenKategoriId == id;
    return SecimYongasi(
      key: ValueKey('kategori-${id ?? 'tumu'}'),
      etiket: isim,
      secili: secili,
      onTap: () => _kategoriSec(id),
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
            SizedBox(height: 80),
            BosDurumGorunumu(
              ikon: Icons.article_outlined,
              mesaj: 'Henüz içerik yok.',
              altMesaj:
                  'Bu kategoride henüz yayınlanmış bir makale bulunmuyor.',
            ),
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
          return RepaintBoundary(
            child: _makaleKarti(_icerikler[index], canModerate, currentUserId),
          );
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
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        onTap: () => context.push('/makale/${icerik.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icerik.resimUrl != null && icerik.resimUrl!.isNotEmpty)
              IcerikKapakResmi(url: icerik.resimUrl!),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IcerikEtiket(
                        text: icerik.kategoriAdi,
                        color: UygulamaTemasi.ikincilMetin,
                        cizgili: true,
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
                                    color: UygulamaTemasi.hata,
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
                    style: UygulamaTemasi.baslik(fontSize: 18, height: 1.25),
                  ),
                  if (icerik.ozet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      icerik.ozet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: UygulamaTemasi.ikincilMetin,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: UygulamaTemasi.ikincilMetin,
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
                              color: UygulamaTemasi.ikincilMetin,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(
                          color: UygulamaTemasi.ikincilMetin,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        icerik.tarihFormatli,
                        style: const TextStyle(
                          color: UygulamaTemasi.ikincilMetin,
                          fontSize: 12,
                        ),
                      ),
                      if (icerik.yorumSayisi > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 13,
                          color: UygulamaTemasi.ikincilMetin,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${icerik.yorumSayisi}',
                          style: const TextStyle(
                            color: UygulamaTemasi.ikincilMetin,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      HizliAksiyonButonu(
                        tooltip: 'Begen',
                        icon: icerik.begendim
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: '${icerik.begeniSayisi}',
                        color: icerik.begendim
                            ? UygulamaTemasi.hata
                            : UygulamaTemasi.ikincilMetin,
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
                            ? UygulamaTemasi.anaRenk
                            : UygulamaTemasi.ikincilMetin,
                        onTap: () => _hizliKaydet(icerik),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
