// ---------------------------------------------------------------------------
// FORUM EKRANI
// ---------------------------------------------------------------------------
// Kullanıcıların birbirine soru sorduğu forum bölümü. Kategori filtresi ve
// sonsuz kaydırmalı soru listesi içerir; sağ alttaki butonla yeni soru
// sorma ekranına geçilir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_sabitleri.dart';
import '../../core/theme/uygulama_temasi.dart';
import '../../shared/api_servisi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/kategori_model.dart';
import '../../shared/sayfalama/sayfalama_yardimcilari.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/widgets/icerik_kart_parcalari.dart';

/// Forum sorularının listelendiği ekran.
class ForumEkrani extends ConsumerStatefulWidget {
  const ForumEkrani({super.key});

  @override
  ConsumerState<ForumEkrani> createState() => _ForumEkraniDurumu();
}

class _ForumEkraniDurumu extends ConsumerState<ForumEkrani> {
  ApiServisi get _api => ref.read(apiServisiProvider);
  final ScrollController _scrollController = ScrollController();
  final SayfalamaTetikleyici _sayfalamaTetikleyici = SayfalamaTetikleyici();

  List<KategoriModel> _kategoriler = [];
  List<IcerikModel> _sorular = [];
  int? _secilenKategoriId;
  // İlk yükleme henüz tamamlanmadıysa true; shimmer yalnızca bu durumda çıkar.
  bool _ilkYukleme = true;
  bool _yukleniyor = true;
  // Arama / kategori değişimi gibi sonraki yüklemeler için ince gösterge.
  bool _yenidenYukleniyor = false;
  bool _dahaYukleniyor = false;
  bool _dahaVar = true;
  int _page = 1;
  int _totalCount = 0;
  String? _hata;

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

  Future<void> _verileriYukle({bool kategorileriYenile = false}) async {
    // İlk yüklemede shimmer; sonraki yüklemelerde mevcut liste korunur.
    final ilk = _ilkYukleme;
    setState(() {
      if (ilk) {
        _yukleniyor = true;
      } else {
        _yenidenYukleniyor = true;
      }
      _hata = null;
    });

    try {
      final kategoriler = kategorileriYenile || _kategoriler.isEmpty
          ? await _api.kategorileriGetir()
          : _kategoriler;
      final response = await _api.icerikleriGetir(
        kategoriId: _secilenKategoriId,
        tur: 'soru',
        page: 1,
        pageSize: ApiSabitleri.pageSize,
      );

      if (!mounted) return;
      setState(() {
        _kategoriler = kategoriler;
        _sorular = response.sonuclar;
        _page = 1;
        _totalCount = response.toplam;
        _dahaVar = response.sonrakiVarMi;
      });
    } catch (e) {
      if (!mounted) return;
      // Sonraki yüklemelerde mevcut liste kaybolmasın; sadece bildirim göster.
      if (ilk) {
        setState(() => _hata = kullaniciDostuHata(e));
      } else {
        _snack(kullaniciDostuHata(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
          _yenidenYukleniyor = false;
          _ilkYukleme = false;
        });
      }
    }
  }

