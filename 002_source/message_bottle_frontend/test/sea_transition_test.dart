import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/home_screen.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';
import 'package:message_bottle_frontend/widgets/sea_waves.dart';

import 'support.dart';

void main() {
  testWidgets('내 바다와 공유 바다를 넘길 때 바다와 위쪽 표시는 제자리에 있고 버튼·유리병만 움직인다', (
    tester,
  ) async {
    usePhone(tester); // 400 x 850
    final server = FakeServer()..on('GET', '/api/sea/me', body: seaJson([1]));
    await tester.pumpWidget(
      testApp(HomeScreen(services: await makeServices(server))),
    );
    await settle(tester);

    Rect rectOf(String key, [int index = 0]) =>
        tester.getRect(find.byKey(Key(key)).at(index));
    final tabBefore = rectOf('home-tab-0');
    final chipBefore = rectOf('sea-sent');
    final bottleBefore = rectOf('bottle-1');

    // 옆으로 반쯤 끈 상태로 둔다.
    final gesture = await tester.startGesture(const Offset(300, 500));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    // 버튼과 유리병은 화면과 함께 옆으로 밀린다.
    final moved = chipBefore.left - rectOf('sea-sent').left;
    expect(moved, greaterThan(100));
    expect(
      bottleBefore.left - rectOf('bottle-1').left,
      closeTo(moved, 6),
      reason: '유리병도 같은 만큼 밀린다(떠다니는 움직임만큼의 차이는 허용)',
    );

    // 두 화면이 각자 그리는 위쪽 표시는 둘 다 처음 자리에 그대로 있다.
    expect(find.byKey(const Key('home-tab-0')), findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(rectOf('home-tab-0', i).left, closeTo(tabBefore.left, 0.5));
      expect(rectOf('home-tab-0', i).top, closeTo(tabBefore.top, 0.5));
    }

    // 두 화면은 같은 시계로 파도를 그리고, 각자 밀린 만큼을 되돌려 같은 자리에 그린다.
    final waves = tester.widgetList<SeaWaves>(find.byType(SeaWaves)).toList();
    expect(waves, hasLength(2));
    expect(identical(waves[0].clock, waves[1].clock), isTrue);
    expect(waves[0].shift!.value, closeTo(moved, 0.5));
    expect(waves[1].shift!.value, closeTo(moved - 400, 0.5));

    // 손을 떼면 공유 바다로 넘어가고, 표시는 여전히 같은 자리다.
    await gesture.up();
    await settle(tester, ms: 1000);
    expect(find.byKey(const Key('shared-write')).hitTestable(), findsOneWidget);
    // 이제 화면에 있는 것은 공유 바다 하나뿐이고, 제자리에 있으므로 되돌릴 값이 0이다.
    final shown = tester.widget<SeaWaves>(find.byType(SeaWaves));
    expect(shown.shift!.value, closeTo(0, 0.5));
    final visibleTab = find.byKey(const Key('home-tab-1')).hitTestable();
    expect(tester.getRect(visibleTab.first).top, closeTo(tabBefore.top, 0.5));

    // 위쪽 표시를 눌러 내 바다로 돌아올 수 있다.
    await tester.tap(find.byKey(const Key('home-tab-0')).hitTestable().first);
    await settle(tester, ms: 1000);
    expect(find.byKey(const Key('sea-sent')).hitTestable(), findsOneWidget);
    expect(rectOf('sea-sent').left, closeTo(chipBefore.left, 0.5));
  });

  testWidgets('바다 화면을 혼자 띄우면 자기 시계로 그리고 바다를 옮기지 않는다', (tester) async {
    usePhone(tester);
    final server = FakeServer()..on('GET', '/api/sea/me', body: seaJson([1]));
    await tester.pumpWidget(
      testApp(SeaScreen(services: await makeServices(server))),
    );
    await settle(tester);
    final waves = tester.widget<SeaWaves>(find.byType(SeaWaves));
    expect(waves.shift, isNull);
  });
}
