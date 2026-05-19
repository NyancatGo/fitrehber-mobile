import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/beslenme_model.dart';
import 'providers/nutrition_provider.dart';

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nutritionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beslenme Takibi'),
        centerTitle: true,
        elevation: 0,
      ),
      body: state.isLoading && state.veri == null
          ? const Center(child: CircularProgressIndicator())
          : _GovdeParcasi(state: state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMealBottomSheet(context, ref),
        label: const Text('Öğün Ekle'),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _GovdeParcasi extends ConsumerWidget {
  final NutritionState state;
  const _GovdeParcasi({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veri = state.veri ?? GunlukBeslenmeModel(tarih: state.seciliTarih);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _GunSecici(seciliTarih: state.seciliTarih),
        const SizedBox(height: 28),
        _ProgressHalkalari(veri: veri),
        const SizedBox(height: 28),
        _SuEklemeButonlari(
          onEkle: (ml) => ref.read(nutritionProvider.notifier).suEkle(ml),
          isLoading: state.isLoading,
        ),
        const SizedBox(height: 28),
        _MakroBarlar(veri: veri),
        if (state.hata != null) ...[
          const SizedBox(height: 16),
          _HataKutusu(metin: state.hata!),
        ],
        const SizedBox(height: 28),
        _OgunListesi(veri: veri, isLoading: state.isLoading),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------- Gün Seçici ----------

class _GunSecici extends ConsumerWidget {
  final String seciliTarih;
  const _GunSecici({required this.seciliTarih});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugun = DateTime.now();
    final gunler = List.generate(
      7,
      (i) => bugun.subtract(Duration(days: 3 - i)),
    );

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gunler.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final gun = gunler[i];
          final tarihStr = _tarihStr(gun);
          final secili = tarihStr == seciliTarih;
          const gunAdlari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

          return GestureDetector(
            onTap: () => ref.read(nutritionProvider.notifier).load(tarihStr),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              decoration: BoxDecoration(
                gradient: secili
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
                      )
                    : null,
                color: secili ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: secili
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    gunAdlari[gun.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: secili
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${gun.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: secili ? Colors.white : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _tarihStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ---------- Progress Halkaları ----------

class _ProgressHalkalari extends StatelessWidget {
  final GunlukBeslenmeModel veri;
  const _ProgressHalkalari({required this.veri});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dış halka — Su
              _Halka(
                yuzde: veri.suYuzdesi,
                renk1: const Color(0xFF06B6D4),
                renk2: const Color(0xFF3B82F6),
                boyut: 220,
                kalinlik: 16,
              ),
              // İç halka — Kalori
              _Halka(
                yuzde: veri.kaloriYuzdesi,
                renk1: const Color(0xFFF97316),
                renk2: const Color(0xFFEF4444),
                boyut: 170,
                kalinlik: 14,
              ),
              // Merkez metin
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${veri.suMl} ml',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF22D3EE),
                    ),
                  ),
                  Text(
                    '%${(veri.suYuzdesi * 100).toStringAsFixed(0)} su',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${veri.kaloriKcal} kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF97316),
                    ),
                  ),
                  Text(
                    '%${(veri.kaloriYuzdesi * 100).toStringAsFixed(0)} kalori',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Etiket(renk: const Color(0xFF06B6D4), metin: 'Su'),
            const SizedBox(width: 20),
            _Etiket(renk: const Color(0xFFF97316), metin: 'Kalori'),
          ],
        ),
      ],
    );
  }
}

class _Halka extends StatelessWidget {
  final double yuzde;
  final Color renk1;
  final Color renk2;
  final double boyut;
  final double kalinlik;

  const _Halka({
    required this.yuzde,
    required this.renk1,
    required this.renk2,
    required this.boyut,
    required this.kalinlik,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boyut,
      height: boyut,
      child: CustomPaint(
        painter: _HalkaPainter(
          yuzde: yuzde,
          renk1: renk1,
          renk2: renk2,
          kalinlik: kalinlik,
        ),
      ),
    );
  }
}

