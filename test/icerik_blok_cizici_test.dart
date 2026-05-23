// Görsel oranı (aspectRatio) ve bölüm başlığı (sectionHead) blokları için
// model ayrıştırma ve widget çizim regresyon testleri. API normalizer bu
// şekilleri üretiyor; mobil tarafın da doğru widget ağacını çizdiğini burada
// kilitliyoruz.

import 'package:fitrehber_mobile/features/icerik/widgets/icerik_blok_cizici.dart';
import 'package:fitrehber_mobile/shared/models/icerik_blok_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // -------------------------------------------------------------------------
  // Model ayrıştırma
  // -------------------------------------------------------------------------

  group('IcerikBlok görsel oranı', () {
    test('sayısal değer double olarak döner', () {
      final block = IcerikBlok.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
        'aspectRatio': 1.7778,
      });
      expect(block.tur, IcerikBlokTuru.gorsel);
      expect(block.aspectRatio, closeTo(1.7778, 0.0001));
    });

    test('tam sayı değer double tipine çevrilir', () {
      final block = IcerikBlok.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
        'aspectRatio': 2,
      });
      expect(block.aspectRatio, 2.0);
    });

    test('metin değer ayrıştırılır', () {
      final block = IcerikBlok.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
        'aspectRatio': '1.5',
      });
      expect(block.aspectRatio, closeTo(1.5, 0.0001));
    });

    test('eksik değer null döner', () {
      final block = IcerikBlok.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
      });
      expect(block.aspectRatio, isNull);
    });

    test('sıfır veya negatif değer eksik kabul edilir', () {
      expect(
        IcerikBlok.fromJson({
          'type': 'figure',
          'src': 'x',
          'aspectRatio': 0,
        }).aspectRatio,
        isNull,
      );
      expect(
        IcerikBlok.fromJson({
          'type': 'figure',
          'src': 'x',
          'aspectRatio': -1.5,
        }).aspectRatio,
        isNull,
      );
    });

    test('ayrıştırılamayan metin null döner', () {
      final block = IcerikBlok.fromJson({
        'type': 'figure',
        'src': 'x',
        'aspectRatio': 'auto',
      });
      expect(block.aspectRatio, isNull);
    });
  });

  group('IcerikBlok bölüm başlığı', () {
    test('tür JSON içinden ayrıştırılır', () {
      final block = IcerikBlok.fromJson({
        'type': 'sectionHead',
        'number': '1',
        'title': 'Progresif Yuklenme',
        'level': 2,
      });
      expect(block.tur, IcerikBlokTuru.bolumBasligi);
      expect(block.number, '1');
      expect(block.title, 'Progresif Yuklenme');
      expect(block.level, 2);
    });

    test('sıra numarası eksikse boş metin olur', () {
      final block = IcerikBlok.fromJson({
        'type': 'sectionHead',
        'title': 'Beslenme',
        'level': 3,
      });
      expect(block.number, '');
      expect(block.title, 'Beslenme');
      expect(block.level, 3);
    });
  });

  // -------------------------------------------------------------------------
  // Widget çizimi
  // -------------------------------------------------------------------------

  Widget sarmala(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('IcerikBlokCizici görsel oranı', () {
    testWidgets('görseli backend oranıyla AspectRatio içine alır', (
      tester,
    ) async {
      final blocks = [
        IcerikBlok.fromJson({
          'type': 'figure',
          'src': 'https://example.com/hero.jpg',
          'alt': 'Hero',
          'caption': '',
          'aspectRatio': 1.7778,
        }),
      ];
      await tester.pumpWidget(
        sarmala(IcerikBlokCizici(blocks: blocks, contentWidth: 360)),
      );
      expect(tester.takeException(), isNull);
      final aspectFinder = find.byType(AspectRatio);
      expect(aspectFinder, findsOneWidget);
      final aspect = tester.widget<AspectRatio>(aspectFinder);
      expect(aspect.aspectRatio, closeTo(1.7778, 0.0001));
    });

    testWidgets('görsel oranı eksikse 16/9 oranına döner', (tester) async {
      final blocks = [
        IcerikBlok.fromJson({
          'type': 'figure',
          'src': 'https://example.com/note.jpg',
          'alt': '',
          'caption': '',
        }),
      ];
      await tester.pumpWidget(
        sarmala(IcerikBlokCizici(blocks: blocks, contentWidth: 360)),
      );
      expect(tester.takeException(), isNull);
      final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspect.aspectRatio, closeTo(16 / 9, 0.0001));
    });
  });

  group('IcerikBlokCizici bölüm başlığı', () {
    testWidgets('sıra numarası varsa rozet ve başlığı çizer', (tester) async {
      final blocks = [
        IcerikBlok.fromJson({
          'type': 'sectionHead',
          'number': '1',
          'title': 'Progresif Yuklenme',
          'level': 2,
        }),
      ];
      await tester.pumpWidget(
        sarmala(IcerikBlokCizici(blocks: blocks, contentWidth: 360)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Progresif Yuklenme'), findsOneWidget);
    });

    testWidgets('sıra numarası boşsa yalnızca başlığı çizer', (tester) async {
      final blocks = [
        IcerikBlok.fromJson({
          'type': 'sectionHead',
          'number': '',
          'title': 'Beslenme Stratejisi',
          'level': 3,
        }),
      ];
      await tester.pumpWidget(
        sarmala(IcerikBlokCizici(blocks: blocks, contentWidth: 360)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Beslenme Stratejisi'), findsOneWidget);
      // Numara olmadığı için sadece başlık gözükür; başlıktan
      // aynı metinli ikinci bir Text widget olmamalı.
      expect(find.text('3'), findsNothing);
    });
  });
}
