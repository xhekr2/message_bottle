import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';

import 'support.dart';

Map<String, dynamic> seaWith(String visibility, [List<int> ids = const []]) => {
  ...seaJson(ids),
  'visibility': visibility,
};

Future<FakeServer> openSea(WidgetTester tester, FakeServer server) async {
  await tester.pumpWidget(
    testApp(SeaScreen(services: await makeServices(server))),
  );
  await settle(tester);
  return server;
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('sea-menu')));
  await settle(tester);
}

void main() {
  testWidgets('비공개가 기본이고 서랍에서 공개 상태가 보인다', (tester) async {
    usePhone(tester);
    await openSea(
      tester,
      FakeServer()..on('GET', '/api/sea/me', body: seaWith('PRIVATE')),
    );
    await openDrawer(tester);

    expect(find.text('바다 비공개'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('바다 공개 중'), findsNothing);
  });

  testWidgets('이미 공개 중이면 공개 중으로 보인다', (tester) async {
    usePhone(tester);
    await openSea(
      tester,
      FakeServer()..on('GET', '/api/sea/me', body: seaWith('PUBLIC')),
    );
    await openDrawer(tester);

    expect(find.text('바다 공개 중'), findsOneWidget);
  });

  testWidgets('서버가 visibility를 주지 않으면(구버전 응답) 비공개로 본다', (tester) async {
    usePhone(tester);
    await openSea(
      tester,
      FakeServer()..on('GET', '/api/sea/me', body: seaJson([])),
    );
    await openDrawer(tester);

    expect(find.text('바다 비공개'), findsOneWidget);
  });

  testWidgets('설정 창에서 공개로 바꾸면 서버가 확인한 뒤에 화면이 바뀐다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on('GET', '/api/sea/me', body: seaWith('PRIVATE'))
      ..on(
        'PATCH',
        '/api/users/me/sea-visibility',
        body: {'visibility': 'PUBLIC'},
      );
    await openSea(tester, server);

    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('sea-visibility')));
    await settle(tester);
    expect(find.text('내 바다 공개'), findsOneWidget);
    expect(find.textContaining('지금은 비공개예요'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byKey(const Key('visibility-switch')));
    await settle(tester, ms: 1000);

    expect(
      server.bodyOf(server.of('PATCH', '/api/users/me/sea-visibility').single),
      {'visibility': 'PUBLIC'},
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.textContaining('지금은 공개 중이에요'), findsOneWidget);
    expect(find.textContaining('편지 내용은 볼 수 없어요'), findsOneWidget);
    expect(find.text('바다를 공개했어요.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('visibility-close')));
    await settle(tester);
    await openDrawer(tester);
    expect(find.text('바다 공개 중'), findsOneWidget, reason: '서랍의 상태도 바뀌었다');
    expect(find.text('바다 비공개'), findsNothing);
  });

  testWidgets('다시 비공개로 바꿀 수 있다', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on('GET', '/api/sea/me', body: seaWith('PUBLIC'))
      ..on(
        'PATCH',
        '/api/users/me/sea-visibility',
        body: {'visibility': 'PRIVATE'},
      );
    await openSea(tester, server);

    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('sea-visibility')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('visibility-switch')));
    await settle(tester, ms: 1000);
    await tester.tap(find.byKey(const Key('visibility-close')));
    await settle(tester);
    await openDrawer(tester);

    expect(
      server.bodyOf(server.of('PATCH', '/api/users/me/sea-visibility').single),
      {'visibility': 'PRIVATE'},
    );
    expect(find.text('바다 비공개'), findsOneWidget);
  });

  testWidgets('서버에서 바꾸지 못하면 설정은 그대로이고 안내한다(성공으로 보이지 않는다)', (tester) async {
    usePhone(tester);
    final server = FakeServer()
      ..on('GET', '/api/sea/me', body: seaWith('PRIVATE'))
      ..on(
        'PATCH',
        '/api/users/me/sea-visibility',
        body: {'message': '서버 오류'},
        status: 500,
      );
    await openSea(tester, server);

    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('sea-visibility')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('visibility-switch')));
    await settle(tester, ms: 1000);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.textContaining('서버 오류'), findsOneWidget);
    expect(find.text('바다를 공개했어요.'), findsNothing);

    await tester.tap(find.byKey(const Key('visibility-close')));
    await settle(tester);
    await openDrawer(tester);
    expect(find.text('바다 비공개'), findsOneWidget);
  });

  testWidgets('메뉴 버튼은 편지함 버튼과 겹치지 않고 누르기 쉬운 크기다', (tester) async {
    usePhone(tester);
    await openSea(
      tester,
      FakeServer()..on('GET', '/api/sea/me', body: seaWith('PUBLIC')),
    );

    final menu = tester.getRect(find.byKey(const Key('sea-menu')));
    final right = tester
        .getRect(find.byKey(const Key('sea-sent')))
        .expandToInclude(tester.getRect(find.byKey(const Key('sea-inbox'))));
    expect(menu.overlaps(right), isFalse);
    expect(menu.height, greaterThanOrEqualTo(48));
  });
}
