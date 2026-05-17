import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/api_service.dart';
import '../../shared/models/icerik_model.dart';
import '../../shared/models/yorum_model.dart';
import 'widgets/article_content_renderer.dart';

class ArticleScreen extends StatefulWidget {
  final int id;
  const ArticleScreen({super.key, required this.id});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final ApiService _api = ApiService();
  IcerikModel? _icerik;
  bool _yukleniyor = true;
  String? _hata;

  List<YorumModel> _yorumlar = [];
  bool _yorumlarYukleniyor = false;
  String? _yorumHata;

  @override
  void initState() {
    super.initState();
    _icerikYukle();
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

  Future<void> _yorumBegen(YorumModel yorum) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _yazarProfiliAc(int? yazarId) {
    if (yazarId == null) return;
    context.push('/profil/$yazarId');
  }

  bool get _forumMu => _icerik?.tur == 'soru';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _icerik?.baslik ?? 'Makale',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _icerik!.kategoriAdi,
                  style: const TextStyle(
                    color: Color(0xFFF5A623),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _icerik!.baslik,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
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
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _icerik!.tarihFormatli,
                    style: const TextStyle(color: Colors.grey),
                  ),
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
              _yorumBolumu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yorumBolumu() {
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
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
                  ? 'Henüz cevap yok. İlk cevabı sen ver!'
                  : 'Henüz yorum yok.',
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._yorumlar.map((y) => _yorumKarti(y, 0)),
      ],
    );
  }

  Widget _yorumKarti(YorumModel yorum, int derinlik) {
    final yazarMakaleSahibi =
        yorum.yazarAdi == _icerik?.yazarAdi && _icerik?.yazarAdi != 'Anonim';
    final indent = (derinlik.clamp(0, 3)) * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(10),
              border: derinlik > 0
                  ? const Border(
                      left: BorderSide(color: Color(0xFF2A2D37), width: 2),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 22,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: InkWell(
                        onTap: () => _yazarProfiliAc(yorum.yazarId),
                        child: Text(
                          yorum.yazarAdi,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (yazarMakaleSahibi) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5A623)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YAZAR',
                          style: TextStyle(
                            color: Color(0xFFF5A623),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      yorum.tarihGoreli,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  yorum.mesaj,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => _yorumBegen(yorum),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            yorum.begendim
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: yorum.begendim
                                ? const Color(0xFFEF4444)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${yorum.begeniSayisi}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: yorum.begendim
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...yorum.yanitlar.map((y) => _yorumKarti(y, derinlik + 1)),
        ],
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
