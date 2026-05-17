import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api_service.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/models/yorum_model.dart';
import '../../shared/session_controller.dart';
import 'widgets/article_content_renderer.dart';
import 'widgets/comment_input_bar.dart';
import 'widgets/comment_skeleton.dart';
import 'widgets/comment_tile.dart';

class ArticleScreen extends ConsumerStatefulWidget {
  final int id;
  const ArticleScreen({super.key, required this.id});

  @override
  ConsumerState<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends ConsumerState<ArticleScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  IcerikModel? _icerik;
  bool _yukleniyor = true;
  String? _hata;

  List<YorumModel> _yorumlar = [];
  bool _yorumlarYukleniyor = false;
  bool _yorumGonderiliyor = false;
  bool _icerikAksiyonuBekliyor = false;
  String? _yorumHata;
  YorumModel? _yanitlananYorum;

  // Yanıtları gizlenmiş (daraltılmış) yorum id'leri.
  final Set<int> _kapaliYorumlar = {};

  @override
  void initState() {
    super.initState();
    _icerikYukle();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _icerikYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final icerik = await _api.getIcerikDetay(widget.id);
      if (!mounted) return;
      setState(() => _icerik = icerik);
      _yorumlariYukle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _yorumlariYukle() async {
    setState(() {
      _yorumlarYukleniyor = true;
      _yorumHata = null;
    });
    try {
      final duzListe = await _api.getYorumlar(widget.id);
      if (!mounted) return;
      setState(() => _yorumlar = YorumModel.agacKur(duzListe));
    } catch (e) {
      if (!mounted) return;
      setState(() => _yorumHata = kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _yorumlarYukleniyor = false);
    }
  }

  Future<void> _yorumGonder(String mesaj) async {
    if (_yorumGonderiliyor || mesaj.trim().isEmpty) return;
    final parentId = _yanitlananYorum?.id;

    setState(() => _yorumGonderiliyor = true);
    try {
      final yeniYorum = await _api.yorumEkle(
        widget.id,
        mesaj: mesaj.trim(),
        parentId: parentId,
      );
      if (!mounted) return;
      setState(() {
        if (parentId == null ||
            !_agacaYorumEkle(_yorumlar, parentId, yeniYorum)) {
          _yorumlar.add(yeniYorum);
        }
        _icerik = _icerik?.copyWith(
          yorumSayisi: (_icerik?.yorumSayisi ?? 0) + 1,
        );
        _yanitlananYorum = null;
        _commentController.clear();
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
    });

    try {
      final sonuc = await _api.toggleYorumBegeni(yorum.id);
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
      });
      _snack(kullaniciDostuHata(e));
    }
  }

