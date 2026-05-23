// ---------------------------------------------------------------------------
// ODAKLANMIŞ YORUM EKRANI
// ---------------------------------------------------------------------------
// Belirli bir yoruma "odaklanarak" açılan ekran. Genellikle bir bildirimden
// veya derin bağlantıdan (deep link) gelinir; ilgili yorum ve onun yanıt
// dizisi öne çıkarılarak gösterilir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api_servisi.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/models/yorum_model.dart';
import '../../shared/oturum_denetleyici.dart';
import 'widgets/yorum_giris_cubugu.dart';
import 'widgets/yorum_karti.dart';

/// Belirli bir yoruma odaklanarak o yorumu ve yanıtlarını gösteren ekran.
class OdakliYorumEkrani extends ConsumerStatefulWidget {
  /// Yorumun ait olduğu içeriğin kimliği.
  final int icerikId;

  /// Öne çıkarılacak (odaklanılacak) yorumun kimliği.
  final int focusCommentId;

  const OdakliYorumEkrani({
    super.key,
    required this.icerikId,
    required this.focusCommentId,
  });

  @override
  ConsumerState<OdakliYorumEkrani> createState() => _OdakliYorumEkraniDurumu();
}

class _OdakliYorumEkraniDurumu extends ConsumerState<OdakliYorumEkrani> {
  final ApiServisi _api = ApiServisi();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  IcerikModel? _icerik;
  List<YorumModel> _yorumlar = [];
  bool _yukleniyor = true;
  bool _yorumGonderiliyor = false;
  bool _changed = false;
  String? _hata;
  YorumModel? _yanitlananYorum;