  Future<void> _dahaYukle() async {
    if (_dahaYukleniyor || !_dahaVar || _yukleniyor) return;
    setState(() => _dahaYukleniyor = true);
    try {
      final response = await _api.icerikleriGetir(
        kategoriId: _secilenKategoriId,
        tur: 'soru',
        page: _page + 1,
        pageSize: ApiSabitleri.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page += 1;
        _sorular.addAll(response.sonuclar);
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
      final sonuc = await _api.icerikBegenisiniDegistir(soru.id);
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
      _snack(kullaniciDostuHata(e));
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
      final sonuc = await _api.icerikKaydiniDegistir(soru.id);
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
      _snack(kullaniciDostuHata(e));
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
            style: FilledButton.styleFrom(backgroundColor: UygulamaTemasi.hata),
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
        title: const Text('Forum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Ara',
            onPressed: () => context.push('/arama'),
          ),
        ],
      ),
      floatingActionButton: _SoruSorFab(onTap: _soruSor),
      body: Column(
        children: [
          _kategoriCubugu(),
          // İnce gösterge: arama/kategori sırasında liste korunurken görünür.
          _yenidenYukleniyor
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
          Expanded(child: _forumAlani(canModerate, currentUserId)),
        ],
      ),
    );
  }

  Widget _kategoriCubugu() {
    return Semantics(
      label: 'Toplam forum sorusu sayısı $_totalCount',
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
              ..._kategoriler.map((kategori) {
                return _kategoriButon(kategori.id, kategori.isim);
              }),
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

  Widget _forumAlani(bool canModerate, int? currentUserId) {
    if (_yukleniyor) return const IcerikShimmerListe(itemHeight: 148);
    if (_hata != null) {
      return HataGorunumu(mesaj: _hata!, onRetry: () => _verileriYukle());
    }
    if (_sorular.isEmpty) {
      return RefreshIndicator(
        onRefresh: _yenile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            BosDurumGorunumu(
              ikon: Icons.forum_outlined,
              mesaj: 'Henuz forum sorusu yok.',
              altMesaj: 'İlk soruyu sorarak toplulukta tartışma başlatabilirsin.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _yenile,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _sorular.length + (_dahaVar ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _sorular.length) {
            return const Padding(
              key: ValueKey('forum-yukleniyor'),
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
            child: _soruKarti(_sorular[index], canModerate, currentUserId),
          );
        },
      ),
    );
  }

  Widget _soruKarti(IcerikModel soru, bool canModerate, int? currentUserId) {
    final canDelete = canModerate || currentUserId == soru.yazarId;

    return Card(
      key: ValueKey('soru-${soru.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(UygulamaTemasi.yaricap),
        onTap: () => context.push('/makale/${soru.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (soru.resimUrl != null && soru.resimUrl!.isNotEmpty)
              IcerikKapakResmi(url: soru.resimUrl!),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IcerikEtiket(
                        text: 'Soru',
                        color: UygulamaTemasi.anaRenk,
                        dolu: true,
                      ),
                      const SizedBox(width: 8),
                      IcerikEtiket(
                        text: soru.kategoriAdi,
                        color: UygulamaTemasi.ikincilMetin,
                        cizgili: true,
                      ),
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
                    soru.baslik,
                    style: UygulamaTemasi.baslik(fontSize: 18, height: 1.25),
                  ),
                  if (soru.ozet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      soru.ozet,
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
                          onTap: soru.yazarId == null
                              ? null
                              : () => context.push('/profil/${soru.yazarId}'),
                          child: Text(
                            soru.yazarAdi,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: UygulamaTemasi.ikincilMetin,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        soru.tarihFormatli,
                        style: const TextStyle(
                          color: UygulamaTemasi.ikincilMetin,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: UygulamaTemasi.ikincilMetin,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${soru.yorumSayisi} cevap',
                        style: const TextStyle(
                          color: UygulamaTemasi.ikincilMetin,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      HizliAksiyonButonu(
                        tooltip: 'Begen',
                        icon: soru.begendim
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: '${soru.begeniSayisi}',
                        color: soru.begendim
                            ? UygulamaTemasi.hata
                            : UygulamaTemasi.ikincilMetin,
                        onTap: () => _hizliBegen(soru),
                      ),
                      const SizedBox(width: 8),
                      HizliAksiyonButonu(
                        tooltip: 'Kaydet',
                        icon: soru.kaydedildi
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: '',
                        color: soru.kaydedildi
                            ? UygulamaTemasi.anaRenk
                            : UygulamaTemasi.ikincilMetin,
                        onTap: () => _hizliKaydet(soru),
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

class _SoruSorFab extends StatelessWidget {
  final VoidCallback onTap;

  const _SoruSorFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Soru sor',
      child: Material(
        color: UygulamaTemasi.anaRenk,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.edit_outlined, color: UygulamaTemasi.anaUstune),
          ),
        ),
      ),
    );
  }
}
