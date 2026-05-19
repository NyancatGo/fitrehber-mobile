import 'package:flutter/material.dart';

import '../../../shared/utils/nutrition_calculator.dart';

/// Su takip bölümü — sayfanın en altında yer alır.
/// Hızlı +250ml / +500ml ekleme butonları ve günlük ilerleme içerir.
class WaterTrackerSection extends StatelessWidget {
  final int suMl;
  final NutritionGoals hedefler;
  final void Function(int ml) onEkle;
  final bool isLoading;

  const WaterTrackerSection({
    super.key,
    required this.suMl,
    required this.hedefler,
    required this.onEkle,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final yuzde =
        hedefler.suHedefMl > 0
            ? (suMl / hedefler.suHedefMl).clamp(0.0, 1.0)
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  color: Color(0xFF06B6D4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Su Tüketimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$suMl / ${hedefler.suHedefMl} ml',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // İlerleme çubuğu
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
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Hızlı ekleme butonları
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
      ),
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
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '+${widget.ml} ml',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
