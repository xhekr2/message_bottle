import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/models.dart';
import 'package:message_bottle_frontend/screens/home_screen.dart';

import 'support.dart';

Map<String, dynamic> sharedLetter(int id, [String content = '바다 건너의 이야기']) => {
  'id': id,
  'content': content,
  'sentAt': '2026-11-10T09:00:00',
};

Future<FakeServer> openHome(WidgetTester tester, FakeServer server) async {
  usePhone(tester);
  server.on('GET', '/api/sea/me', body: seaJson([1]));
  await tester.pumpWidget(
    testApp(HomeScreen(services: await makeServices(server))),
  );
  await settle(tester);
  return server;
}

Future<void> toSharedSea(WidgetTester tester) async {
  await tester.fling(
    find.byKey(const Key('home-pages')),
    const Offset(-500, 0),
    1500,
  );
  await settle(tester, ms: 1000);
}

void main() {
  group('스와이프', () {
    testWidgets('내 바다에서 옆으로 밀면 공유 바다로 넘어가고, 되돌아오면 내 바다가 그대로다', (tester) async {
      await openHome(tester, FakeServer());
      expect(find.byKey(const Key('bottle-1')), findsOneWidget);
      expect(find.byKey(const Key('sea-write')), findsOneWidget);
      expect(find.byKey(const Key('shared-fish')), findsNothing);

      await toSharedSea(tester);
      expect(find.byKey(const Key('shared-title')), findsOneWidget);
      expect(find.byKey(const Key('shared-fish')), findsOneWidget);

      await tester.fling(
        find.byKey(const Key('home-pages')),
        const Offset(500, 0),
        1500,
      );
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('bottle-1')), findsOneWidget);
      expect(find.byKey(const Key('shared-fish')), findsNothing);
    });

    testWidgets('위쪽 표시를 눌러서도 넘길 수 있다', (tester) async {
      await openHome(tester, FakeServer());
      await tester.tap(find.byKey(const Key('home-tab-1')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('shared-title')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-tab-0')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('sea-write')), findsOneWidget);
    });

    testWidgets('서랍이 열리면 서랍이 위쪽 표시보다 위에 있어 표시가 눌리지 않는다', (tester) async {
      await openHome(tester, FakeServer());
      await tester.tap(find.byKey(const Key('sea-menu')));
      await settle(tester, ms: 800);
      expect(find.byKey(const Key('sea-drawer')), findsOneWidget);

      // 표시가 서랍 영역 안에 있어도 눌리는 것은 서랍이다.
      final tab = tester.getCenter(find.byKey(const Key('home-tab-1')));
      final drawer = tester.getRect(find.byKey(const Key('sea-drawer')));
      expect(drawer.contains(tab), isTrue);
      await tester.tapAt(tab);
      await settle(tester, ms: 800);
      expect(find.byKey(const Key('shared-title')), findsNothing);
      expect(find.byKey(const Key('sea-drawer')), findsOneWidget);
    });

    testWidgets('공유 바다에는 유리병이 없고 유리병 낚기 버튼이 아래 가운데에 둥글게 있다', (tester) async {
      await openHome(tester, FakeServer());
      await toSharedSea(tester);

      expect(find.byKey(const Key('bottle-1')), findsNothing);
      final rect = tester.getRect(find.byKey(const Key('shared-fish')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect((rect.center.dx - screen.width / 2).abs(), lessThan(2));
      expect(rect.bottom, greaterThan(screen.height * 0.75));
      expect((rect.width - rect.height).abs(), lessThan(1), reason: '원 모양');
      expect(find.text('유리병 낚기'), findsOneWidget);
    });
  });

  group('내 바다로 돌아올 때', () {
    testWidgets('UI가 숨겨진 뒤 공유 바다에 다녀와도 돌아오면 UI가 보인다', (tester) async {
      usePhone(tester);
      final server = FakeServer()..on('GET', '/api/sea/me', body: seaJson([1]));
      final services = await makeServices(server);
      await services.settings.setIdleSeconds(3);
      await tester.pumpWidget(testApp(HomeScreen(services: services)));
      await settle(tester);
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .ancestor(
                  of: find.byKey(const Key('sea-sent')),
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          )
          .opacity;

      await settle(tester, ms: 3600);
      expect(opacity(), 0, reason: '가만히 있으면 숨는다');

      await toSharedSea(tester);
      await settle(tester, ms: 4000);
      await tester.fling(
        find.byKey(const Key('home-pages')),
        const Offset(500, 0),
        1500,
      );
      await settle(tester, ms: 1200);
      expect(opacity(), 1, reason: '내 바다로 돌아오면 UI가 보인다');
      expect(find.byKey(const Key('sea-write')), findsOneWidget);
    });
  });

  group('낚기', () {
    testWidgets('남은 편지가 없으면 "남아있는 편지가 없어요!"를 보여준다', (tester) async {
      final server = FakeServer()
        ..on(
          'POST',
          '/api/shared-sea/fish',
          body: {'message': '남아있는 편지가 없어요!'},
          status: 404,
        );
      await openHome(tester, server);
      await toSharedSea(tester);

      await tester.tap(find.byKey(const Key('shared-fish')));
      await settle(tester, ms: 4500);

      expect(find.text('남아있는 편지가 없어요!'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing, reason: '체크 아이콘 없이 글자만');
      expect(find.byIcon(Icons.priority_high), findsNothing);
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      expect(server.count('POST', '/api/shared-sea/fish'), 1);
    });

    testWidgets('낚은 편지는 익명이고 보관 버튼 없이 답장만 있으며 X는 그냥 닫는다', (tester) async {
      final server = FakeServer()
        ..on('POST', '/api/shared-sea/fish', body: sharedLetter(7));
      await openHome(tester, server);
      await toSharedSea(tester);

      await tester.tap(find.byKey(const Key('shared-fish')));
      await settle(tester, ms: 3800);
      // 올라온 유리병을 눌러야 편지가 열린다.
      await tester.tap(find.byKey(const Key('fished-bottle')));
      await settle(tester, ms: 1000);

      expect(find.text('익명의 유리병'), findsOneWidget);
      expect(find.text('바다 건너의 이야기'), findsOneWidget);
      // 본문이 짧아도 일반 편지처럼 가로를 꽉 채우고 왼쪽에서 시작한다.
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final scroll = tester.getRect(
        find.ancestor(
          of: find.byKey(const Key('fished-content')),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroll.left, 0);
      expect(scroll.width, screenWidth);
      expect(tester.getRect(find.byKey(const Key('fished-content'))).left, 24);
      expect(tester.getRect(find.byKey(const Key('fished-heading'))).left, 24);
      expect(find.byKey(const Key('fished-reply')), findsOneWidget);
      expect(find.text('보관'), findsNothing);
      expect(find.byKey(const Key('detail-archive')), findsNothing);
      expect(find.byKey(const Key('detail-visit')), findsNothing);
      final x = tester.getRect(find.byKey(const Key('fished-close')));
      expect(x.right, greaterThan(300), reason: '우상단');
      expect(x.top, lessThan(80));

      await tester.tap(find.byKey(const Key('fished-close')));
      await settle(tester, ms: 800);
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      expect(find.byKey(const Key('shared-fish')), findsOneWidget);
      expect(
        server.requests.where(
          (r) => r.method != 'GET' && !r.url.path.endsWith('/fish'),
        ),
        isEmpty,
        reason: '닫기만으로는 삭제·답장 요청이 없다(편지는 바다에 남는다)',
      );

      // 다시 낚으면 같은 편지가 나올 수 있다
      await tester.tap(find.byKey(const Key('shared-fish')));
      await settle(tester, ms: 3800);
      // 올라온 유리병을 눌러야 편지가 열린다.
      await tester.tap(find.byKey(const Key('fished-bottle')));
      await settle(tester, ms: 1000);
      expect(find.text('바다 건너의 이야기'), findsOneWidget);
      expect(server.count('POST', '/api/shared-sea/fish'), 2);
    });

    testWidgets('Android 뒤로 가기도 편지를 삭제하지 않고 닫기만 한다', (tester) async {
      final server = FakeServer()
        ..on('POST', '/api/shared-sea/fish', body: sharedLetter(7));
      await openHome(tester, server);
      await toSharedSea(tester);
      await tester.tap(find.byKey(const Key('shared-fish')));
      await settle(tester, ms: 3800);
      // 올라온 유리병을 눌러야 편지가 열린다.
      await tester.tap(find.byKey(const Key('fished-bottle')));
      await settle(tester, ms: 1000);

      await systemBack(tester);
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      expect(find.byKey(const Key('shared-fish')), findsOneWidget);
    });
  });

  group('답장', () {
    Future<FakeServer> fished(WidgetTester tester, FakeServer server) async {
      server.on('POST', '/api/shared-sea/fish', body: sharedLetter(7));
      await openHome(tester, server);
      await toSharedSea(tester);
      await tester.tap(find.byKey(const Key('shared-fish')));
      await settle(tester, ms: 3800);
      // 올라온 유리병을 눌러야 편지가 열린다.
      await tester.tap(find.byKey(const Key('fished-bottle')));
      await settle(tester, ms: 1000);
      await tester.tap(find.byKey(const Key('fished-reply')));
      await settle(tester, ms: 800);
      return server;
    }

    testWidgets('답장을 보내면 공유 바다 편지에 답장이 전달되고 공유 바다로 돌아온다', (tester) async {
      final server = await fished(
        tester,
        FakeServer()..on(
          'POST',
          '/api/shared-sea/letters/7/replies',
          body: {'id': 90},
          status: 201,
        ),
      );
      expect(find.text('익명의 유리병에 답장'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('reply-text')), '읽었어요!');
      await tester.tap(find.byKey(const Key('reply-send')));
      await settle(tester, ms: 1000);

      expect(
        server.bodyOf(
          server.of('POST', '/api/shared-sea/letters/7/replies').single,
        ),
        {'content': '읽었어요!'},
      );
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      expect(find.byKey(const Key('shared-fish')), findsOneWidget);
      expect(find.text('답장을 보냈어요. 그 편지는 공유 바다에서 사라져요.'), findsOneWidget);
      expect(
        server.count('POST', '/api/letters/7/replies'),
        0,
        reason: '일반 답장 API가 아니다',
      );
    });

    testWidgets('보내기가 실패하면 입력이 남고, 이미 답장이 된 편지면 안내하고 닫는다', (tester) async {
      var gone = false;
      final server = await fished(
        tester,
        FakeServer()..on(
          'POST',
          '/api/shared-sea/letters/7/replies',
          handler: (_) => gone
              ? FakeServer.json({'message': 'x'}, status: 404)
              : FakeServer.json({'message': '서버 오류'}, status: 500),
        ),
      );
      await tester.enterText(find.byKey(const Key('reply-text')), '답장 본문');
      await tester.tap(find.byKey(const Key('reply-send')));
      await settle(tester, ms: 800);
      expect(find.textContaining('서버 오류'), findsOneWidget);
      expect(find.text('답장 본문'), findsOneWidget, reason: '입력 보존');

      gone = true;
      await tester.tap(find.byKey(const Key('reply-send')));
      await settle(tester, ms: 1000);
      expect(find.text('이미 답장이 된 편지예요.'), findsOneWidget);
      expect(find.byKey(const Key('reply-text')), findsNothing);
      expect(find.byKey(const Key('shared-fish')), findsOneWidget);
      expect(server.count('POST', '/api/shared-sea/letters/7/replies'), 2);
    });

    testWidgets('답장 화면에서 돌아가면 내용이 있을 때 버릴지 묻고, 계속 작성하면 그대로다', (tester) async {
      await fished(tester, FakeServer());
      await tester.enterText(find.byKey(const Key('reply-text')), '쓰던 답장');
      await systemBack(tester);
      expect(find.text('작성 중인 답장을 버릴까요?'), findsOneWidget);

      await tester.tap(find.text('계속 작성'));
      await settle(tester);
      expect(find.text('쓰던 답장'), findsOneWidget);

      await systemBack(tester);
      await tester.tap(find.text('버리기'));
      await settle(tester, ms: 800);
      expect(
        find.byKey(const Key('fished-heading')),
        findsOneWidget,
        reason: '낚은 편지로 돌아온다',
      );
    });
  });

  group('편지 띄우기', () {
    testWidgets('받는 사람·익명 선택 없이 내용만 적어 띄우면 서버에 보내고 안내한다', (tester) async {
      final server = FakeServer()
        ..on('POST', '/api/shared-sea/letters', body: {'id': 3}, status: 201);
      await openHome(tester, server);
      await toSharedSea(tester);

      await tester.tap(find.byKey(const Key('shared-write')));
      await settle(tester, ms: 800);
      expect(find.byKey(const Key('shared-write-note')), findsOneWidget);
      expect(find.byKey(const Key('write-search')), findsNothing);
      expect(find.byKey(const Key('write-anonymous')), findsNothing);

      await tester.tap(find.byKey(const Key('shared-write-send')));
      await settle(tester);
      expect(find.textContaining('편지 내용을 입력해주세요.'), findsOneWidget);
      expect(server.count('POST', '/api/shared-sea/letters'), 0);

      await tester.enterText(
        find.byKey(const Key('shared-write-content')),
        '아무나 읽어 주세요',
      );
      await tester.tap(find.byKey(const Key('shared-write-send')));
      await settle(tester, ms: 1000);

      expect(
        server.bodyOf(server.of('POST', '/api/shared-sea/letters').single),
        {'content': '아무나 읽어 주세요'},
      );
      expect(find.byKey(const Key('shared-write-content')), findsNothing);
      expect(find.text('공유 바다에 편지를 띄웠어요.'), findsOneWidget);
    });

    testWidgets('실패하면 입력이 남고 취소할 때 내용이 있으면 버릴지 묻는다', (tester) async {
      final server = FakeServer()
        ..on(
          'POST',
          '/api/shared-sea/letters',
          body: {'message': '서버 오류'},
          status: 500,
        );
      await openHome(tester, server);
      await toSharedSea(tester);
      await tester.tap(find.byKey(const Key('shared-write')));
      await settle(tester, ms: 800);

      await tester.enterText(
        find.byKey(const Key('shared-write-content')),
        '내용',
      );
      await tester.tap(find.byKey(const Key('shared-write-send')));
      await settle(tester, ms: 800);
      expect(find.textContaining('서버 오류'), findsOneWidget);
      expect(find.text('내용'), findsOneWidget);

      await tester.tap(find.byKey(const Key('shared-write-cancel')));
      await settle(tester);
      expect(find.text('작성 중인 편지를 버릴까요?'), findsOneWidget);
      await tester.tap(find.text('계속 작성'));
      await settle(tester);
      expect(find.byKey(const Key('shared-write-content')), findsOneWidget);
    });
  });

  group('익명 답장의 받는 사람 표시', () {
    test('받는 사람을 알려주지 않는 보낸 편지는 익명의 유리병으로 보인다', () {
      final item = SentItem.fromJson({
        'id': 5,
        'receiverUsername': null,
        'anonymous': false,
        'preview': '답장',
        'sentAt': '2026-11-10T09:00:00',
      });
      expect(item.receiverLabel, '익명의 유리병');

      final detail = DetailData.fromSentJson({
        'id': 5,
        'receiverUsername': null,
        'anonymous': false,
        'content': 'x',
        'sentAt': '2026-11-10T09:00:00',
      });
      expect(detail.heading, '익명의 유리병에 보낸 답장');

      final parent = DetailData.fromParentJson({
        'id': 9,
        'role': 'SENDER',
        'counterpartUsername': null,
        'anonymous': true,
        'content': '내가 띄운 편지',
        'sentAt': '2026-11-10T09:00:00',
        'parentLetterId': null,
      });
      expect(parent.heading, '공유 바다에 띄운 편지');
    });
  });
}
