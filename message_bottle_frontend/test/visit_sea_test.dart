import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:message_bottle_frontend/models.dart';
import 'package:message_bottle_frontend/screens/letter_detail_screen.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';
import 'package:message_bottle_frontend/screens/visit_sea_screen.dart';

import 'support.dart';

Map<String, dynamic> publicSea(String username, int count) => {
  'username': username,
  'floatingCount': count,
};

Map<String, dynamic> inboxItem(
  int archiveId, {
  String? sender = 'Mina',
  bool anonymous = false,
}) => {
  'archiveId': archiveId,
  'letterId': archiveId + 100,
  'senderUsername': anonymous ? null : sender,
  'anonymous': anonymous,
  'preview': '보관한 편지 $archiveId',
  'sentAt': '2026-11-05T10:00:00',
  'archivedAt': '2026-11-06T10:00:00',
  'replied': false,
};

DetailData inboxLetter({
  String? counterpart = 'Mina',
  bool anonymous = false,
}) => DetailData.fromInboxJson({
  'archiveId': 5,
  'letterId': 1,
  'senderUsername': anonymous ? null : counterpart,
  'anonymous': anonymous,
  'content': '보관한 편지의 내용',
  'sentAt': '2026-11-05T10:00:00',
  'archivedAt': '2026-11-06T10:00:00',
  'replied': false,
});

