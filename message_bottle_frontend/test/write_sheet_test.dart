import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';

import 'support.dart';

Future<FakeServer> openSheet(WidgetTester tester, FakeServer server) async {
  server.on('GET', '/api/sea/me', body: seaJson([]));
  await tester.pumpWidget(
    testApp(SeaScreen(services: await makeServices(server))),
  );
  await settle(tester);
  await tester.tap(find.byKey(const Key('sea-write')));
  await settle(tester);
  return server;
}

Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('write-search')), text);
  await tester.pump();
}

void main() {
  testWidgets('받는 사람 검색은 글자를 칠 때마다 부르지 않고 입력이 1초간 멈추면 한 번만 부른다', (
    tester,
  ) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'abc123'},
          {'username': 'Abc123'},
        ],
      );
    await openSheet(tester, server);

    await typeSearch(tester, 'a');
    await tester.pump(const Duration(milliseconds: 300));
    await typeSearch(tester, 'ab');
    await tester.pump(const Duration(milliseconds: 300));
    await typeSearch(tester, 'abc');
    await tester.pump(const Duration(milliseconds: 900));

    expect(
      server.count('GET', '/api/users/search'),
      0,
      reason: '마지막 입력 후 1초가 지나기 전에는 검색하지 않는다',
    );
    expect(find.text('입력을 멈추면 검색해요…'), findsOneWidget);

    await settle(tester, ms: 400);

    final calls = server.of('GET', '/api/users/search').toList();
    expect(calls, hasLength(1));
    expect(calls.single.url.queryParameters['username'], 'abc');
    expect(find.byKey(const Key('result-abc123')), findsOneWidget);
    expect(find.byKey(const Key('result-Abc123')), findsOneWidget);
  });

  testWidgets('검색어를 지우면 결과도 지우고 검색하지 않는다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'Mina'},
        ],
      );
    await openSheet(tester, server);

    await typeSearch(tester, 'Mi');
    await settle(tester, ms: 1500);
    expect(find.byKey(const Key('result-Mina')), findsOneWidget);

    await typeSearch(tester, '');
    await settle(tester, ms: 1500);

    expect(find.byKey(const Key('result-Mina')), findsNothing);
    expect(server.count('GET', '/api/users/search'), 1);
  });

  testWidgets('결과 없음과 검색 실패(다시 시도)를 구분해서 안내한다', (tester) async {
    usePhone(tester);
    var fail = false;
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        handler: (_) => fail
            ? FakeServer.json({'message': '서버 오류'}, status: 500)
            : FakeServer.json([]),
      );
    await openSheet(tester, server);

    await typeSearch(tester, 'zzz');
    await settle(tester, ms: 1500);
    expect(find.byKey(const Key('result-zzz')), findsNothing);
    expect(find.text('일치하는 사용자가 없습니다.'), findsOneWidget);

    fail = true;
    await typeSearch(tester, 'zzzz');
    await settle(tester, ms: 1500);
    expect(find.text('검색하지 못했습니다. 다시 시도'), findsOneWidget);
    expect(find.text('일치하는 사용자가 없습니다.'), findsNothing);

    fail = false;
    await tester.tap(find.text('검색하지 못했습니다. 다시 시도'));
    await settle(tester);
    expect(find.text('검색하지 못했습니다. 다시 시도'), findsNothing);
  });

  testWidgets('나 자신은 선택할 수 없다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'Abc123'},
        ],
      );
    await openSheet(tester, server);

    await typeSearch(tester, 'Abc');
    await settle(tester, ms: 1500);
    expect(find.text('Abc123 (나)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('result-Abc123')));
    await settle(tester);

    expect(find.textContaining('나 자신에게는 보낼 수 없습니다.'), findsOneWidget);
    expect(find.byKey(const Key('write-chosen')), findsNothing);
  });

  testWidgets('받는 사람을 고르고 내용을 쓰면 서버에서 확인된 뒤에 닫히고 익명은 기본 꺼짐이다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'Mina'},
        ],
      )
      ..on('POST', '/api/letters', body: {'id': 1}, status: 201);
    await openSheet(tester, server);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('write-anonymous')))
          .value,
      isFalse,
    );

    await typeSearch(tester, 'Mi');
    await settle(tester, ms: 1500);
    await tester.tap(find.byKey(const Key('result-Mina')));
    await settle(tester);
    expect(find.text('Mina 님에게'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('write-content')), '안녕하세요');
    await tester.tap(find.byKey(const Key('write-send')));
    await settle(tester, ms: 1000);

    final body = server.bodyOf(server.of('POST', '/api/letters').single);
    expect(body, {
      'receiverUsername': 'Mina',
      'content': '안녕하세요',
      'anonymous': false,
    });
    expect(
      find.byKey(const Key('write-send')),
      findsNothing,
      reason: '시트가 닫혔다',
    );
    expect(find.text('보냈습니다. 보낸 편지함에서 확인할 수 있어요.'), findsOneWidget);
  });

  testWidgets('익명 스위치를 켜면 anonymous=true로 보낸다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'Mina'},
        ],
      )
      ..on('POST', '/api/letters', body: {'id': 1}, status: 201);
    await openSheet(tester, server);
    await typeSearch(tester, 'Mi');
    await settle(tester, ms: 1500);
    await tester.tap(find.byKey(const Key('result-Mina')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('write-content')), '비밀 편지');
    await tester.tap(find.byKey(const Key('write-anonymous')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('write-send')));
    await settle(tester, ms: 1000);

    expect(
      server.bodyOf(server.of('POST', '/api/letters').single)['anonymous'],
      isTrue,
    );
  });

  testWidgets('받는 사람이나 내용이 비어 있으면 항목 아래에 안내하고 보내지 않는다', (tester) async {
    usePhone(tester);
    final server = FakeServer();
    await openSheet(tester, server);

    await tester.tap(find.byKey(const Key('write-send')));
    await settle(tester);

    expect(find.textContaining('받는 사람을 선택해주세요.'), findsOneWidget);
    expect(find.textContaining('편지 내용을 입력해주세요.'), findsOneWidget);
    expect(server.count('POST', '/api/letters'), 0);

    await tester.enterText(find.byKey(const Key('write-content')), '   ');
    await tester.tap(find.byKey(const Key('write-send')));
    await settle(tester);
    expect(
      find.textContaining('편지 내용을 입력해주세요.'),
      findsOneWidget,
      reason: '공백만으로는 보낼 수 없다',
    );
  });

  testWidgets('보내기가 실패하면 입력이 그대로 남고 다시 시도할 수 있다', (tester) async {
    usePhone(tester);
    var fail = true;
    final server = FakeServer()
      ..on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'Mina'},
        ],
      )
      ..on(
        'POST',
        '/api/letters',
        handler: (_) => fail
            ? FakeServer.json({'message': '서버 오류'}, status: 500)
            : FakeServer.json({'id': 1}, status: 201),
      );
    await openSheet(tester, server);
    await typeSearch(tester, 'Mi');
    await settle(tester, ms: 1500);
    await tester.tap(find.byKey(const Key('result-Mina')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('write-content')),
      '꼭 보내야 하는 편지',
    );

    await tester.tap(find.byKey(const Key('write-send')));
    await settle(tester, ms: 1000);

    expect(find.textContaining('서버 오류'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('write-content')))
          .controller!
          .text,
      '꼭 보내야 하는 편지',
    );
    expect(find.text('Mina 님에게'), findsOneWidget);
    expect(find.text('보냈습니다. 보낸 편지함에서 확인할 수 있어요.'), findsNothing);

    fail = false;
    await tester.tap(find.byKey(const Key('write-send')));
    await settle(tester, ms: 1000);
    expect(find.byKey(const Key('write-send')), findsNothing);
    expect(server.count('POST', '/api/letters'), 2);
  });

  group('취소', () {
    testWidgets('입력이 없으면 바로 닫는다', (tester) async {
      usePhone(tester);
      await openSheet(tester, FakeServer());

      await tester.tap(find.byKey(const Key('write-cancel')));
      await settle(tester);

      expect(find.byKey(const Key('write-send')), findsNothing);
      expect(find.text('작성 중인 편지를 버릴까요?'), findsNothing);
    });

    testWidgets('입력이 있으면 폐기를 확인하고, 계속 작성을 고르면 입력이 남는다', (tester) async {
      usePhone(tester);
      await openSheet(tester, FakeServer());
      await tester.enterText(find.byKey(const Key('write-content')), '쓰던 편지');

      await tester.tap(find.byKey(const Key('write-cancel')));
      await settle(tester);
      expect(find.text('작성 중인 편지를 버릴까요?'), findsOneWidget);

      await tester.tap(find.text('계속 작성'));
      await settle(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('write-content')))
            .controller!
            .text,
        '쓰던 편지',
      );

      await tester.tap(find.byKey(const Key('write-cancel')));
      await settle(tester);
      await tester.tap(find.text('버리기'));
      await settle(tester);
      expect(find.byKey(const Key('write-send')), findsNothing);
    });

    testWidgets('Android 뒤로 가기도 취소와 같다', (tester) async {
      usePhone(tester);
      await openSheet(tester, FakeServer());

      await systemBack(tester); // 비어 있음 → 바로 닫힘
      expect(find.byKey(const Key('write-send')), findsNothing);

      await tester.tap(find.byKey(const Key('sea-write')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('write-content')), '내용');
      await systemBack(tester); // 내용 있음 → 폐기 확인
      expect(find.text('작성 중인 편지를 버릴까요?'), findsOneWidget);
      expect(find.byKey(const Key('write-send')), findsOneWidget);
    });
  });
}
