import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';
import 'package:message_bottle_frontend/sea_settings.dart';
import 'package:message_bottle_frontend/widgets/bottle_field.dart';
import 'package:message_bottle_frontend/widgets/sea_waves.dart';

import 'support.dart';

double _opacityOf(WidgetTester tester, Finder inside) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: inside, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  group('진행 파도', () {
    test('모든 상태에서 선이 꺾이거나 되감기지 않는다(가로로 계속 앞으로)', () {
      final clock = WaveClock(type: WaveType.rough);
      for (final mood in [0.0, 0.3, 0.7, 1.0]) {
        clock.mood = mood;
        for (var step = 0; step < 200; step++) {
          clock.advance(0.0001);
          for (var l = 0; l < WaveField.layerCount; l++) {
            final pts = WaveField.points(
              width: 390,
              height: 230,
              layer: l,
              phases: clock.phases,
              mood: mood,
            );
            for (var i = 1; i < pts.length; i++) {
              expect(pts[i].dx, greaterThan(pts[i - 1].dx));
            }
          }
          clock.phases.fillRange(0, clock.phases.length, step * 0.37);
        }
      }
    });

    test('마루가 오른쪽으로만 나아간다', () {
      // 가장 긴 파도의 마루(최고점)가 시간이 지나면 오른쪽으로 옮겨 간다.
      final clock = WaveClock(type: WaveType.calm);
      double crestX() {
        final pts = WaveField.points(
          width: 390,
          height: 230,
          layer: 2,
          phases: clock.phases,
          mood: 0,
        ).where((p) => p.dx > 60 && p.dx < 330).toList();
        return pts.reduce((a, b) => a.dy < b.dy ? a : b).dx;
      }

      var moved = 0;
      var x = crestX();
      for (var i = 0; i < 30; i++) {
        clock.advance(0.1);
        final next = crestX();
        if (next > x) moved++;
        expect(next - x, lessThan(120), reason: '한 번에 순간이동하지 않는다');
        x = next;
      }
      expect(moved, greaterThan(15));
    });

    test('거센 파도는 잔잔한 파도보다 높고 빠르다', () {
      double range(double mood) {
        final pts = WaveField.points(
          width: 390,
          height: 230,
          layer: 3,
          phases: List.filled(12, 0.5),
          mood: mood,
        );
        final ys = pts.map((p) => p.dy);
        return ys.reduce((a, b) => a > b ? a : b) -
            ys.reduce((a, b) => a < b ? a : b);
      }

      expect(range(1), greaterThan(range(0) * 2));
      expect(WaveField.speedFactor(1), greaterThan(WaveField.speedFactor(0)));
    });

    test('둘 다는 시간이 지나면 잔잔함과 거셈을 오가고, 잔잔·거센은 고정이다', () {
      final both = WaveClock();
      var lo = 1.0, hi = 0.0;
      for (var i = 0; i < 700; i++) {
        both.advance(0.1);
        lo = lo < both.mood ? lo : both.mood;
        hi = hi > both.mood ? hi : both.mood;
      }
      expect(lo, lessThan(0.15));
      expect(hi, greaterThan(0.85));

      final calm = WaveClock(type: WaveType.calm);
      final rough = WaveClock(type: WaveType.rough);
      for (var i = 0; i < 100; i++) {
        calm.advance(0.1);
        rough.advance(0.1);
      }
      expect(calm.mood, lessThan(0.01));
      expect(rough.mood, greaterThan(0.99));
    });
  });

  group('유리병 자리', () {
    test('남아 있는 병은 자리를 지키고 새 병은 빈 자리에 놓인다', () {
      var slots = assignSlots({}, [1, 2, 3]);
      expect(slots, {1: 0, 2: 1, 3: 2});
      slots = assignSlots(slots, [1, 3]);
      expect(slots, {1: 0, 3: 2});
      slots = assignSlots(slots, [1, 3, 9]);
      expect(slots, {1: 0, 3: 2, 9: 1});
    });

    test('사라지는 중인 자리는 쓰지 않는다', () {
      final slots = assignSlots({1: 0, 3: 2}, [1, 3, 9], reserved: {1});
      expect(slots, {1: 0, 3: 2, 9: 3}, reason: '예약된 1번 자리를 건너뛴다');
    });
  });

  group('서랍과 설정', () {
    testWidgets('서랍에 공개 설정·대기 시간·파도 종류·로그아웃이 모여 있다', (tester) async {
      usePhone(tester);
      final services = await makeServices(
        FakeServer()..on('GET', '/api/sea/me', body: seaJson([])),
      );
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester);
      expect(find.byKey(const Key('sea-logout')), findsNothing);

      await tester.tap(find.byKey(const Key('sea-menu')));
      await settle(tester);
      expect(find.byKey(const Key('sea-visibility')), findsOneWidget);
      expect(find.byKey(const Key('sea-logout')), findsOneWidget);
      expect(find.byKey(const Key('idle-slider')), findsOneWidget);
      expect(find.text('둘 다'), findsOneWidget);
      expect(find.text('잔잔'), findsOneWidget);
      expect(find.text('거센'), findsOneWidget);
      expect(find.text('5초'), findsOneWidget);
    });

    testWidgets('대기 시간은 1~10초이고 파도 종류를 바꾸면 서버에 저장된다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaJson([]))
        ..withSettings();
      final services = await makeServices(server);
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester);
      await tester.tap(find.byKey(const Key('sea-menu')));
      await settle(tester);

      final slider = tester.widget<Slider>(
        find.byKey(const Key('idle-slider')),
      );
      expect(slider.min, 1);
      expect(slider.max, 10);
      expect(slider.divisions, 9);

      await services.settings.setIdleSeconds(99);
      expect(services.settings.idleSeconds, 10);
      await services.settings.setIdleSeconds(0);
      expect(services.settings.idleSeconds, 1);
      await settle(tester, ms: 100);
      expect(find.text('1초'), findsWidgets);

      await tester.tap(find.byKey(const Key('wave-rough')));
      await settle(tester, ms: 200);
      expect(services.settings.waveType, WaveType.rough);

      expect(server.settings['idleSeconds'], 1);
      expect(server.settings['waveType'], 'ROUGH');
    });

    testWidgets('저장된 설정을 다시 불러온다', (tester) async {
      usePhone(tester);
      final services = await makeServices(
        FakeServer()
          ..on('GET', '/api/sea/me', body: seaJson([]))
          ..withSettings({
            'seaTone': 'DAY',
            'textStep': 1,
            'idleSeconds': 8,
            'waveType': 'CALM',
          }),
      );
      await services.settings.load();
      expect(services.settings.idleSeconds, 8);
      expect(services.settings.waveType, WaveType.calm);
    });
  });

  group('사라지는 효과', () {
    Future<FakeServer> twoBottles(
      WidgetTester tester,
      List<int> Function() ids,
    ) async {
      final server = FakeServer()
        ..on(
          'GET',
          '/api/sea/me',
          handler: (_) => FakeServer.json(seaJson(ids())),
        )
        ..on('GET', '/api/letters/1', body: letterJson(id: 1))
        ..on('POST', '/api/letters/1/discard', status: 204)
        ..on('POST', '/api/letters/1/archive', body: {'archiveId': 9});
      await tester.pumpWidget(
        testApp(SeaScreen(services: await makeServices(server))),
      );
      await settle(tester);
      return server;
    }

    testWidgets('X로 버리면 물결 효과가 나오고 남은 병은 제자리를 지킨다', (tester) async {
      usePhone(tester);
      var discarded = false;
      await twoBottles(tester, () => discarded ? [2, 3] : [1, 2]);
      final before = tester.getTopLeft(find.byKey(const Key('bottle-2')));

      await tester.tap(find.byKey(const Key('bottle-1')));
      await settle(tester);
      discarded = true;
      await tester.tap(find.byKey(const Key('detail-discard')));
      await settle(tester);
      await tester.tap(find.text('버리기'));
      await settle(tester, ms: 600);

      expect(find.byType(VanishEffect), findsOneWidget);
      expect(find.byKey(const Key('bottle-1')), findsNothing);
      // 새로 올라온 병(3)은 사라지는 자리를 피해 다른 빈 자리에 놓이고, 남은 병(2)은 움직이지 않는다.
      expect(find.byKey(const Key('bottle-3')), findsOneWidget);
      final after = tester.getTopLeft(find.byKey(const Key('bottle-2')));
      expect((after.dx - before.dx).abs(), lessThan(0.001));

      await settle(tester, ms: 3000);
      expect(find.byType(VanishEffect), findsNothing, reason: '효과는 끝나면 사라진다');
    });

    testWidgets('보관하면 효과 없이 사라진다', (tester) async {
      usePhone(tester);
      var archived = false;
      await twoBottles(tester, () => archived ? [2] : [1, 2]);

      await tester.tap(find.byKey(const Key('bottle-1')));
      await settle(tester);
      archived = true;
      await tester.tap(find.byKey(const Key('detail-archive')));
      await settle(tester, ms: 800);

      expect(find.byKey(const Key('bottle-1')), findsNothing);
      expect(find.byType(VanishEffect), findsNothing);
    });
  });

  group('UI 숨김', () {
    testWidgets('설정한 시간 동안 가만히 있으면 버튼이 숨고, 건드리면 다시 보인다', (tester) async {
      usePhone(tester);
      final services = await makeServices(
        FakeServer()..on('GET', '/api/sea/me', body: seaJson([1, 2])),
      );
      await services.settings.setIdleSeconds(2);
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester);
      expect(_opacityOf(tester, find.byKey(const Key('sea-sent'))), 1);

      await settle(tester, ms: 3500);
      expect(_opacityOf(tester, find.byKey(const Key('sea-sent'))), 0);
      expect(_opacityOf(tester, find.byKey(const Key('sea-write'))), 0);
      expect(
        find.byKey(const Key('bottle-1')),
        findsOneWidget,
        reason: '유리병은 그대로 보인다',
      );

      final gesture = await tester.startGesture(const Offset(200, 700));
      await gesture.up();
      await settle(tester, ms: 1200);
      expect(_opacityOf(tester, find.byKey(const Key('sea-sent'))), 1);
      await settle(tester, ms: 100);
    });

    testWidgets('빈 바다는 숨김 상태에서 안내도 사라진다', (tester) async {
      usePhone(tester);
      final services = await makeServices(
        FakeServer()..on('GET', '/api/sea/me', body: seaJson([])),
      );
      await services.settings.setIdleSeconds(1);
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester);
      expect(_opacityOf(tester, find.byKey(const Key('sea-empty'))), 1);

      await settle(tester, ms: 2500);
      expect(_opacityOf(tester, find.byKey(const Key('sea-empty'))), 0);
    });

    testWidgets('서랍이 열려 있는 동안은 숨기지 않는다', (tester) async {
      usePhone(tester);
      final services = await makeServices(
        FakeServer()..on('GET', '/api/sea/me', body: seaJson([])),
      );
      await services.settings.setIdleSeconds(1);
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester);
      await tester.tap(find.byKey(const Key('sea-menu')));
      await settle(tester, ms: 2500);
      expect(find.byKey(const Key('sea-logout')), findsOneWidget);
      expect(_opacityOf(tester, find.byKey(const Key('sea-sent'))), 1);
    });
  });
}
