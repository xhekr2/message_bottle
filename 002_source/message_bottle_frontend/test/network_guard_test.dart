import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/app_services.dart';
import 'package:message_bottle_frontend/main.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

void main() {
  late bool offline;
  late int exits;

  Future<AppServices> pumpApp(WidgetTester tester, FakeServer server) async {
    usePhone(tester);
    offline = false;
    exits = 0;
    SharedPreferences.setMockInitialValues({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'username': 'Abc123',
    });
    final services = AppServices.create(
      httpClient: server.client,
      offlineProbe: () async => offline,
      exitApp: () => exits++,
    );
    await tester.pumpWidget(
      MessageBottleApp(
        services: services,
        home: SeaScreen(services: services),
      ),
    );
    await settle(tester);
    return services;
  }

  FakeServer server() => FakeServer()
    ..on('GET', '/api/sea/me', body: seaJson([1]))
    ..on('GET', '/api/letters/1', body: letterJson());

  testWidgets('네트워크가 연결돼 있는 동안에는 안내가 뜨지 않는다', (tester) async {
    await pumpApp(tester, server());
    await settle(tester, ms: 7000);
    expect(find.byKey(const Key('offline-dialog')), findsNothing);
    expect(exits, 0);
  });

  testWidgets('네트워크가 끊기면 안내 창이 뜨고 확인을 누르면 앱을 종료한다', (tester) async {
    await pumpApp(tester, server());
    offline = true;
    await settle(tester, ms: 3500);

    expect(find.byKey(const Key('offline-dialog')), findsOneWidget);
    expect(find.text('네트워크에 연결할 수 없어요'), findsOneWidget);
    expect(find.byKey(const Key('offline-retry')), findsNothing);
    expect(exits, 0, reason: '확인을 누르기 전에는 종료하지 않는다');

    // 바깥을 누르거나 뒤로 가기를 해도 닫히지 않는다.
    await tester.tapAt(const Offset(10, 10));
    await systemBack(tester);
    expect(find.byKey(const Key('offline-dialog')), findsOneWidget);
    // 안내가 떠 있는 동안 다시 확인해도 창이 겹쳐 뜨지 않는다.
    await settle(tester, ms: 7000);
    expect(find.byKey(const Key('offline-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('offline-exit')));
    await settle(tester, ms: 200);
    expect(exits, 1);
  });

  testWidgets('편지를 열어 둔 동안 끊기면 종료하지 않고 다시 시도하게 한다', (tester) async {
    await pumpApp(tester, server());
    await tester.tap(find.byKey(const Key('bottle-1')));
    await settle(tester, ms: 1200);
    expect(find.byKey(const Key('detail-content')), findsOneWidget);

    offline = true;
    await settle(tester, ms: 3500);
    expect(find.byKey(const Key('offline-dialog')), findsOneWidget);
    expect(find.byKey(const Key('offline-exit')), findsNothing);
    expect(find.textContaining('열어 둔 편지는 그대로 있어요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('offline-retry')));
    await settle(tester, ms: 300);
    expect(find.byKey(const Key('offline-still')), findsOneWidget);
    expect(find.byKey(const Key('offline-dialog')), findsOneWidget);

    offline = false;
    await tester.tap(find.byKey(const Key('offline-retry')));
    await settle(tester, ms: 600);
    expect(find.byKey(const Key('offline-dialog')), findsNothing);
    expect(
      find.byKey(const Key('detail-content')),
      findsOneWidget,
      reason: '편지는 그대로 열려 있다',
    );
    expect(exits, 0);
  });

  testWidgets('편지를 열어 둔 동안 연결이 돌아오면 안내 창이 저절로 닫힌다', (tester) async {
    await pumpApp(tester, server());
    await tester.tap(find.byKey(const Key('bottle-1')));
    await settle(tester, ms: 1200);

    offline = true;
    await settle(tester, ms: 3500);
    expect(find.byKey(const Key('offline-retry')), findsOneWidget);

    offline = false;
    await settle(tester, ms: 4000);
    expect(find.byKey(const Key('offline-dialog')), findsNothing);
    expect(find.byKey(const Key('detail-content')), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('서버에 닿지 못한 요청이 있으면 기다리지 않고 바로 네트워크를 확인한다', (tester) async {
    final services = await pumpApp(tester, server());
    offline = true;
    services.client.onNetworkError?.call();
    await settle(tester, ms: 300);
    expect(find.byKey(const Key('offline-dialog')), findsOneWidget);
  });
}
