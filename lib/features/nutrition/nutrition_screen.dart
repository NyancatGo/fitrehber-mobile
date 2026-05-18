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
        label: const Text('Besin / Kalori Ekle'),
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
    final gunler = List.generate(7, (i) => bugun.subtract(Duration(days: 3 - i)));

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
            onTap: () =>
                ref.read(nutritionProvider.notifier).load(tarihStr),
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
                color: secili
                    ? null
                    : Colors.white.withValues(alpha: 0.05),
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

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * yuzde,
        false,
        fgPaint,
      );
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
            Expanded(child: _SuButon(ml: 250, onEkle: onEkle, isLoading: isLoading)),
            const SizedBox(width: 12),
            Expanded(child: _SuButon(ml: 500, onEkle: onEkle, isLoading: isLoading)),
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
  const _SuButon({required this.ml, required this.onEkle, required this.isLoading});

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
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
              Container(
                height: 8,
                color: Colors.white.withValues(alpha: 0.07),
              ),
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

void _showAddMealBottomSheet(BuildContext context, WidgetRef ref) {
  final formKey = GlobalKey<FormState>();
  final mealCtrl = TextEditingController();
  final calCtrl = TextEditingController();
  final proteinCtrl = TextEditingController();
  final carbCtrl = TextEditingController();
  final fatCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
                    'Öğün veya Kalori Ekle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: mealCtrl,
                    decoration: _inputDec('Öğün / Besin Adı (örn: Yulaf Ezmesi)', Icons.fastfood_outlined),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: calCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDec('Kalori (kcal) *', Icons.local_fire_department_outlined),
                    style: const TextStyle(color: Colors.white),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Lütfen kalori miktarını girin';
                      if (int.tryParse(val) == null) return 'Geçersiz bir sayı girin';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: proteinCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDec('Protein (g)', null),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: carbCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDec('Karb (g)', null),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: fatCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDec('Yağ (g)', null),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final cal = int.parse(calCtrl.text);
                        final p = double.tryParse(proteinCtrl.text) ?? 0.0;
                        final c = double.tryParse(carbCtrl.text) ?? 0.0;
                        final f = double.tryParse(fatCtrl.text) ?? 0.0;

                        ref.read(nutritionProvider.notifier).kaloriEkle(
                          kaloriKcal: cal,
                          proteinG: p,
                          karbonhidratG: c,
                          yagG: f,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Öğün başarıyla eklendi! 🔥'),
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
        ),
      );
    },
  );
}

InputDecoration _inputDec(String label, IconData? icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFF97316), size: 20) : null,
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
