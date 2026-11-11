import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';

import 'support.dart';

void main() {
  testWidgets('떠 있는 편지마다 유리병이 하나씩 보이고 편지함 버튼과 편지 쓰기 버튼이 있다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on('GET', '/api/sea/me', body: seaJson([1, 2, 3]));
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);

    for (final id in [1, 2, 3]) {
      expect(find.byKey(Key('bottle-$id')), findsOneWidget);
    }
    expect(find.text('보낸 편지함'), findsOneWidget);
    expect(find.text('받은 편지함'), findsOneWidget);
    expect(find.byKey(const Key('sea-write')), findsOneWidget);
    expect(find.byKey(const Key('sea-empty')), findsNothing);
  });

  testWidgets('유리병은 최대 10개까지만 그리고 서로 겹치지 않는다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/sea/me',
        body: seaJson(List.generate(12, (i) => i + 1)),
      );
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);

    final bottles = [
      for (var i = 1; i <= 12; i++) find.byKey(Key('bottle-$i')),
    ];
    expect(bottles.where((f) => f.evaluate().isNotEmpty).length, 10);

    final rects = [
      for (var i = 1; i <= 10; i++)
        tester.getRect(find.byKey(Key('bottle-$i'))),
    ];
    for (var a = 0; a < rects.length; a++) {
      for (var b = a + 1; b < rects.length; b++) {
        // 떠다니는 움직임(±5px)을 감안해 8px 여유를 두고도 겹치지 않아야 한다
        expect(
          rects[a].inflate(4).overlaps(rects[b].inflate(4)),
          isFalse,
          reason: 'bottle ${a + 1} vs ${b + 1}',
        );
      }
    }
    // 우상단 편지함 버튼과도 겹치지 않는다
    final chips = tester
        .getRect(find.byKey(const Key('sea-sent')))
        .expandToInclude(tester.getRect(find.byKey(const Key('sea-inbox'))));
    for (final r in rects) {
      expect(r.overlaps(chips), isFalse);
    }
  });

  testWidgets('편지가 없으면 빈 바다 안내를 보여준다', (tester) async {
    usePhone(tester);
    final server = FakeServer()..on('GET', '/api/sea/me', body: seaJson([]));
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);

    expect(find.byKey(const Key('sea-empty')), findsOneWidget);
    expect(find.text('아직 도착한 유리병이 없어요'), findsOneWidget);
  });

  testWidgets('읽기에 실패하면 안내와 다시 시도 버튼을 보여주고 다시 시도하면 불러온다', (tester) async {
    usePhone(tester);
    var fail = true;
    final server = FakeServer()
      ..on(
        'GET',
        '/api/sea/me',
        handler: (_) => fail
            ? FakeServer.json({'message': '서버 오류'}, status: 500)
            : FakeServer.json(seaJson([7])),
      );
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);

    expect(find.text('바다를 불러오지 못했습니다'), findsOneWidget);
    expect(find.byKey(const Key('bottle-7')), findsNothing);

    fail = false;
    await tester.tap(find.byKey(const Key('sea-retry')));
    await settle(tester);

    expect(find.byKey(const Key('bottle-7')), findsOneWidget);
    expect(find.text('바다를 불러오지 못했습니다'), findsNothing);
  });

  testWidgets('유리병을 누르면 편지를 열고, 보관하면 바다에서 사라진다', (tester) async {
    usePhone(tester);
    var archived = false;
    final server = FakeServer()
      ..on(
        'GET',
        '/api/sea/me',
        handler: (_) => FakeServer.json(seaJson(archived ? [2] : [1, 2])),
      )
      ..on('GET', '/api/letters/1', body: letterJson(id: 1))
      ..on(
        'POST',
        '/api/letters/1/archive',
        handler: (_) {
          archived = true;
          return FakeServer.json({'archiveId': 9}, status: 201);
        },
      );
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('bottle-1')));
    await settle(tester);
    expect(find.byKey(const Key('detail-heading')), findsOneWidget);
    expect(server.count('GET', '/api/letters/1'), 1);

    await tester.tap(find.byKey(const Key('detail-archive')));
    await settle(tester, ms: 1000);

    expect(server.count('POST', '/api/letters/1/archive'), 1);
    expect(find.byKey(const Key('detail-heading')), findsNothing);
    expect(find.byKey(const Key('bottle-1')), findsNothing);
    expect(find.byKey(const Key('bottle-2')), findsOneWidget);
    expect(find.text('받은 편지함에 보관했어요.'), findsOneWidget);
  });

  testWidgets('이미 사라진 편지를 열려고 하면 안내하고 바다를 다시 불러온다', (tester) async {
    usePhone(tester);
    var gone = false;
    final server = FakeServer()
      ..on(
        'GET',
        '/api/sea/me',
        handler: (_) => FakeServer.json(seaJson(gone ? [] : [1])),
      )
      ..on(
        'GET',
        '/api/letters/1',
        handler: (_) {
          gone = true;
          return FakeServer.json({
            'message': '이미 사라졌거나 존재하지 않는 편지입니다.',
          }, status: 404);
        },
      );
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('bottle-1')));
    await settle(tester);

    expect(find.text('이미 사라진 편지입니다.'), findsOneWidget);
    expect(find.byKey(const Key('bottle-1')), findsNothing);
    expect(find.byKey(const Key('detail-heading')), findsNothing);
  });

  testWidgets('편지를 열어 둔 동안에는 앱으로 돌아와도 바다를 다시 불러오지 않는다(열람 후 이탈 규칙)', (
    tester,
  ) async {
    usePhone(tester);
    final server = FakeServer()
      ..on('GET', '/api/sea/me', body: seaJson([1]))
      ..on('GET', '/api/letters/1', body: letterJson(id: 1));
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('bottle-1')));
    await settle(tester);
    final before = server.count('GET', '/api/sea/me');

    // 전화가 오거나 홈 버튼을 눌렀다가 돌아온 상황
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(server.count('GET', '/api/sea/me'), before);
    expect(
      find.byKey(const Key('detail-heading')),
      findsOneWidget,
      reason: '편지는 그대로 열려 있다',
    );
  });

  testWidgets('편지를 열지 않았을 때 앱으로 돌아오면 새 편지를 불러온다', (tester) async {
    usePhone(tester);
    var ids = [1];
    final server = FakeServer()
      ..on('GET', '/api/sea/me', handler: (_) => FakeServer.json(seaJson(ids)));
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);
    expect(find.byKey(const Key('bottle-2')), findsNothing);

    ids = [1, 2];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(find.byKey(const Key('bottle-2')), findsOneWidget);
  });

  testWidgets('로그아웃하면 서버에 알리고 로그인 화면으로 돌아간다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on('GET', '/api/sea/me', body: seaJson([]))
      ..on('POST', '/api/auth/logout', status: 204);
    final services = await makeServices(server);
    await tester.pumpWidget(testApp(SeaScreen(services: services)));
    await settle(tester);

    await tester.tap(find.byKey(const Key('sea-menu')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('sea-logout')));
    await settle(tester);
    await tester.tap(find.text('로그아웃').last);
    await settle(tester, ms: 1000);

    expect(server.count('POST', '/api/auth/logout'), 1);
    expect(await services.storage.readRefreshToken(), isNull);
    expect(find.text('계정이 없나요? 회원가입'), findsOneWidget);
  });
}
