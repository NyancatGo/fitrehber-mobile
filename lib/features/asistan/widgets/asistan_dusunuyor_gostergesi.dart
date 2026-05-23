// ---------------------------------------------------------------------------
// "ASİSTAN DÜŞÜNÜYOR" GÖSTERGESİ
// ---------------------------------------------------------------------------
// Asistandan yanıt beklenirken gösterilen animasyonlu gösterge (marka
// nabzı + hareketli noktalar). Kullanıcıya isteğin işlendiğini bildirir.
// ---------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/uygulama_temasi.dart';

/// Asistan yanıt üretirken gösterilen animasyonlu bekleme göstergesi.
class AsistanDusunuyorGostergesi extends StatefulWidget {
  const AsistanDusunuyorGostergesi({super.key});

  @override
  State<AsistanDusunuyorGostergesi> createState() =>
      _AsistanDusunuyorGostergesiDurumu();
}

class _AsistanDusunuyorGostergesiDurumu
    extends State<AsistanDusunuyorGostergesi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: UygulamaTemasi.yuzey,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BrandPulse(controller: _controller),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FitRehber hazırlanıyor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: UygulamaTemasi.anaMetin,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _ThinkingDots(controller: _controller),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPulse extends StatelessWidget {
  final Animation<double> controller;

  const _BrandPulse({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final wave = math.sin(controller.value * math.pi * 2);
        final scale = 1 + ((wave + 1) / 2) * 0.16;
        final ringOpacity = 0.2 + ((wave + 1) / 2) * 0.28;

        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: UygulamaTemasi.anaRenk.withValues(
                        alpha: ringOpacity,
                      ),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: UygulamaTemasi.anaRenk.withValues(alpha: 0.16),
                  border: Border.all(
                    color: UygulamaTemasi.anaRenk.withValues(alpha: 0.42),
                  ),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 17,
                  color: UygulamaTemasi.anaRenk,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  final Animation<double> controller;

  const _ThinkingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (controller.value + (index * 0.18)) % 1;
            final lift = math.sin(phase * math.pi);
            final width = 7 + lift * 9;
            final opacity = 0.34 + lift * 0.56;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
              width: width,
              height: 7,
              decoration: BoxDecoration(
                color: UygulamaTemasi.anaRenk.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}