void main() {
  group('다른 사람의 바다 방문 화면', () {
    testWidgets('공개된 바다는 "OOO의 바다"로 누구의 바다인지 보여주고 유리병 개수만 보여준다', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/users/Mina', body: publicSea('Mina', 3));
      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            services: await makeServices(server),
            username: 'Mina',
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Mina의 바다'), findsOneWidget);
      expect(find.text('유리병 3개가 떠 있어요'), findsOneWidget);
      expect(find.textContaining('개수만 볼 수 있어요'), findsOneWidget);
      expect(find.bySemanticsLabel('유리병'), findsNWidgets(3));
      expect(server.count('GET', '/api/sea/users/Mina'), 1);
    });

    testWidgets('유리병을 눌러도 편지를 열 수 없다(누를 수 있는 유리병이 없다)', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/users/Mina', body: publicSea('Mina', 2));
      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            services: await makeServices(server),
            username: 'Mina',
          ),
        ),
      );
      await settle(tester);

      expect(find.bySemanticsLabel('유리병 편지 열기'), findsNothing);
      await tester.tap(find.bySemanticsLabel('유리병').first, warnIfMissed: false);
      await settle(tester);
      expect(
        server.requests.where((r) => r.url.path.startsWith('/api/letters')),
        isEmpty,
      );
    });

    testWidgets('개수가 10을 넘어도 10개까지만 그리고, 0이면 비어 있다고 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/users/Full', body: publicSea('Full', 10))
        ..on('GET', '/api/sea/users/Empty', body: publicSea('Empty', 0));
      final services = await makeServices(server);

      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            key: const ValueKey('Full'),
            services: services,
            username: 'Full',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('유리병 10개가 떠 있어요'), findsOneWidget);
      expect(find.bySemanticsLabel('유리병'), findsNWidgets(10));

      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            key: const ValueKey('Empty'),
            services: services,
            username: 'Empty',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('떠 있는 유리병이 없어요'), findsOneWidget);
    });

    testWidgets('비공개 바다(403)는 개수 없이 안내만 보여준다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'GET',
          '/api/sea/users/Mina',
          body: {'message': '비공개 바다입니다.'},
          status: 403,
        );
      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            services: await makeServices(server),
            username: 'Mina',
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Mina의 바다'), findsOneWidget);
      expect(find.byKey(const Key('visit-private')), findsOneWidget);
      expect(find.textContaining('유리병 개수를 볼 수 있어요'), findsOneWidget);
      expect(find.byKey(const Key('visit-count')), findsNothing);
    });

    testWidgets('없는 사용자(404)와 읽기 실패를 구분해서 안내하고 다시 시도할 수 있다', (tester) async {
      usePhone(tester);
      var fail = true;
      final server = FakeServer()
        ..on(
          'GET',
          '/api/sea/users/Ghost',
          body: {'message': '존재하지 않는 사용자입니다.'},
          status: 404,
        )
        ..on(
          'GET',
          '/api/sea/users/Mina',
          handler: (_) => fail
              ? FakeServer.json({'message': '서버 오류'}, status: 500)
              : FakeServer.json(publicSea('Mina', 1)),
        );
      final services = await makeServices(server);

      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            key: const ValueKey('Ghost'),
            services: services,
            username: 'Ghost',
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('visit-notfound')), findsOneWidget);

      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            key: const ValueKey('Mina2'),
            services: services,
            username: 'Mina',
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('visit-failed')), findsOneWidget);

      fail = false;
      await tester.tap(find.byKey(const Key('visit-retry')));
      await settle(tester);
      expect(find.text('유리병 1개가 떠 있어요'), findsOneWidget);
    });

    testWidgets('뒤로 가기로 돌아간다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/users/Mina', body: publicSea('Mina', 1));
      await showScreen(
        tester,
        VisitSeaScreen(services: await makeServices(server), username: 'Mina'),
      );

      await tester.tap(find.byKey(const Key('visit-back')));
      await settle(tester, ms: 1000);

      expect(find.byKey(const Key('visit-title')), findsNothing);
    });
  });

  group('받은 편지에서 보낸 사람의 바다로', () {
    testWidgets('받은 편지함에서 연 편지(익명 아님)에는 "OOO의 바다" 버튼이 있고 누르면 방문한다', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/users/Mina', body: publicSea('Mina', 4));
      final services = await makeServices(server);
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: inboxLetter()),
      );

      expect(find.byKey(const Key('detail-visit')), findsOneWidget);
      expect(find.text('바다 이동'), findsOneWidget);
      // 버튼은 보낸 사람 이름(제목) 옆, 같은 줄에 있다.
      final heading = tester.getRect(find.byKey(const Key('detail-heading')));
      final button = tester.getRect(find.byKey(const Key('detail-visit')));
      expect(button.left, greaterThanOrEqualTo(heading.right));
      expect((button.center.dy - heading.center.dy).abs(), lessThan(20));

      await tester.tap(find.byKey(const Key('detail-visit')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('visit-title')), findsOneWidget);
      expect(find.text('유리병 4개가 떠 있어요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-back')));
      await settle(tester, ms: 1000);
      expect(
        find.byKey(const Key('detail-heading')),
        findsOneWidget,
        reason: '방문을 마치면 편지로 돌아온다',
      );
    });

    testWidgets('바다에서 연 편지(익명 아님)에도 이동 버튼이 있고, 다녀오면 편지가 그대로 열려 있다', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/users/Mina', body: publicSea('Mina', 2));
      final services = await makeServices(server);
      await tester.pumpWidget(
        testApp(
          LetterDetailScreen(
            services: services,
            data: DetailData.fromLetterJson(letterJson()),
          ),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('detail-visit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('detail-visit')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('visit-title')), findsOneWidget);
      expect(find.text('Mina의 바다'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-back')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('detail-heading')), findsOneWidget);
      expect(find.byKey(const Key('detail-discard')), findsOneWidget);
      expect(find.byKey(const Key('detail-archive')), findsOneWidget);
    });

    testWidgets('바다에서 연 익명 편지에는 이동 버튼이 없다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      await tester.pumpWidget(
        testApp(
          LetterDetailScreen(
            services: services,
            data: DetailData.fromLetterJson(
              letterJson(anonymous: true, counterpart: null),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('detail-visit')), findsNothing);
    });

    testWidgets('받은 편지함의 익명 편지와 보낸 편지에는 이동 버튼이 없다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());

      await showScreen(
        tester,
        LetterDetailScreen(
          services: services,
          data: inboxLetter(anonymous: true),
        ),
      );
      expect(find.byKey(const Key('detail-visit')), findsNothing);
      await systemBack(tester);

      await tester.pumpWidget(
        testApp(
          LetterDetailScreen(
            services: services,
            data: DetailData.fromSentJson({
              'id': 3,
              'receiverUsername': 'Bob123',
              'anonymous': false,
              'content': 'x',
              'sentAt': '2026-11-09T10:00:00',
            }),
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('detail-visit')), findsNothing);
    });

    testWidgets('받은 편지함 카드의 보낸 사람 이름을 누르면 방문하고, 돌아오면 목록이 다시 열린다', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaJson([]))
        ..on(
          'GET',
          '/api/inbox',
          body: [inboxItem(1), inboxItem(2, anonymous: true)],
        )
        ..on('GET', '/api/sea/users/Mina', body: publicSea('Mina', 2));
      await tester.pumpWidget(
        testApp(SeaScreen(services: await makeServices(server))),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      expect(find.byKey(const Key('card-visit-Mina')), findsOneWidget);
      expect(
        find.byKey(const Key('card-visit-익명')),
        findsNothing,
        reason: '익명 편지는 보낸 사람을 알 수 없어 누를 수 없다',
      );

      await tester.tap(find.byKey(const Key('card-visit-Mina')));
      await settle(tester, ms: 1000);
      expect(find.text('Mina의 바다'), findsOneWidget);
      expect(find.text('유리병 2개가 떠 있어요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('visit-back')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('mailbox-title')), findsOneWidget);
      expect(find.text('보관한 편지 1'), findsOneWidget);
    });

    testWidgets('카드의 이름이 아닌 부분을 누르면 여전히 편지가 열린다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaJson([]))
        ..on('GET', '/api/inbox', body: [inboxItem(1)])
        ..on(
          'GET',
          '/api/inbox/1',
          body: {
            'archiveId': 1,
            'letterId': 101,
            'senderUsername': 'Mina',
            'anonymous': false,
            'content': '편지 전문',
            'sentAt': '2026-11-05T10:00:00',
            'archivedAt': '2026-11-06T10:00:00',
            'replied': false,
          },
        );
      await tester.pumpWidget(
        testApp(SeaScreen(services: await makeServices(server))),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester);

      await tester.tap(find.text('보관한 편지 1'));
      await settle(tester, ms: 1000);

      expect(find.text('편지 전문'), findsOneWidget);
      expect(server.count('GET', '/api/sea/users/Mina'), 0);
    });

    testWidgets('서버에 닿지 못해도 방문 화면이 오류를 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'GET',
          '/api/sea/users/Mina',
          handler: (_) => throw http.ClientException('연결 실패'),
        );
      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            services: await makeServices(server),
            username: 'Mina',
          ),
        ),
      );
      await settle(tester, ms: 1000);

      expect(find.byKey(const Key('visit-failed')), findsOneWidget);
      expect(find.textContaining('서버에 연결할 수 없습니다'), findsOneWidget);
    });
  });
}
