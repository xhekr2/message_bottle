import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/home_screen.dart';

import 'support.dart';

void main() {
  for (final width in [360.0, 400.0]) {
    testWidgets('폭 $width: 위쪽 표시와 버튼이 겹치지 않고, 편지함 버튼과 편지 띄우기가 같은 높이에서 시작한다', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 2, 1700);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final server = FakeServer()..on('GET', '/api/sea/me', body: seaJson([1]));
      await tester.pumpWidget(
        testApp(HomeScreen(services: await makeServices(server))),
      );
      await settle(tester);

      Rect rectOf(String key) => tester.getRect(find.byKey(Key(key)).last);
      final tabs = rectOf('home-tab-0').expandToInclude(rectOf('home-tab-1'));
      final sent = rectOf('sea-sent');
      final inbox = rectOf('sea-inbox');
      expect(tabs.overlaps(sent), isFalse);
      expect(tabs.overlaps(inbox), isFalse);
      expect(tabs.overlaps(rectOf('sea-menu')), isFalse);
      expect(sent.top, greaterThanOrEqualTo(tabs.bottom));
      expect(inbox.top, greaterThan(sent.bottom), reason: '보낸 편지함 아래에 받은 편지함');

      await tester.tap(find.byKey(const Key('home-tab-1')).first);
      await settle(tester, ms: 1000);
      final sharedTabs = rectOf('home-tab-0')
          .expandToInclude(rectOf('home-tab-1'));
      final write = rectOf('shared-write');
      expect(sharedTabs.overlaps(write), isFalse);
      expect(write.top, sent.top, reason: '내 바다의 편지함 버튼과 같은 높이');
      expect(write.right, sent.right);
    });
  }
}
