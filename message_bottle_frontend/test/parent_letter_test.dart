import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/models.dart';
import 'package:message_bottle_frontend/screens/letter_detail_screen.dart';

import 'support.dart';

Map<String, dynamic> parentJson(
  int id, {
  required String role,
  String? counterpart = 'Mina',
  String content = '이전 편지',
  int? parentId,
}) => {
  'id': id,
  'role': role,
  'counterpartUsername': counterpart,
  'anonymous': false,
  'content': content,
  'sentAt': '2026-11-05T10:00:00',
  'parentLetterId': parentId,
};

void main() {
  testWidgets('부모 편지가 없으면 이전 편지 버튼이 없다', (tester) async {
    usePhone(tester);
    final services = await makeServices(FakeServer());
    await showScreen(
      tester,
      LetterDetailScreen(
        services: services,
        data: DetailData.fromLetterJson(letterJson()),
      ),
    );
    expect(find.byKey(const Key('detail-parent')), findsNothing);
  });

  testWidgets('답장이면 제목 위에 이전 편지 버튼이 있고, 누르면 이전 편지가 읽기 전용으로 열린다', (
    tester,
  ) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/letters/30/parent',
        body: parentJson(
          20,
          role: 'SENDER',
          content: '내가 보낸 편지',
          parentId: null,
        ),
      );
    final services = await makeServices(server);
    await showScreen(
      tester,
      LetterDetailScreen(
        services: services,
        data: DetailData.fromLetterJson({
          ...letterJson(id: 30),
          'parentLetterId': 20,
        }),
      ),
    );

    final button = tester.getRect(find.byKey(const Key('detail-parent')));
    final heading = tester.getRect(find.byKey(const Key('detail-heading')));
    expect(button.bottom, lessThanOrEqualTo(heading.top + 1), reason: '제목 위');

    await tester.tap(find.byKey(const Key('detail-parent')));
    await settle(tester, ms: 1000);

    expect(server.count('GET', '/api/letters/30/parent'), 1);
    expect(find.text('내가 보낸 편지'), findsOneWidget);
    expect(
      find.text('Mina 님에게 보낸 편지'),
      findsOneWidget,
      reason: '내가 보낸 편지는 보낸 편지처럼 보인다',
    );
    expect(find.byKey(const Key('detail-back')), findsOneWidget);
    expect(find.byKey(const Key('detail-discard')), findsNothing);
    expect(find.byKey(const Key('detail-parent')), findsNothing);
  });

  testWidgets('이전 편지에 또 이전 편지가 있으면 계속 거슬러 올라가고, 뒤로 가면 한 단계씩 돌아온다', (
    tester,
  ) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/letters/30/parent',
        body: parentJson(20, role: 'SENDER', content: '둘째 편지', parentId: 10),
      )
      ..on(
        'GET',
        '/api/letters/20/parent',
        body: parentJson(
          10,
          role: 'RECEIVER',
          content: '첫째 편지',
          parentId: null,
        ),
      );
    final services = await makeServices(server);
    await showScreen(
      tester,
      LetterDetailScreen(
        services: services,
        data: DetailData.fromLetterJson({
          ...letterJson(id: 30, content: '셋째 편지'),
          'parentLetterId': 20,
        }),
      ),
    );

    await tester.tap(find.byKey(const Key('detail-parent')));
    await settle(tester, ms: 1000);
    expect(find.text('둘째 편지'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-parent')));
    await settle(tester, ms: 1000);
    expect(find.text('첫째 편지'), findsOneWidget);
    expect(find.text('Mina 님의 편지'), findsOneWidget, reason: '받은 편지로 보인다');
    expect(find.byKey(const Key('detail-parent')), findsNothing);

    await tester.tap(find.byKey(const Key('detail-back')));
    await settle(tester, ms: 1000);
    expect(find.text('둘째 편지'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-back')));
    await settle(tester, ms: 1000);
    expect(find.text('셋째 편지'), findsOneWidget);
    expect(find.byKey(const Key('detail-discard')), findsOneWidget);
    expect(find.byKey(const Key('detail-archive')), findsOneWidget);
  });

  testWidgets('이전 편지를 볼 수 없게 되었으면 안내하고 현재 편지는 그대로다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/letters/30/parent',
        body: {'message': '이미 사라졌거나 존재하지 않는 편지입니다.'},
        status: 404,
      );
    final services = await makeServices(server);
    await showScreen(
      tester,
      LetterDetailScreen(
        services: services,
        data: DetailData.fromLetterJson({
          ...letterJson(id: 30),
          'parentLetterId': 20,
        }),
      ),
    );

    await tester.tap(find.byKey(const Key('detail-parent')));
    await settle(tester, ms: 1000);

    expect(find.text('이전 편지를 더 이상 볼 수 없어요.'), findsOneWidget);
    expect(find.byKey(const Key('detail-heading')), findsOneWidget);
    expect(find.byKey(const Key('detail-discard')), findsOneWidget);
  });

  testWidgets('받은 편지함·보낸 편지함 상세도 부모 id를 읽는다', (tester) async {
    final inbox = DetailData.fromInboxJson({
      'archiveId': 5,
      'letterId': 31,
      'senderUsername': 'Mina',
      'anonymous': false,
      'content': 'x',
      'sentAt': '2026-11-05T10:00:00',
      'parentLetterId': 20,
    });
    final sent = DetailData.fromSentJson({
      'id': 32,
      'receiverUsername': 'Mina',
      'anonymous': false,
      'content': 'x',
      'sentAt': '2026-11-05T10:00:00',
      'parentLetterId': 21,
    });
    expect(inbox.parentId, 20);
    expect(sent.parentId, 21);
    expect(sent.id, 32);
  });
}