class _HalkaPainter extends CustomPainter {
  final double yuzde;
  final Color renk1;
  final Color renk2;
  final double kalinlik;

  const _HalkaPainter({
    required this.yuzde,
    required this.renk1,
    required this.renk2,
    required this.kalinlik,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final merkez = Offset(size.width / 2, size.height / 2);
    final yaricap = (size.width - kalinlik) / 2;
    final rect = Rect.fromCircle(center: merkez, radius: yaricap);

    // Arka plan halkası
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalinlik
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(merkez, yaricap, bgPaint);

    // İlerleme halkası
    if (yuzde > 0) {
      final shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [renk1, renk2],
        tileMode: TileMode.clamp,
      ).createShader(rect);

      final fgPaint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = kalinlik
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * yuzde, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_HalkaPainter old) =>
      old.yuzde != yuzde || old.renk1 != renk1;
}

class _Etiket extends StatelessWidget {
  final Color renk;
  final String metin;
  const _Etiket({required this.renk, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          metin,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ---------- Su Ekleme Butonları ----------

class _SuEklemeButonlari extends StatelessWidget {
  final void Function(int ml) onEkle;
  final bool isLoading;
  const _SuEklemeButonlari({required this.onEkle, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Su Ekle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SuButon(ml: 250, onEkle: onEkle, isLoading: isLoading),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SuButon(ml: 500, onEkle: onEkle, isLoading: isLoading),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuButon extends StatefulWidget {
  final int ml;
  final void Function(int ml) onEkle;
  final bool isLoading;
  const _SuButon({
    required this.ml,
    required this.onEkle,
    required this.isLoading,
  });

  @override
  State<_SuButon> createState() => _SuButonState();
}

class _SuButonState extends State<_SuButon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _press() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onEkle(widget.ml);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.isLoading ? null : _press,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '+${widget.ml} ml',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Makro Barlar ----------

class _MakroBarlar extends StatelessWidget {
  final GunlukBeslenmeModel veri;
  const _MakroBarlar({required this.veri});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Makrolar',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        _MakroBar(
          etiket: 'Protein',
          deger: veri.proteinG,
          hedef: GunlukBeslenmeModel.gunlukProteinHedefG,
          yuzde: veri.proteinYuzdesi,
          renk: const Color(0xFF3B82F6),
          birim: 'g',
        ),
        const SizedBox(height: 14),
        _MakroBar(
          etiket: 'Karbonhidrat',
          deger: veri.karbonhidratG,
          hedef: GunlukBeslenmeModel.gunlukKarbonhidratHedefG,
          yuzde: veri.karbonhidratYuzdesi,
          renk: const Color(0xFFF5A623),
          birim: 'g',
        ),
        const SizedBox(height: 14),
        _MakroBar(
          etiket: 'Yağ',
          deger: veri.yagG,
          hedef: GunlukBeslenmeModel.gunlukYagHedefG,
          yuzde: veri.yagYuzdesi,
          renk: const Color(0xFFEF4444),
          birim: 'g',
        ),
      ],
    );
  }
}

class _MakroBar extends StatelessWidget {
  final String etiket;
  final double deger;
  final double hedef;
  final double yuzde;
  final Color renk;
  final String birim;

  const _MakroBar({
    required this.etiket,
    required this.deger,
    required this.hedef,
    required this.yuzde,
    required this.renk,
    required this.birim,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              etiket,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              '${deger.toStringAsFixed(0)} / ${hedef.toStringAsFixed(0)} $birim',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: Colors.white.withValues(alpha: 0.07)),
              FractionallySizedBox(
                widthFactor: yuzde,
                child: Container(height: 8, color: renk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HataKutusu extends StatelessWidget {
  final String metin;
  const _HataKutusu({required this.metin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        metin,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OgunListesi extends StatelessWidget {
  final GunlukBeslenmeModel veri;
  final bool isLoading;

  const _OgunListesi({required this.veri, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    const ogunSirasi = ['sabah', 'ogle', 'aksam', 'atistirmalik'];
    final kayitSayisi = veri.ogunler.values.fold<int>(
      0,
      (toplam, kayitlar) => toplam + kayitlar.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Öğünler',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$kayitSayisi kayıt',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...ogunSirasi.map(
          (ogunTipi) => _OgunBolumu(
            ogunTipi: ogunTipi,
            kayitlar: veri.ogunler[ogunTipi] ?? const [],
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}

class _OgunBolumu extends StatelessWidget {
  final String ogunTipi;
  final List<OgunKaydiModel> kayitlar;
  final bool isLoading;

  const _OgunBolumu({
    required this.ogunTipi,
    required this.kayitlar,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final toplamKalori = kayitlar.fold<int>(
      0,
      (toplam, kayit) => toplam + kayit.kalori,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _ogunIkonu(ogunTipi),
                  color: const Color(0xFFF97316),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _ogunBasligi(ogunTipi),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$toplamKalori kcal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (kayitlar.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Henüz kayıt yok',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.36),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...kayitlar.map(
              (kayit) => _OgunKarti(kayit: kayit, isLoading: isLoading),
            ),
          ],
        ],
      ),
    );
  }
}

class _OgunKarti extends ConsumerWidget {
  final OgunKaydiModel kayit;
  final bool isLoading;

  const _OgunKarti({required this.kayit, required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kayit.besinIsim,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatMiktar(kayit.miktar)} ${kayit.miktarBirimi} • '
                  'P ${kayit.protein.toStringAsFixed(1)}g • '
                  'K ${kayit.karbonhidrat.toStringAsFixed(1)}g • '
                  'Y ${kayit.yag.toStringAsFixed(1)}g',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${kayit.kalori}',
            style: const TextStyle(
              color: Color(0xFFF97316),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'kcal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.36),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            visualDensity: VisualDensity.compact,
            onPressed: isLoading
                ? null
                : () => ref.read(nutritionProvider.notifier).ogunSil(kayit.id),
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

void _showAddMealBottomSheet(BuildContext context, WidgetRef ref) {
  final formKey = GlobalKey<FormState>();
  final searchCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: '100');
  final calCtrl = TextEditingController();
  final proteinCtrl = TextEditingController();
  final carbCtrl = TextEditingController();
  final fatCtrl = TextEditingController();

  const ogunSecenekleri = ['sabah', 'ogle', 'aksam', 'atistirmalik'];
  String seciliOgun = 'sabah';
  bool manuelMod = false;
  bool araniyor = false;
  String? aramaHatasi;
  BesinModel? seciliBesin;
  List<BesinModel> sonuclar = [];

  Future<void> ara(StateSetter setModalState, BuildContext sheetContext) async {
    final query = searchCtrl.text.trim();
    if (query.length < 2) {
      setModalState(() {
        sonuclar = [];
        aramaHatasi = null;
      });
      return;
    }

    setModalState(() {
      araniyor = true;
      aramaHatasi = null;
    });

    try {
      final gelen = await ref.read(nutritionProvider.notifier).besinAra(query);
      if (!sheetContext.mounted) return;
      setModalState(() {
        sonuclar = gelen;
        araniyor = false;
      });
    } catch (_) {
      if (!sheetContext.mounted) return;
      setModalState(() {
        sonuclar = [];
        araniyor = false;
        aramaHatasi = 'Besin araması yapılamadı.';
      });
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final miktar = _parseInputDouble(amountCtrl.text);
            final besin = seciliBesin;
            final hazirBesin = !manuelMod && besin != null;
            final previewKalori = hazirBesin
                ? ((besin.kalori100g * miktar) / 100).toInt()
                : (_parseInputInt(calCtrl.text) ?? 0);
            final previewProtein = hazirBesin
                ? (besin.protein100g * miktar) / 100
                : _parseInputDouble(proteinCtrl.text);
            final previewKarb = hazirBesin
                ? (besin.karbonhidrat100g * miktar) / 100
                : _parseInputDouble(carbCtrl.text);
            final previewYag = hazirBesin
                ? (besin.yag100g * miktar) / 100
                : _parseInputDouble(fatCtrl.text);

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1D27),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Öğün Ekle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ogunSecenekleri.map((ogun) {
                          final secili = seciliOgun == ogun;
                          return ChoiceChip(
                            label: Text(_ogunBasligi(ogun)),
                            selected: secili,
                            onSelected: (_) =>
                                setModalState(() => seciliOgun = ogun),
                            selectedColor: const Color(0xFFF97316),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                            labelStyle: TextStyle(
                              color: secili ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w800,
                            ),
                            side: BorderSide(
                              color: secili
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ModButonu(
                              metin: 'Besin ara',
                              secili: !manuelMod,
                              onTap: () => setModalState(() {
                                manuelMod = false;
                                nameCtrl.clear();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModButonu(
                              metin: 'Manuel',
                              secili: manuelMod,
                              onTap: () => setModalState(() {
                                manuelMod = true;
                                seciliBesin = null;
                                sonuclar = [];
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (!manuelMod) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: searchCtrl,
                                decoration: _inputDec(
                                  'Besin ara (örn: yulaf)',
                                  Icons.search,
                                ),
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.search,
                                onFieldSubmitted: (_) =>
                                    ara(setModalState, sheetContext),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 52,
                              width: 52,
                              child: ElevatedButton(
                                onPressed: araniyor
                                    ? null
                                    : () => ara(setModalState, sheetContext),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFFF97316),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: araniyor
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (aramaHatasi != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            aramaHatasi!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (sonuclar.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 210),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: sonuclar.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              itemBuilder: (context, index) {
                                final item = sonuclar[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    item.isim,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.kalori100g} kcal • '
                                    'P ${item.protein100g.toStringAsFixed(1)}g • '
                                    'K ${item.karbonhidrat100g.toStringAsFixed(1)}g • '
                                    'Y ${item.yag100g.toStringAsFixed(1)}g / 100g',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.42,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: item.isVerified
                                      ? const Icon(
                                          Icons.verified,
                                          color: Color(0xFF22C55E),
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () => setModalState(() {
                                    seciliBesin = item;
                                    nameCtrl.text = item.isim;
                                  }),
                                );
                              },
                            ),
                          ),
                        ],
                        if (seciliBesin != null) ...[
                          const SizedBox(height: 12),
                          _SeciliBesinKutusu(besin: seciliBesin!),
                        ],
                      ] else ...[
                        TextFormField(
                          controller: nameCtrl,
                          decoration: _inputDec(
                            'Besin / Öğün Adı',
                            Icons.fastfood_outlined,
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (!manuelMod) return null;
                            if (val == null || val.trim().isEmpty) {
                              return 'Lütfen besin adını girin';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDec(
                          'Miktar (g)',
                          Icons.scale_outlined,
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (_) => setModalState(() {}),
                        validator: (val) {
                          final miktar = _parseInputDouble(val ?? '');
                          if (miktar <= 0) {
                            return 'Miktar sıfırdan büyük olmalı';
                          }
                          return null;
                        },
                      ),
                      if (manuelMod) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: calCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _inputDec(
                            'Kalori (kcal)',
                            Icons.local_fire_department_outlined,
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (_) => setModalState(() {}),
                          validator: (val) {
                            if (!manuelMod) return null;
                            if (_parseInputInt(val ?? '') == null) {
                              return 'Geçerli kalori girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: proteinCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _inputDec('Protein (g)', null),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: carbCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _inputDec('Karb (g)', null),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: fatCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _inputDec('Yağ (g)', null),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      _MakroOnizleme(
                        kalori: previewKalori,
                        protein: previewProtein,
                        karbonhidrat: previewKarb,
                        yag: previewYag,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (!manuelMod && seciliBesin == null) {
                            setModalState(() {
                              aramaHatasi = 'Lütfen listeden bir besin seçin.';
                            });
                            return;
                          }

                          final notifier = ref.read(nutritionProvider.notifier);
                          final besin = seciliBesin;
                          Navigator.pop(sheetContext);
                          await notifier.ogunEkle(
                            ogunTipi: seciliOgun,
                            besinId: manuelMod ? null : besin?.id,
                            besinIsim: manuelMod ? nameCtrl.text.trim() : null,
                            miktar: _parseInputDouble(amountCtrl.text),
                            kalori: manuelMod
                                ? (_parseInputInt(calCtrl.text) ?? 0)
                                : 0,
                            protein: manuelMod
                                ? _parseInputDouble(proteinCtrl.text)
                                : 0,
                            karbonhidrat: manuelMod
                                ? _parseInputDouble(carbCtrl.text)
                                : 0,
                            yag: manuelMod
                                ? _parseInputDouble(fatCtrl.text)
                                : 0,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Öğün başarıyla eklendi.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    searchCtrl.dispose();
    nameCtrl.dispose();
    amountCtrl.dispose();
    calCtrl.dispose();
    proteinCtrl.dispose();
    carbCtrl.dispose();
    fatCtrl.dispose();
  });
}

class _ModButonu extends StatelessWidget {
  final String metin;
  final bool secili;
  final VoidCallback onTap;

  const _ModButonu({
    required this.metin,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secili
              ? const Color(0xFFF97316)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: secili
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          metin,
          style: TextStyle(
            color: secili ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SeciliBesinKutusu extends StatelessWidget {
  final BesinModel besin;

  const _SeciliBesinKutusu({required this.besin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              besin.isim,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MakroOnizleme extends StatelessWidget {
  final int kalori;
  final double protein;
  final double karbonhidrat;
  final double yag;

  const _MakroOnizleme({
    required this.kalori,
    required this.protein,
    required this.karbonhidrat,
    required this.yag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _OnizlemeDegeri(label: 'kcal', value: '$kalori'),
          _OnizlemeDegeri(label: 'Protein', value: protein.toStringAsFixed(1)),
          _OnizlemeDegeri(
            label: 'Karb',
            value: karbonhidrat.toStringAsFixed(1),
          ),
          _OnizlemeDegeri(label: 'Yağ', value: yag.toStringAsFixed(1)),
        ],
      ),
    );
  }
}

class _OnizlemeDegeri extends StatelessWidget {
  final String label;
  final String value;

  const _OnizlemeDegeri({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _ogunBasligi(String ogunTipi) {
  switch (ogunTipi) {
    case 'sabah':
      return 'Sabah';
    case 'ogle':
      return 'Öğle';
    case 'aksam':
      return 'Akşam';
    case 'atistirmalik':
      return 'Atıştırmalık';
    default:
      return ogunTipi;
  }
}

IconData _ogunIkonu(String ogunTipi) {
  switch (ogunTipi) {
    case 'sabah':
      return Icons.wb_sunny_outlined;
    case 'ogle':
      return Icons.lunch_dining_outlined;
    case 'aksam':
      return Icons.dinner_dining_outlined;
    case 'atistirmalik':
      return Icons.local_cafe_outlined;
    default:
      return Icons.restaurant_outlined;
  }
}

String _formatMiktar(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

int? _parseInputInt(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized) ?? double.tryParse(normalized)?.toInt();
}

double _parseInputDouble(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  return double.tryParse(normalized) ?? 0;
}

InputDecoration _inputDec(String label, IconData? icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    prefixIcon: icon != null
        ? Icon(icon, color: const Color(0xFFF97316), size: 20)
        : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.03),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}
