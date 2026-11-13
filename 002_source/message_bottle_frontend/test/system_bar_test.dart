import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/home_screen.dart';
import 'package:message_bottle_frontend/widgets/bottle_field.dart';

import 'support.dart';

/// 화면 아래쪽에 시스템 내비게이션 바(뒤로 가기·홈 버튼)가 있는 기기.
/// 앱은 그 바 뒤까지 그려지므로, 누르는 것들은 바에 가려지지 않게 그 위에 있어야 한다.
const double navBar = 48;

void useNavBarPhone(WidgetTester tester) {
  usePhone(tester);
  final px = navBar * tester.view.devicePixelRatio;
  tester.view.padding = FakeViewPadding(bottom: px);
  tester.view.viewPadding = FakeViewPadding(bottom: px);
}

void main() {
  /// [finder]가 내비게이션 바 위에 온전히 보인다.
  void expectAboveNavBar(WidgetTester tester, Finder finder) {
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(finder, findsOneWidget);
    expect(
      tester.getBottomLeft(finder).dy,
      lessThanOrEqualTo(screen.height - navBar),
      reason: '$finder 가 내비게이션 바에 가려진다',
    );
  }

  Future<void> openHome(WidgetTester tester, {List<int>? slots}) async {
    useNavBarPhone(tester);
    final server = FakeServer()
      ..on(
        'GET',
        '/api/sea/me',
        body: {
          'floatingCount': (slots ?? [0]).length,
          'capacity': 10,
          'letters': [
            for (final (i, slot) in (slots ?? [0]).indexed)
              {...bottle(i + 1), 'slot': slot},
          ],
        },
      );
    await tester.pumpWidget(
      testApp(HomeScreen(services: await makeServices(server))),
    );
    await settle(tester, ms: 2000);
  }

  testWidgets('내 바다의 편지 쓰기 버튼과 유리병이 내비게이션 바에 가려지지 않는다', (tester) async {
    // 가장 아래쪽 자리들을 포함해 10곳을 채운다.
    await openHome(tester, slots: [for (var i = 1; i <= 10; i++) i]);
    expectAboveNavBar(tester, find.byKey(const Key('sea-write')));
    expect(BottleField.slots, hasLength(11));
    for (var id = 1; id <= 10; id++) {
      expectAboveNavBar(tester, find.byKey(Key('bottle-$id')));
    }
  });

  testWidgets('편지 쓰기 창의 취소·보내기 버튼이 내비게이션 바에 가려지지 않는다', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('sea-write')));
    await settle(tester, ms: 1000);
    expectAboveNavBar(tester, find.byKey(const Key('write-cancel')));
    expectAboveNavBar(tester, find.byKey(const Key('write-send')));
  });

  testWidgets('공유 바다의 낚기 버튼이 내비게이션 바에 가려지지 않는다', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('home-tab-1')));
    await settle(tester, ms: 1000);
    expectAboveNavBar(tester, find.byKey(const Key('shared-fish')));
  });

  testWidgets('편지 띄우기 창의 취소·띄우기 버튼이 내비게이션 바에 가려지지 않는다', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('home-tab-1')));
    await settle(tester, ms: 1000);
    await tester.tap(find.byKey(const Key('shared-write')));
    await settle(tester, ms: 1000);
    expectAboveNavBar(tester, find.byKey(const Key('shared-write-cancel')));
    expectAboveNavBar(tester, find.byKey(const Key('shared-write-send')));
  });
}
