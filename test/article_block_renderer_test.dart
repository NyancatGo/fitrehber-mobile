// figure aspectRatio + sectionHead bloklari icin model parse ve widget render
// regresyon testleri. API normalizer bu sekilleri uretiyor; mobil tarafin da
// dogru widget agacini cizdigini burada kilitliyoruz.

import 'package:fitrehber_mobile/features/article/widgets/article_block_renderer.dart';
import 'package:fitrehber_mobile/shared/models/article_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // -------------------------------------------------------------------------
  // Model parsing
  // -------------------------------------------------------------------------

  group('ArticleBlock.aspectRatio', () {
    test('numeric value is returned as double', () {
      final block = ArticleBlock.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
        'aspectRatio': 1.7778,
      });
      expect(block.type, ArticleBlockType.figure);
      expect(block.aspectRatio, closeTo(1.7778, 0.0001));
    });

    test('integer value is converted to double', () {
      final block = ArticleBlock.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
        'aspectRatio': 2,
      });
      expect(block.aspectRatio, 2.0);
    });

    test('string value parses', () {
      final block = ArticleBlock.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
        'aspectRatio': '1.5',
      });
      expect(block.aspectRatio, closeTo(1.5, 0.0001));
    });

    test('missing value returns null', () {
      final block = ArticleBlock.fromJson({
        'type': 'figure',
        'src': 'https://example.com/x.jpg',
      });
      expect(block.aspectRatio, isNull);
    });

    test('zero or negative is treated as missing', () {
      expect(
        ArticleBlock.fromJson({
          'type': 'figure',
          'src': 'x',
          'aspectRatio': 0,
        }).aspectRatio,
        isNull,
      );
      expect(
        ArticleBlock.fromJson({
          'type': 'figure',
          'src': 'x',
          'aspectRatio': -1.5,
        }).aspectRatio,
        isNull,
      );
    });

    test('non-parseable string returns null', () {
      final block = ArticleBlock.fromJson({
        'type': 'figure',
        'src': 'x',
        'aspectRatio': 'auto',
      });
      expect(block.aspectRatio, isNull);
    });
  });

  group('ArticleBlock.sectionHead', () {
    test('type is parsed from JSON', () {
      final block = ArticleBlock.fromJson({
        'type': 'sectionHead',
        'number': '1',
        'title': 'Progresif Yuklenme',
        'level': 2,
      });
      expect(block.type, ArticleBlockType.sectionHead);
      expect(block.number, '1');
      expect(block.title, 'Progresif Yuklenme');
      expect(block.level, 2);
    });

    test('number defaults to empty string when missing', () {
      final block = ArticleBlock.fromJson({
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
  // Widget rendering
  // -------------------------------------------------------------------------

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      );

  group('ArticleBlockRenderer figure aspectRatio', () {
    testWidgets('wraps image in AspectRatio with backend ratio', (tester) async {
      final blocks = [
        ArticleBlock.fromJson({
          'type': 'figure',
          'src': 'https://example.com/hero.jpg',
          'alt': 'Hero',
          'caption': '',
          'aspectRatio': 1.7778,
        }),
      ];
      await tester.pumpWidget(wrap(
        ArticleBlockRenderer(blocks: blocks, contentWidth: 360),
      ));
      expect(tester.takeException(), isNull);
      final aspectFinder = find.byType(AspectRatio);
      expect(aspectFinder, findsOneWidget);
      final aspect = tester.widget<AspectRatio>(aspectFinder);
      expect(aspect.aspectRatio, closeTo(1.7778, 0.0001));
    });

    testWidgets('falls back to 16/9 when aspectRatio missing', (tester) async {
      final blocks = [
        ArticleBlock.fromJson({
          'type': 'figure',
          'src': 'https://example.com/note.jpg',
          'alt': '',
          'caption': '',
        }),
      ];
      await tester.pumpWidget(wrap(
        ArticleBlockRenderer(blocks: blocks, contentWidth: 360),
      ));
      expect(tester.takeException(), isNull);
      final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspect.aspectRatio, closeTo(16 / 9, 0.0001));
    });
  });

  group('ArticleBlockRenderer sectionHead', () {
    testWidgets('renders number badge + title when number is present',
        (tester) async {
      final blocks = [
        ArticleBlock.fromJson({
          'type': 'sectionHead',
          'number': '1',
          'title': 'Progresif Yuklenme',
          'level': 2,
        }),
      ];
      await tester.pumpWidget(wrap(
        ArticleBlockRenderer(blocks: blocks, contentWidth: 360),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Progresif Yuklenme'), findsOneWidget);
    });

    testWidgets('renders only title when number is empty', (tester) async {
      final blocks = [
        ArticleBlock.fromJson({
          'type': 'sectionHead',
          'number': '',
          'title': 'Beslenme Stratejisi',
          'level': 3,
        }),
      ];
      await tester.pumpWidget(wrap(
        ArticleBlockRenderer(blocks: blocks, contentWidth: 360),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Beslenme Stratejisi'), findsOneWidget);
      // Numara olmadigi icin sadece baslik gozukur — basliktan
      // ayni metinli ikinci bir Text widget olmamali.
      expect(find.text('3'), findsNothing);
    });
  });
}
