import 'package:fitrehber_mobile/features/icerik/widgets/yorum_karti.dart';
import 'package:fitrehber_mobile/shared/models/yorum_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  YorumModel yorum({
    required int id,
    required String mesaj,
    int depth = 0,
    int? parent,
    int toplamYanitSayisi = 0,
    bool hasMoreReplies = false,
    List<YorumModel>? yanitlar,
  }) {
    return YorumModel(
      id: id,
      mesaj: mesaj,
      tarih: DateTime.now().toUtc().toIso8601String(),
      parent: parent,
      depth: depth,
      yazar: {'id': id, 'username': 'user$id'},
      toplamYanitSayisi: toplamYanitSayisi,
      hasMoreReplies: hasMoreReplies,
      yanitlar: yanitlar,
    );
  }

  Widget host({
    required YorumModel model,
    required int depth,
    ValueChanged<YorumModel>? onContinueThread,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: YorumKarti(
          yorum: model,
          depth: depth,
          opAuthorName: null,
          canModerate: false,
          currentUserId: null,
          expandedIds: {model.id},
          onReply: (_) {},
          onLike: (_) {},
          onDelete: (_) {},
          onToggleCollapse: (_) {},
          onAuthorTap: (_) {},
          onContinueThread: onContinueThread,
        ),
      ),
    );
  }

  testWidgets('maksimum iç içe derinlikte yanıtları keser', (tester) async {
    final child = yorum(id: 2, mesaj: 'deep child', parent: 1, depth: 3);
    final parent = yorum(
      id: 1,
      mesaj: 'focused parent',
      depth: 2,
      toplamYanitSayisi: 1,
      hasMoreReplies: true,
      yanitlar: [child],
    );

    await tester.pumpWidget(
      host(model: parent, depth: 2, onContinueThread: (_) {}),
    );

    expect(find.text('focused parent'), findsOneWidget);
    expect(find.text('deep child'), findsNothing);
    expect(find.textContaining('Bu tartışmanın devamını gör'), findsOneWidget);
  });

  testWidgets('devam butonu seçilen yorumu döndürür', (tester) async {
    YorumModel? selected;
    final parent = yorum(
      id: 7,
      mesaj: 'thread parent',
      depth: 2,
      toplamYanitSayisi: 3,
      hasMoreReplies: true,
    );

    await tester.pumpWidget(
      host(
        model: parent,
        depth: 2,
        onContinueThread: (yorum) => selected = yorum,
      ),
    );

    await tester.tap(find.textContaining('Bu tartışmanın devamını gör'));
    await tester.pump();

    expect(selected?.id, 7);
  });
}
