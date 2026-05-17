import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/profil_model.dart';
import '../../shared/models/yorum_model.dart';
import '../../shared/session_controller.dart';
import 'widgets/article_content_renderer.dart';
import 'widgets/comment_input_bar.dart';

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
      setState(() => _hata = e.toString());
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
      setState(() => _yorumHata = e.toString());
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
      _snack(e.toString());
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
      _snack(e.toString());
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
      _snack(e.toString());
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
      _snack(e.toString());
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
      _snack(e.toString());
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
      _snack(e.toString());
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 118),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _etiket(_icerik!.kategoriAdi, const Color(0xFFF5A623)),
              const SizedBox(height: 16),
              Text(
                _icerik!.baslik,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
              if (_icerik!.resimUrl != null &&
                  _icerik!.resimUrl!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _kapakResmi(_icerik!.resimUrl!),
              ],
              const Divider(height: 32),
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
              const Divider(height: 40),
              _yorumBolumu(canModerate, currentUserId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yorumBolumu(bool canModerate, int? currentUserId) {
    final baslik = _forumMu ? 'Cevaplar' : 'Yorumlar';
    final toplam = _yorumlar.fold<int>(0, (t, y) => t + y.toplamSayi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              _yorumlarYukleniyor ? baslik : '$baslik ($toplam)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_yorumlarYukleniyor)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_yorumHata != null)
          Row(
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
          )
        else if (_yorumlar.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _forumMu
                  ? 'Henuz cevap yok. Ilk cevabi sen ver!'
                  : 'Henuz yorum yok.',
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._yorumlar.map(
            (y) => _yorumKarti(y, 0, canModerate, currentUserId),
          ),
      ],
    );
  }

  Widget _yorumKarti(
    YorumModel yorum,
    int derinlik,
    bool canModerate,
    int? currentUserId,
  ) {
    final yazarMakaleSahibi =
        yorum.yazarAdi == _icerik?.yazarAdi && _icerik?.yazarAdi != 'Anonim';
    final canDeleteComment = canModerate || currentUserId == yorum.yazarId;
    final indent = (derinlik.clamp(0, 5)) * 12.0;
    final yanitlarKapali = _kapaliYorumlar.contains(yorum.id);
    final altYanitSayisi = yorum.yanitlar.fold<int>(
      0,
      (toplam, y) => toplam + y.toplamSayi,
    );
    final initial = yorum.yazarAdi.trim().isEmpty
        ? '?'
        : yorum.yazarAdi.trim().substring(0, 1).toUpperCase();

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: 34,
                        bottom: 0,
                        child: Container(
                          width: 1.5,
                          color: const Color(
                            0xFF2A2D37,
                          ).withValues(alpha: 0.72),
                        ),
                      ),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(
                          0xFF22D3EE,
                        ).withValues(alpha: 0.14),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Color(0xFFBFF6FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: InkWell(
                                onTap: () => _yazarProfiliAc(yorum.yazarId),
                                child: Text(
                                  yorum.yazarAdi,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (yazarMakaleSahibi) ...[
                              const SizedBox(width: 6),
                              _etiket(
                                'YAZAR',
                                const Color(0xFFF5A623),
                                mini: true,
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              yorum.tarihGoreli,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.44),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (canDeleteComment)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                tooltip: 'Moderasyon',
                                onSelected: (value) {
                                  if (value == 'delete') _yorumSil(yorum);
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
                        const SizedBox(height: 7),
                        Text(
                          yorum.mesaj,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            _yorumAksiyon(
                              icon: yorum.begendim
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              label: '${yorum.begeniSayisi}',
                              color: yorum.begendim
                                  ? const Color(0xFFEF4444)
                                  : Colors.white.withValues(alpha: 0.54),
                              onTap: () => _yorumBegen(yorum),
                            ),
                            _yorumAksiyon(
                              icon: Icons.mode_comment_outlined,
                              label: 'Yanitla',
                              color: const Color(0xFF22D3EE),
                              onTap: () => _yanitla(yorum),
                            ),
                            if (yorum.yanitlar.isNotEmpty)
                              _yorumAksiyon(
                                icon: yanitlarKapali
                                    ? Icons.unfold_more
                                    : Icons.unfold_less,
                                label: yanitlarKapali
                                    ? '$altYanitSayisi yanit'
                                    : 'Gizle',
                                color: Colors.white.withValues(alpha: 0.54),
                                onTap: () =>
                                    _yanitGorunumunuDegistir(yorum.id),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!yanitlarKapali)
            ...yorum.yanitlar.map(
              (y) => _yorumKarti(y, derinlik + 1, canModerate, currentUserId),
            ),
        ],
      ),
    );
  }

  Widget _yorumAksiyon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _etiket(String text, Color color, {bool mini = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 6 : 10,
        vertical: mini ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: mini ? 9 : 13,
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