  Future<void> _icerikBegen() async {
    final mevcut = _icerik;
    if (mevcut == null || _icerikAksiyonuBekliyor) return;

    final onceki = mevcut;
    setState(() {
      _icerikAksiyonuBekliyor = true;
      _icerik = mevcut.copyWith(
        begendim: !mevcut.begendim,
        begeniSayisi: (mevcut.begeniSayisi + (mevcut.begendim ? -1 : 1))
            .clamp(0, 1 << 30)
            .toInt(),
      );
    });

    try {
      final sonuc = await _api.toggleIcerikBegeni(mevcut.id);
      if (!mounted) return;
      final sayi = sonuc['begeni_sayisi'];
      setState(() {
        _icerik = _icerik?.copyWith(
          begendim: sonuc['begendim'] == true,
          begeniSayisi: sayi is int
              ? sayi
              : int.tryParse(sayi?.toString() ?? '') ?? _icerik!.begeniSayisi,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _icerik = onceki);
      _snack(kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _icerikAksiyonuBekliyor = false);
    }
  }

  Future<void> _icerikKaydet() async {
    final mevcut = _icerik;
    if (mevcut == null || _icerikAksiyonuBekliyor) return;

    final onceki = mevcut;
    setState(() {
      _icerikAksiyonuBekliyor = true;
      _icerik = mevcut.copyWith(kaydedildi: !mevcut.kaydedildi);
    });

    try {
      final sonuc = await _api.toggleIcerikKaydet(mevcut.id);
      if (!mounted) return;
      setState(() {
        _icerik = _icerik?.copyWith(kaydedildi: sonuc['kaydedildi'] == true);
      });
    } catch (e) {
      if (mounted) setState(() => _icerik = onceki);
      _snack(kullaniciDostuHata(e));
    } finally {
      if (mounted) setState(() => _icerikAksiyonuBekliyor = false);
    }
  }

  Future<void> _icerikSil() async {
    final mevcut = _icerik;
    if (mevcut == null) return;
    final confirmed = await _silmeOnayi('Bu icerik silinsin mi?');
    if (confirmed != true) return;

    try {
      await _api.icerikSil(mevcut.id);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      _snack(kullaniciDostuHata(e));
    }
  }

  Future<void> _yorumSil(YorumModel yorum) async {
    final confirmed = await _silmeOnayi('Bu yorum silinsin mi?');
    if (confirmed != true) return;

    try {
      await _api.yorumSil(yorum.id);
      if (!mounted) return;
      setState(() {
        final silinenAdet = yorum.toplamSayi;
        _agactanYorumSil(_yorumlar, yorum.id);
        _icerik = _icerik?.copyWith(
          yorumSayisi: ((_icerik?.yorumSayisi ?? silinenAdet) - silinenAdet)
              .clamp(0, 1 << 30)
              .toInt(),
        );
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
      if (_kapaliYorumlar.contains(yorumId)) {
        _kapaliYorumlar.remove(yorumId);
      } else {
        _kapaliYorumlar.add(yorumId);
      }
    });
  }

  void _yazarProfiliAc(int? yazarId) {
    if (yazarId == null) return;
    context.push('/profil/$yazarId');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _forumMu => _icerik?.tur == 'soru';

  bool _canModerate(ProfilModel? profile) {
    return profile?.isStaff == true || profile?.isSuperuser == true;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionControllerProvider).profile;
    final canModerate = _canModerate(profile);
    final currentUserId = profile?.id;
    final canDeleteContent = canModerate || currentUserId == _icerik?.yazarId;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          _icerik?.baslik ?? 'Makale',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_icerik != null) ...[
            IconButton(
              tooltip: 'Begen',
              onPressed: _icerikAksiyonuBekliyor ? null : _icerikBegen,
              icon: Icon(
                _icerik!.begendim ? Icons.favorite : Icons.favorite_border,
                color: _icerik!.begendim ? const Color(0xFFEF4444) : null,
              ),
            ),
            IconButton(
              tooltip: 'Kaydet',
              onPressed: _icerikAksiyonuBekliyor ? null : _icerikKaydet,
              icon: Icon(
                _icerik!.kaydedildi
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _icerik!.kaydedildi ? const Color(0xFFF5A623) : null,
              ),
            ),
            if (canDeleteContent)
              PopupMenuButton<String>(
                tooltip: 'Moderasyon',
                onSelected: (value) {
                  if (value == 'delete') _icerikSil();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text('Sil'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: _govde(canModerate, currentUserId),
      bottomNavigationBar: _icerik == null || _yukleniyor
          ? null
          : CommentInputBar(
              controller: _commentController,
              focusNode: _commentFocusNode,
              replyToUsername: _yanitlananYorum?.yazarAdi,
              isSending: _yorumGonderiliyor,
              onCancelReply: _yanitiIptalEt,
              onSend: _yorumGonder,
            ),
    );
  }

  // Tüm sliver çocuklarını tablet genişliğine sığdırır (maks. 820 px).
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_hata!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _icerikYukle,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_icerik == null) return const SizedBox();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ortala(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _makaleGovdesi(),
                const Divider(height: 40),
                _yorumBasligi(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        ..._yorumSliverlari(canModerate, currentUserId),
      ],
    );
  }

  Widget _makaleGovdesi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiket(_icerik!.kategoriAdi, const Color(0xFFF5A623)),
        const SizedBox(height: 16),
        Text(
          _icerik!.baslik,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            InkWell(
              onTap: () => _yazarProfiliAc(_icerik!.yazarId),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Color(0xFF22D3EE),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _icerik!.yazarAdi,
                      style: const TextStyle(
                        color: Color(0xFF22D3EE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _meta(Icons.calendar_today_outlined, _icerik!.tarihFormatli),
            _meta(Icons.favorite_border, '${_icerik!.begeniSayisi}'),
            _meta(Icons.chat_bubble_outline, '${_icerik!.yorumSayisi}'),
          ],
        ),
        if (_icerik!.resimUrl != null && _icerik!.resimUrl!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _kapakResmi(_icerik!.resimUrl!),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - 40;

            return SizedBox(
              width: double.infinity,
              child: ArticleContentRenderer(
                html: _icerik!.yaziTemiz,
                contentWidth: contentWidth,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _yorumBasligi() {
    final baslik = _forumMu ? 'Cevaplar' : 'Yorumlar';
    // Yüklenirken bile içerik modelindeki sayı gösterilir.
    final toplam = _yorumlarYukleniyor
        ? (_icerik?.yorumSayisi ?? 0)
        : _yorumlar.fold<int>(0, (t, y) => t + y.toplamSayi);

    return Row(
      children: [
        Icon(
          _forumMu
              ? Icons.question_answer_outlined
              : Icons.chat_bubble_outline,
          size: 20,
          color: const Color(0xFF22D3EE),
        ),
        const SizedBox(width: 8),
        Text(
          '$baslik ($toplam)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  List<Widget> _yorumSliverlari(bool canModerate, int? currentUserId) {
    const altPadding = EdgeInsets.fromLTRB(20, 0, 20, 118);

    if (_yorumlarYukleniyor) {
      return [
        SliverToBoxAdapter(
          child: _ortala(
            padding: altPadding,
            child: const CommentSkeletonList(),
          ),
        ),
      ];
    }

    if (_yorumHata != null) {
      return [
        SliverToBoxAdapter(
          child: _ortala(
            padding: altPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _yorumHata!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: _yorumlariYukle,
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_yorumlar.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _ortala(
            padding: altPadding,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _forumMu
                    ? 'Henuz cevap yok. Ilk cevabi sen ver!'
                    : 'Henuz yorum yok.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: altPadding,
        sliver: SliverList.builder(
          itemCount: _yorumlar.length,
          itemBuilder: (context, index) {
            final yorum = _yorumlar[index];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CommentTile(
                    key: ValueKey('yorum-${yorum.id}'),
                    yorum: yorum,
                    depth: 0,
                    opAuthorName: _icerik?.yazarAdi,
                    canModerate: canModerate,
                    currentUserId: currentUserId,
                    collapsedIds: _kapaliYorumlar,
                    onReply: _yanitla,
                    onLike: _yorumBegen,
                    onDelete: _yorumSil,
                    onToggleCollapse: _yanitGorunumunuDegistir,
                    onAuthorTap: _yazarProfiliAc,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _meta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _etiket(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _kapakResmi(String url) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(color: const Color(0xFF1A1D27)),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFF1A1D27),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined),
          ),
        ),
      ),
    );
  }
}