  final Set<int> _acikYorumlar = {};

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final icerik = await _api.icerikDetayiniGetir(widget.icerikId);
      final duzListe = await _api.yorumlariGetir(
        widget.icerikId,
        odakId: widget.focusCommentId,
        depthLimit: defaultMaxInlineCommentDepth,
      );
      if (!mounted) return;
      final yorumlar = YorumModel.agacKur(duzListe);
      setState(() {
        _icerik = icerik;
        _yorumlar = yorumlar;
        _acikYorumlar
          ..clear()
          ..addAll(_acilacakYorumIdleri(yorumlar));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _yorumlariYenile() async {
    try {
      final duzListe = await _api.yorumlariGetir(
        widget.icerikId,
        odakId: widget.focusCommentId,
        depthLimit: defaultMaxInlineCommentDepth,
      );
      if (!mounted) return;
      final yorumlar = YorumModel.agacKur(duzListe);
      setState(() {
        _yorumlar = yorumlar;
        _acikYorumlar.addAll(_acilacakYorumIdleri(yorumlar));
      });
    } catch (e) {
      _snack(kullaniciDostuHata(e));
    }
  }

  Set<int> _acilacakYorumIdleri(List<YorumModel> yorumlar) {
    final ids = <int>{};
    void walk(List<YorumModel> liste) {
      for (final yorum in liste) {
        if (yorum.yanitlar.isNotEmpty) {
          ids.add(yorum.id);
          walk(yorum.yanitlar);
        }
      }
    }

    walk(yorumlar);
    return ids;
  }

  Future<void> _yorumGonder(String mesaj) async {
    if (_yorumGonderiliyor || mesaj.trim().isEmpty) return;
    final parentId = _yanitlananYorum?.id ?? widget.focusCommentId;

    setState(() => _yorumGonderiliyor = true);
    try {
      final yeniYorum = await _api.yorumEkle(
        widget.icerikId,
        mesaj: mesaj.trim(),
        parentId: parentId,
      );
      if (!mounted) return;
      setState(() {
        if (!_agacaYorumEkle(_yorumlar, parentId, yeniYorum)) {
          _yorumlar.add(yeniYorum);
        }
        _acikYorumlar.add(parentId);
        _icerik = _icerik?.copyWith(
          yorumSayisi: (_icerik?.yorumSayisi ?? 0) + 1,
        );
        _yanitlananYorum = null;
        _commentController.clear();
        _changed = true;
      });
      _commentFocusNode.unfocus();
    } catch (e) {
      _snack(kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _yorumGonderiliyor = false);
    }
  }

  bool _agacaYorumEkle(
    List<YorumModel> yorumlar,
    int parentId,
    YorumModel yeniYorum,
  ) {
    for (final yorum in yorumlar) {
      if (yorum.id == parentId) {
        yorum.yanitlar.add(yeniYorum);
        return true;
      }
      if (_agacaYorumEkle(yorum.yanitlar, parentId, yeniYorum)) {
        return true;
      }
    }
    return false;
  }

  bool _agactanYorumSil(List<YorumModel> yorumlar, int yorumId) {
    final index = yorumlar.indexWhere((yorum) => yorum.id == yorumId);
    if (index != -1) {
      yorumlar.removeAt(index);
      return true;
    }
    for (final yorum in yorumlar) {
      if (_agactanYorumSil(yorum.yanitlar, yorumId)) return true;
    }
    return false;
  }

  Future<void> _yorumBegen(YorumModel yorum) async {
    final oncekiBegendim = yorum.begendim;
    final oncekiSayi = yorum.begeniSayisi;
    setState(() {
      yorum.begendim = !yorum.begendim;
      yorum.begeniSayisi += yorum.begendim ? 1 : -1;
      if (yorum.begeniSayisi < 0) yorum.begeniSayisi = 0;
      _changed = true;
    });

    try {
      final sonuc = await _api.yorumBegenisiniDegistir(yorum.id);
      if (!mounted) return;
      setState(() {
        yorum.begendim = sonuc['begendim'] == true;
        final sayi = sonuc['begeni_sayisi'];
        yorum.begeniSayisi = sayi is int
            ? sayi
            : int.tryParse(sayi?.toString() ?? '') ?? yorum.begeniSayisi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        yorum.begendim = oncekiBegendim;
        yorum.begeniSayisi = oncekiSayi;
        _changed = true;
      });
      _snack(kullaniciDostuHata(e));
    }
  }

  Future<void> _yorumSil(YorumModel yorum) async {
    final confirmed = await _silmeOnayi('Bu yorum silinsin mi?');
    if (confirmed != true) return;

    try {
      await _api.yorumSil(yorum.id);
      if (!mounted) return;
      if (yorum.id == widget.focusCommentId) {
        context.go('/makale/${widget.icerikId}');
        return;
      }
      setState(() {
        final silinenAdet = yorum.toplamSayi;
        _agactanYorumSil(_yorumlar, yorum.id);
        _icerik = _icerik?.copyWith(
          yorumSayisi: ((_icerik?.yorumSayisi ?? silinenAdet) - silinenAdet)
              .clamp(0, 1 << 30)
              .toInt(),
        );
        _changed = true;
      });
    } catch (e) {
      _snack(kullaniciDostuHata(e));
    }
  }

  Future<bool?> _silmeOnayi(String mesaj) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Moderasyon'),
          content: Text(mesaj),
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
        );
      },
    );
  }

  void _yanitla(YorumModel yorum) {
    setState(() => _yanitlananYorum = yorum);
    _commentFocusNode.requestFocus();
  }

  void _yanitiIptalEt() {
    setState(() => _yanitlananYorum = null);
  }

  void _yanitGorunumunuDegistir(int yorumId) {
    setState(() {
      if (_acikYorumlar.contains(yorumId)) {
        _acikYorumlar.remove(yorumId);
      } else {
        _acikYorumlar.add(yorumId);
      }
    });
  }

  void _yazarProfiliAc(int? yazarId) {
    if (yazarId == null) return;
    context.push('/profil/$yazarId');
  }

  Future<void> _yorumDevaminiAc(YorumModel yorum) async {
    final changed = await context.push<bool>(
      '/makale/${widget.icerikId}/yorum/${yorum.id}',
    );
    if (changed == true && mounted) {
      _changed = true;
      _yorumlariYenile();
    }
  }

  void _geriDon() {
    if (context.canPop()) {
      context.pop(_changed);
    } else {
      context.go('/makale/${widget.icerikId}');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _canModerate(ProfilModel? profile) {
    return profile?.isStaff == true || profile?.isSuperuser == true;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(oturumDenetleyiciProvider).profile;
    final canModerate = _canModerate(profile);
    final currentUserId = profile?.id;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: _geriDon,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          _icerik?.baslik ?? 'Yorum akışı',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _govde(canModerate, currentUserId),
      bottomNavigationBar: _icerik == null || _yukleniyor
          ? null
          : YorumGirisCubugu(
              controller: _commentController,
              focusNode: _commentFocusNode,
              replyToUsername: _yanitlananYorum?.yazarAdi,
              isSending: _yorumGonderiliyor,
              onCancelReply: _yanitiIptalEt,
              onSend: _yorumGonder,
            ),
    );
  }

  Widget _ortala({required EdgeInsets padding, required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  Widget _govde(bool canModerate, int? currentUserId) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null) {
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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ortala(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: _odakBanner(),
          ),
        ),
        if (_yorumlar.isEmpty)
          SliverToBoxAdapter(
            child: _ortala(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Bu yorum akışı bulunamadı.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
            sliver: SliverList.builder(
              itemCount: _yorumlar.length,
              itemBuilder: (context, index) {
                final yorum = _yorumlar[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: YorumKarti(
                        key: ValueKey('odak-yorum-${yorum.id}'),
                        yorum: yorum,
                        depth: 0,
                        opAuthorName: _icerik?.yazarAdi,
                        canModerate: canModerate,
                        currentUserId: currentUserId,
                        expandedIds: _acikYorumlar,
                        onReply: _yanitla,
                        onLike: _yorumBegen,
                        onDelete: _yorumSil,
                        onToggleCollapse: _yanitGorunumunuDegistir,
                        onAuthorTap: _yazarProfiliAc,
                        onContinueThread: _yorumDevaminiAc,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _odakBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22D3EE).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.center_focus_strong_rounded,
                color: Color(0xFF22D3EE),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tek bir yorum akışını görüntülüyorsun',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _icerik?.baslik ?? 'Ana tartışmaya dönebilirsin.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/makale/${widget.icerikId}'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Tüm Tartışmaya Dön'),
            ),
          ),
        ],
      ),
    );
  }
}
