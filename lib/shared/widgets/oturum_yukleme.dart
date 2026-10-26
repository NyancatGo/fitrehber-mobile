// ---------------------------------------------------------------------------
// OTURUM YÜKLEME EKRANI
// ---------------------------------------------------------------------------
// Uygulama açılırken (oturum bilgisi okunurken) gösterilen, markaya özgü
// animasyonlu açılış/yükleme ekranı. Hem tam ekran (`OturumYuklemeEkrani`)
// hem de mevcut bir ekranın üzerine bindirilen katman (`OturumYuklemeKatmani`)
// biçiminde kullanılabilir.
// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/uygulama_temasi.dart';

const _mutedText = UygulamaTemasi.ikincilMetin;

class OturumYuklemeEkrani extends StatelessWidget {
  final String title;
  final String subtitle;

  const OturumYuklemeEkrani({
    super.key,
    this.title = 'Hesabın hazırlanıyor',
    this.subtitle = 'Verilerin senkronize ediliyor',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UygulamaTemasi.arkaPlan,
      body: OturumYuklemeGorunumu(title: title, subtitle: subtitle),
    );
  }
}

class OturumYuklemeKatmani extends StatelessWidget {
  final String title;
  final String subtitle;

  const OturumYuklemeKatmani({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: UygulamaTemasi.arkaPlan.withValues(alpha: 0.94),
          child: OturumYuklemeGorunumu(
            title: title,
            subtitle: subtitle,
            compact: true,
          ),
        ),
      ),
    );
  }
}

class OturumYuklemeGorunumu extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool compact;

  const OturumYuklemeGorunumu({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  State<OturumYuklemeGorunumu> createState() => _OturumYuklemeGorunumuDurumu();
}

class _OturumYuklemeGorunumuDurumu extends State<OturumYuklemeGorunumu>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _pulse;
  late final AnimationController _dots;
  late final AnimationController _heart;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _heart = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    _dots.dispose();
    _heart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.padding.vertical;
    final isCompact = widget.compact || availableHeight < 700;
    final ringSize = isCompact ? 132.0 : 156.0;
    final logoSize = ringSize * 0.46;

    return DecoratedBox(
      decoration: const BoxDecoration(color: UygulamaTemasi.arkaPlan),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: UygulamaTemasi.cizgi,
                              width: 1.5,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _ring,
                          builder: (context, child) => CustomPaint(
                            size: Size.square(ringSize),
                            painter: _ArcPainter(
                              progress: _ring.value,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, child) {
                            final t = Curves.easeInOut.transform(_pulse.value);
                            return Transform.scale(
                              scale: 0.98 + t * 0.04,
                              child: SizedBox.square(
                                dimension: logoSize,
                                child: CustomPaint(
                                  painter: const _BrandMarkPainter(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 24 : 32),
                  Text(
                    'FitRehber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UygulamaTemasi.baslik(fontSize: 26),
                  ),
                  SizedBox(height: isCompact ? 18 : 24),
                  SizedBox(
                    width: math.min(220, media.size.width * 0.62),
                    height: 28,
                    child: AnimatedBuilder(
                      animation: _heart,
                      builder: (context, child) => CustomPaint(
                        painter: _HeartbeatPainter(progress: _heart.value),
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 20 : 28),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: UygulamaTemasi.anaMetin,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _mutedText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: isCompact ? 28 : 40),
                  AnimatedBuilder(
                    animation: _dots,
                    builder: (context, child) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final phase = (_dots.value + i * 0.18) % 1.0;
                        final t = (math.sin(phase * math.pi * 2) + 1) / 2;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              _mutedText.withValues(alpha: 0.25),
                              UygulamaTemasi.anaRenk,
                              t,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  const _ArcPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final sweep = math.pi * 0.62;
    final start = progress * 2 * math.pi - math.pi / 2;

    final paint = Paint()
      ..color = UygulamaTemasi.anaRenk
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final heartPaint = Paint()
      ..color = UygulamaTemasi.anaRenk
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double x(double value) => value / 24 * w;
    double y(double value) => value / 24 * h;

    final heart = Path()
      ..moveTo(x(12), y(21))
      ..cubicTo(x(12), y(21), x(3.5), y(15), x(3.5), y(9))
      ..cubicTo(x(3.5), y(6.2), x(5.8), y(4), x(8.6), y(4))
      ..cubicTo(x(10.4), y(4), x(11.4), y(5), x(12), y(6))
      ..cubicTo(x(12.6), y(5), x(13.6), y(4), x(15.4), y(4))
      ..cubicTo(x(18.2), y(4), x(20.5), y(6.2), x(20.5), y(9))
      ..cubicTo(x(20.5), y(15), x(12), y(21), x(12), y(21))
      ..close();
    canvas.drawPath(heart, heartPaint);

    final pulsePaint = Paint()
      ..color = UygulamaTemasi.anaRenk
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pulse = Path()
      ..moveTo(x(5.5), y(11.5))
      ..lineTo(x(8.5), y(11.5))
      ..lineTo(x(10), y(8.5))
      ..lineTo(x(12), y(14.5))
      ..lineTo(x(14), y(10))
      ..lineTo(x(15.5), y(11.5))
      ..lineTo(x(18.5), y(11.5));
    canvas.drawPath(pulse, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}

class _HeartbeatPainter extends CustomPainter {
  final double progress;

  const _HeartbeatPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;

    final basePaint = Paint()
      ..color = UygulamaTemasi.cizgi
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, mid), Offset(w, mid), basePaint);

    final paint = Paint()
      ..color = UygulamaTemasi.anaRenk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = progress * w;
    final spikeW = w * 0.22;
    final path = Path()
      ..moveTo(0, mid)
      ..lineTo(cx - spikeW, mid)
      ..lineTo(cx - spikeW * 0.45, mid)
      ..lineTo(cx - spikeW * 0.25, h * 0.12)
      ..lineTo(cx, h * 0.88)
      ..lineTo(cx + spikeW * 0.25, mid - h * 0.12)
      ..lineTo(cx + spikeW * 0.5, mid)
      ..lineTo(w, mid);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
