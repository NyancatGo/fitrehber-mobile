import 'package:fitrehber_mobile/features/article/widgets/article_content_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('article renderer builds site-like content blocks', (
    tester,
  ) async {
    const html = '''
      <div class="article-body">
        <nav class="box box-toc">
          <p class="box-title">Icindekiler</p>
          <ol><li><a href="#ozet">Ozet</a></li></ol>
        </nav>
        <h2 id="ozet">Ozet</h2>
        <section class="box box-summary">
          <p class="lead">Bu makale ne anlatiyor?</p>
        </section>
        <div class="fraction-list">
          <div class="fraction-item">
            <div class="fraction-badge">WPC</div>
            <div><h4>Konsantre</h4><p>En yaygin formdur.</p></div>
          </div>
        </div>
        <div class="facts">
          <h3>Temel Parametreler</h3>
          <ul><li>Gunluk protein alimi</li></ul>
        </div>
        <figure class="media">
          <img src="https://example.com/image.jpg" width="1200" height="700" />
          <figcaption>Gorsel aciklamasi</figcaption>
        </figure>
      </div>
    ''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArticleContentRenderer(html: html, contentWidth: 360),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Icindekiler', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Konsantre', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Temel Parametreler', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(AspectRatio), findsOneWidget);
  });
}
