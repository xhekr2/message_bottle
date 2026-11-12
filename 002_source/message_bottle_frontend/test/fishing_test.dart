import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/home_screen.dart';
import 'package:message_bottle_frontend/widgets/fishing_rig.dart';
import 'package:message_bottle_frontend/widgets/sea_waves.dart';

import 'support.dart';

Future<FakeServer> openSharedSea(WidgetTester tester, FakeServer server) async {
  usePhone(tester);
  server.on('GET', '/api/sea/me', body: seaJson([1]));
  await tester.pumpWidget(
    testApp(HomeScreen(services: await makeServices(server))),
  );
  await settle(tester);
  await tester.tap(find.byKey(const Key('home-tab-1')));
  await settle(tester, ms: 1000);
  return server;
}

final fishButton = find.byKey(const Key('shared-fish'));
final writeChip = find.byKey(const Key('shared-write'));

/// 공유 바다 화면에 있는 위쪽 표시(내 바다 화면에도 같은 표시가 하나 더 있다).
final sharedTab = find.byKey(const Key('home-tab-1')).last;

double opacityAround(WidgetTester tester, Finder child) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: child, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  group('낚싯줄의 진행 순서', () {
    FishingRig rig() => FishingRig(WaveClock());

    void run(FishingRig r, double seconds) {
      for (var t = 0.0; t < seconds; t += 0.05) {
        r.advance(0.05);
      }
    }

    test('던진 뒤에는 서버의 답이 올 때까지 계속 기다린다', () {
      final r = rig()..start();
      expect(r.phase, FishingPhase.cast);
      expect(r.status.value, '낚는 중…');
      run(r, 0.6);
      expect(r.phase, FishingPhase.wait);
      run(r, 10);
      expect(r.phase, FishingPhase.wait, reason: '답이 없으면 찌가 계속 떠 있다');
      r.dispose();
    });

    test('편지가 낚이면 입질 → 끌어올리기 → 매달림 순서로 가고 매달렸을 때 끝난다', () async {
      final r = rig()..start();
      var done = false;
      r.finish(caught: true).then((_) => done = true);

      run(r, 0.6);
      expect(r.phase, FishingPhase.wait, reason: '답이 빨라도 찌를 잠깐은 보여 준다');
      run(r, 0.4);
      expect(r.phase, FishingPhase.wait);
      run(r, 0.7);
      expect(r.phase, FishingPhase.bite);
      expect(r.status.value, '뭔가 걸렸어요!');
      run(r, 0.5);
      expect(r.phase, FishingPhase.reel);
      expect(r.status.value, '');
      await Future<void>.value();
      expect(done, isFalse);
      run(r, 1.5);
      expect(r.phase, FishingPhase.held);
      await Future<void>.value();
      expect(done, isTrue);

      run(r, 5);
      expect(r.phase, FishingPhase.held, reason: '치울 때까지 매달려 있다');
      r.reset();
      expect(r.phase, FishingPhase.idle);
      r.dispose();
    });

    test('낚인 것이 없으면 입질 없이 빈 바늘이 올라오고 줄이 사라진 뒤에 끝난다', () async {
      final r = rig()..start();
      var done = false;
      r.finish(caught: false).then((_) => done = true);

      final seen = <FishingPhase>{};
      for (var t = 0.0; t < 2.6; t += 0.05) {
        r.advance(0.05);
        seen.add(r.phase);
        await Future<void>.value();
        if (r.phase != FishingPhase.idle) expect(done, isFalse);
      }
      run(r, 0.4);
      await Future<void>.value();
      expect(seen, isNot(contains(FishingPhase.bite)));
      expect(seen, isNot(contains(FishingPhase.held)));
      expect(seen, contains(FishingPhase.retract));
      expect(r.phase, FishingPhase.idle);
      expect(done, isTrue);
      r.dispose();
    });

    test('도중에 치워도 기다리던 쪽이 멈추지 않는다', () async {
      final r = rig()..start();
      var done = false;
      r.finish(caught: true).then((_) => done = true);
      r.reset();
      await Future<void>.value();
      expect(done, isTrue);
      expect(r.status.value, '');
      r.dispose();
    });
  });

  group('유리병 낚기 화면', () {
    testWidgets('누르면 버튼이 빠지고 낚는 중 안내가 나오며, 응답이 빨라도 움직임이 끝난 뒤에 편지가 열린다', (
      tester,
    ) async {
      final server = await openSharedSea(
        tester,
        FakeServer()..on(
          'POST',
          '/api/shared-sea/fish',
          body: {
            'id': 7,
            'content': '바다 건너의 이야기',
            'sentAt': '2026-11-10T09:00:00',
          },
        ),
      );
      expect(opacityAround(tester, fishButton), 1);
      expect(opacityAround(tester, find.byKey(const Key('shared-title'))), 1);

      await tester.tap(fishButton);
      await settle(tester, ms: 1000);
      expect(opacityAround(tester, fishButton), 0, reason: '버튼이 빠진다');
      expect(
        opacityAround(tester, find.byKey(const Key('shared-title'))),
        0,
        reason: '가운데 안내도 치운다',
      );
      expect(find.text('낚는 중…'), findsOneWidget);
      expect(find.byKey(const Key('fished-heading')), findsNothing);

      // 빠진 버튼은 눌리지 않는다.
      await tester.tap(fishButton, warnIfMissed: false);
      await settle(tester, ms: 600);
      expect(server.count('POST', '/api/shared-sea/fish'), 1);
      expect(find.text('뭔가 걸렸어요!'), findsOneWidget);
      expect(find.byKey(const Key('fished-heading')), findsNothing);

      // 유리병이 올라와도 누르기 전에는 편지가 열리지 않는다.
      await settle(tester, ms: 2600);
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      expect(find.text('유리병을 눌러 열어 보세요'), findsOneWidget);
      await settle(tester, ms: 5000);
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      // 낚는 동안에는 위쪽 표시와 편지 띄우기도 숨는다.
      expect(opacityAround(tester, sharedTab), 0);
      expect(opacityAround(tester, writeChip), 0);
      await tester.tap(sharedTab, warnIfMissed: false);
      await tester.tap(writeChip, warnIfMissed: false);
      await settle(tester, ms: 600);
      expect(find.byKey(const Key('shared-write-content')), findsNothing);
      expect(find.byKey(const Key('shared-title')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fished-bottle')));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('fished-heading')), findsOneWidget);
      expect(find.text('유리병을 눌러 열어 보세요'), findsNothing);
      expect(find.text('바다 건너의 이야기'), findsOneWidget);

      // 닫으면 버튼과 안내가 돌아온다.
      await tester.tap(find.byKey(const Key('fished-close')));
      await settle(tester, ms: 800);
      expect(opacityAround(tester, fishButton), 1);
      expect(opacityAround(tester, find.byKey(const Key('shared-title'))), 1);
      expect(find.text('낚는 중…'), findsNothing);
      expect(find.text('뭔가 걸렸어요!'), findsNothing);
    });

    testWidgets('남은 편지가 없으면 빈 바늘이 올라온 뒤에 안내하고 버튼이 돌아온다', (tester) async {
      final server = await openSharedSea(
        tester,
        FakeServer()..on(
          'POST',
          '/api/shared-sea/fish',
          body: {'message': '남아있는 편지가 없어요!'},
          status: 404,
        ),
      );

      await tester.tap(fishButton);
      await settle(tester, ms: 1800);
      expect(find.text('남아있는 편지가 없어요!'), findsNothing, reason: '줄을 거둔 뒤에 알린다');
      expect(find.text('뭔가 걸렸어요!'), findsNothing, reason: '입질이 없다');
      expect(opacityAround(tester, fishButton), 0);

      await settle(tester, ms: 1400);
      expect(find.text('남아있는 편지가 없어요!'), findsOneWidget);
      expect(opacityAround(tester, fishButton), 1);

      // 버튼이 안내 위로 올라와 자리를 잡은 뒤에 다시 누른다.
      await settle(tester, ms: 400);
      await tester.tap(fishButton);
      await settle(tester, ms: 3200);
      expect(
        server.count('POST', '/api/shared-sea/fish'),
        2,
        reason: '다시 낚을 수 있다',
      );
    });

    testWidgets('서버 오류면 빈 바늘이 올라온 뒤에 오류를 알리고 버튼이 돌아온다', (tester) async {
      await openSharedSea(
        tester,
        FakeServer()..on(
          'POST',
          '/api/shared-sea/fish',
          body: {'message': '서버 오류'},
          status: 500,
        ),
      );
      await tester.tap(fishButton);
      await settle(tester, ms: 3200);
      expect(find.textContaining('서버 오류'), findsOneWidget);
      expect(find.byKey(const Key('fished-heading')), findsNothing);
      expect(opacityAround(tester, fishButton), 1);
    });

    testWidgets('기기에서 애니메이션 줄이기를 켰으면 움직임 없이 바로 편지를 연다', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openSharedSea(
        tester,
        FakeServer()..on(
          'POST',
          '/api/shared-sea/fish',
          body: {
            'id': 7,
            'content': '바다 건너의 이야기',
            'sentAt': '2026-11-10T09:00:00',
          },
        ),
      );
      await tester.tap(fishButton);
      await settle(tester, ms: 800);
      expect(find.byKey(const Key('fished-heading')), findsOneWidget);
    });
  });
}
