import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// FitRehber AI Asistan ikonu — bottom navigation bar için özel widget.
///
/// İki state:
///   - `isActive=false` (pasif): mono SVG, NavigationBar'ın default rengini alır
///     (currentColor), diğer Material ikonlarla aynı sessizlikte durur.
///   - `isActive=true` (aktif): brand gradient SVG (sarı→turuncu) + amber halo
///     + idle twinkle (küçük sparkle opacity 0.45 ↔ 1.0, 1.6s ease-in-out).
///
/// Tasarım kaynağı: Claude Design v3.0 "Sparkle Twin" — logoyla kardeş gibi durur.
class AsistanIkonu extends StatefulWidget {
  final bool isActive;
  final double size;

  const AsistanIkonu({super.key, required this.isActive, this.size = 24});

  @override
  State<AsistanIkonu> createState() => _AsistanIkonuDurumu();
}

class _AsistanIkonuDurumu extends State<AsistanIkonu>
    with TickerProviderStateMixin {
  // Idle twinkle: küçük sparkle nefesi (1.6s loop, ease-in-out)
  late final AnimationController _twinkleCtrl;
  // Tap pop: state'ten state'e geçişte 0.9 → 1.10 → 1.0 (180ms easeOutBack)
  late final AnimationController _popCtrl;
  late final Animation<double> _popScale;

  bool _wasActive = false;

  @override
  void initState() {
    super.initState();
    _twinkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.10,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.10,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
    ]).animate(_popCtrl);

    _wasActive = widget.isActive;
  }

  @override
  void didUpdateWidget(covariant AsistanIkonu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sekme aktif olduğu an tap pop'u oynat (selectedIcon her seferinde
    // yeniden oluşturulmuyor — NavigationBar widget'ı reuse ediyor).
    if (widget.isActive && !_wasActive) {
      _popCtrl.forward(from: 0);
    }
    _wasActive = widget.isActive;
  }

  @override
  void dispose() {
    _twinkleCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    if (!widget.isActive) {
      // Pasif: mono SVG (currentColor), NavigationBar'ın unselected rengini alır.
      return SvgPicture.asset(
        'assets/icons/ai_assistant_mono.svg',
        width: size,
        height: size,
        // currentColor desteği için colorFilter:
        colorFilter: ColorFilter.mode(
          IconTheme.of(context).color ?? Colors.white70,
          BlendMode.srcIn,
        ),
      );
    }

    // Aktif: gradient SVG + halo + idle twinkle + tap pop
    return AnimatedBuilder(
      animation: Listenable.merge([_twinkleCtrl, _popCtrl]),
      builder: (context, _) {
        // Halo opacity'si twinkle ile birlikte hafifçe oynar (0.45..0.75)
        final haloOpacity = 0.45 + (_twinkleCtrl.value * 0.30);
        return Transform.scale(
          scale: _popScale.value,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Halo — SVG dışında BoxShadow ile (tasarımcının önerisi)
              Container(
                width: size * 0.85,
                height: size * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFBBF24,
                      ).withValues(alpha: haloOpacity),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
              // Gradient SVG
              SvgPicture.asset(
                'assets/icons/ai_assistant.svg',
                width: size,
                height: size,
              ),
            ],
          ),
        );
      },
    );
  }
}
