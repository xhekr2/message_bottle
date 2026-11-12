import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';

import 'support.dart';

Map<String, dynamic> inboxItem(
  int archiveId, {
  String sender = 'Mina',
  bool anonymous = false,
  bool replied = false,
  String? preview,
}) => {
  'archiveId': archiveId,
  'letterId': archiveId + 100,
  'senderUsername': anonymous ? null : sender,
  'anonymous': anonymous,
  'preview': preview ?? '보관한 편지 $archiveId',
  'sentAt': '2026-11-05T10:00:00',
  'archivedAt': '2026-11-06T10:00:00',
  'replied': replied,
};

Map<String, dynamic> sentItem(
  int id, {
  String to = 'Bob123',
  bool anonymous = false,
}) => {
  'id': id,
  'receiverUsername': to,
  'anonymous': anonymous,
  'preview': '보낸 편지 $id',
  'sentAt': '2026-11-09T10:00:00',
};

Future<FakeServer> openSea(WidgetTester tester, FakeServer server) async {
  server.on('GET', '/api/sea/me', body: seaJson([]));
  await tester.pumpWidget(
    testApp(SeaScreen(services: await makeServices(server))),
  );
  await settle(tester);
  return server;
}

void main() {
  group('받은 편지함', () {
    testWidgets('답장한 편지의 카드에만 맨 오른쪽에 체크 아이콘이 있다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'GET',
          '/api/inbox',
          body: [
            inboxItem(1, replied: true),
            inboxItem(2),
            inboxItem(3, anonymous: true),
          ],
        );
      await openSea(tester, server);

      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      expect(find.byKey(const Key('mailbox-title')), findsOneWidget);
      expect(find.text('받은 편지함'), findsWidgets);
      expect(find.byKey(const Key('replied-check')), findsOneWidget);
      final card = tester.getRect(find.byKey(const ValueKey('inbox-1')));
      final check = tester.getRect(find.byKey(const Key('replied-check')));
      expect(check.right, greaterThan(card.right - 30), reason: '카드 맨 오른쪽');
      expect(check.center.dy, closeTo(card.center.dy, 6));
      expect(
        find.textContaining('익명', findRichText: true),
        findsOneWidget,
        reason: '익명 편지는 보낸 사람 대신 익명',
      );
      expect(find.textContaining('Mina', findRichText: true), findsNWidgets(2));
    });

    testWidgets('카드를 오른쪽에서 왼쪽으로 밀면 확인 없이 삭제하고 서버에서 확인된 뒤에 지운다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/inbox', body: [inboxItem(1), inboxItem(2)])
        ..on('DELETE', '/api/inbox/1', status: 204);
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      await tester.drag(
        find.byKey(const ValueKey('dismiss-1')),
        const Offset(-500, 0),
      );
      await settle(tester, ms: 1000);

      expect(server.count('DELETE', '/api/inbox/1'), 1);
      expect(find.text('보관한 편지 1'), findsNothing);
      expect(find.text('보관한 편지 2'), findsOneWidget);
      expect(find.text('삭제했어요.'), findsOneWidget);
      expect(find.textContaining('정말'), findsNothing, reason: '삭제 확인 창이 없다');
    });

    testWidgets('왼쪽에서 오른쪽으로 밀면 삭제되지 않는다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/inbox', body: [inboxItem(1)]);
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      await tester.drag(
        find.byKey(const ValueKey('dismiss-1')),
        const Offset(500, 0),
      );
      await settle(tester, ms: 1000);

      expect(find.text('보관한 편지 1'), findsOneWidget);
      expect(server.count('DELETE', '/api/inbox/1'), 0);
    });

    testWidgets('삭제가 서버에서 실패하면 카드가 돌아오고 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/inbox', body: [inboxItem(1)])
        ..on('DELETE', '/api/inbox/1', body: {'message': '서버 오류'}, status: 500);
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      await tester.drag(
        find.byKey(const ValueKey('dismiss-1')),
        const Offset(-500, 0),
      );
      await settle(tester, ms: 1000);

      expect(find.text('보관한 편지 1'), findsOneWidget);
      expect(find.text('삭제하지 못했습니다. 카드를 다시 밀어 보세요.'), findsOneWidget);
      expect(find.text('삭제했어요.'), findsNothing);
    });

    testWidgets('카드를 누르면 편지를 열고, 뒤로 가기로 돌아오면 목록이 다시 열린다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/inbox', body: [inboxItem(1, replied: true)])
        ..on(
          'GET',
          '/api/inbox/1',
          body: {
            'archiveId': 1,
            'letterId': 101,
            'senderUsername': 'Mina',
            'anonymous': false,
            'content': '보관해 둔 편지의 전체 내용',
            'sentAt': '2026-11-05T10:00:00',
            'archivedAt': '2026-11-06T10:00:00',
            'replied': true,
          },
        );
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      await tester.tap(find.text('보관한 편지 1'));
      await settle(tester, ms: 1000);

      expect(find.text('보관해 둔 편지의 전체 내용'), findsOneWidget);
      expect(find.byKey(const Key('detail-discard')), findsNothing);
      expect(
        find.byKey(const Key('detail-reply')),
        findsNothing,
        reason: '보관함에서는 답장할 수 없다',
      );

      await tester.tap(find.byKey(const Key('detail-back')));
      await settle(tester, ms: 1000);

      expect(find.byKey(const Key('mailbox-title')), findsOneWidget);
      expect(find.byKey(const Key('replied-check')), findsOneWidget);
    });

    testWidgets('카드가 많아져도 카드는 줄어들지 않고 목록이 스크롤되며, 돌아오면 스크롤 위치를 되살린다', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'GET',
          '/api/inbox',
          body: [for (var i = 1; i <= 30; i++) inboxItem(i)],
        )
        ..on(
          'GET',
          '/api/inbox/12',
          body: {
            'archiveId': 12,
            'letterId': 112,
            'senderUsername': 'Mina',
            'anonymous': false,
            'content': '열어 본 편지',
            'sentAt': '2026-11-05T10:00:00',
            'archivedAt': '2026-11-06T10:00:00',
            'replied': false,
          },
        );
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      final heights = <double>{
        for (var i = 1; i <= 30; i++)
          if (find.byKey(ValueKey('inbox-$i')).evaluate().isNotEmpty)
            tester.getSize(find.byKey(ValueKey('inbox-$i'))).height,
      };
      expect(heights, hasLength(1), reason: '보이는 카드는 모두 같은 높이');
      expect(heights.single, greaterThanOrEqualTo(72));
      expect(find.text('보관한 편지 30'), findsNothing, reason: '화면 밖은 스크롤해야 보인다');

      await tester.scrollUntilVisible(
        find.text('보관한 편지 12'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await settle(tester);
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      final before = position().pixels;
      expect(before, greaterThan(0));

      await tester.tap(find.text('보관한 편지 12'));
      await settle(tester, ms: 1000);
      await tester.tap(find.byKey(const Key('detail-back')));
      await settle(tester, ms: 1000);

      expect(position().pixels, closeTo(before, 1));
      expect(find.text('보관한 편지 12'), findsOneWidget);
    });

    testWidgets('편지가 없으면 안내하고, 읽기에 실패하면 다시 시도할 수 있다', (tester) async {
      usePhone(tester);
      var fail = true;
      final server = FakeServer()
        ..on(
          'GET',
          '/api/inbox',
          handler: (_) => fail
              ? FakeServer.json({'message': '서버 오류'}, status: 500)
              : FakeServer.json([]),
        );
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      expect(find.text('불러오지 못했습니다.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('다시 시도'));
      await settle(tester);

      expect(find.text('보관한 편지가 없습니다'), findsOneWidget);
    });
  });

  group('보낸 편지함', () {
    testWidgets('삭제 수단이 없고 익명으로 보낸 편지는 표시한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'GET',
          '/api/sent',
          body: [sentItem(1), sentItem(2, anonymous: true)],
        );
      await openSea(tester, server);

      await tester.tap(find.byKey(const Key('sea-sent')));
      await settle(tester);

      expect(find.text('보낸 편지함'), findsWidgets);
      expect(find.text('보낸 편지는 삭제할 수 없어요.'), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
      expect(find.textContaining('익명으로 보냄'), findsOneWidget);
      expect(find.byKey(const Key('replied-check')), findsNothing);
    });

    testWidgets('편지가 없으면 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()..on('GET', '/api/sent', body: []);
      await openSea(tester, server);

      await tester.tap(find.byKey(const Key('sea-sent')));
      await settle(tester);

      expect(find.text('보낸 편지가 없습니다'), findsOneWidget);
    });

    testWidgets('보낸 편지를 열면 읽기 전용이고 뒤로 가기로 목록에 돌아온다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sent', body: [sentItem(1, anonymous: true)])
        ..on(
          'GET',
          '/api/sent/1',
          body: {
            'id': 1,
            'receiverUsername': 'Bob123',
            'anonymous': true,
            'content': '보낸 편지 전문',
            'sentAt': '2026-11-09T10:00:00',
          },
        );
      await openSea(tester, server);
      await tester.tap(find.byKey(const Key('sea-sent')));
      await settle(tester);

      await tester.tap(find.text('보낸 편지 1'));
      await settle(tester, ms: 1000);
      expect(find.text('Bob123 님에게 보낸 편지 (익명)'), findsOneWidget);
      expect(find.byKey(const Key('detail-archive')), findsNothing);

      await systemBack(tester);
      expect(find.byKey(const Key('mailbox-title')), findsOneWidget);
    });
  });

  group('팝업 닫기', () {
    testWidgets('바깥을 터치하거나 뒤로 가기를 누르거나 닫기 버튼을 누르면 닫힌다', (tester) async {
      usePhone(tester);
      final server = FakeServer()..on('GET', '/api/sent', body: [sentItem(1)]);
      await openSea(tester, server);

      await tester.tap(find.byKey(const Key('sea-sent')));
      await settle(tester);
      await tester.tapAt(const Offset(4, 400));
      await settle(tester);
      expect(find.byKey(const Key('mailbox-title')), findsNothing);

      await tester.tap(find.byKey(const Key('sea-sent')));
      await settle(tester);
      await systemBack(tester);
      expect(find.byKey(const Key('mailbox-title')), findsNothing);

      await tester.tap(find.byKey(const Key('sea-sent')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('mailbox-close')));
      await settle(tester);
      expect(find.byKey(const Key('mailbox-title')), findsNothing);
    });
  });
}
