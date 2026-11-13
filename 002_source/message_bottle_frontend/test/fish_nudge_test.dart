import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';
import 'package:message_bottle_frontend/screens/visit_sea_screen.dart';
import 'package:message_bottle_frontend/widgets/bottle_field.dart';
import 'package:message_bottle_frontend/widgets/bottle_icon.dart';
import 'package:message_bottle_frontend/widgets/fish_nudge.dart';

import 'support.dart';

/// 서버가 자리를 함께 주는 내 바다 응답.
Map<String, dynamic> seaWithSlots(Map<int, int> slots) => {
  'floatingCount': slots.length,
  'capacity': 10,
  'letters': [
    for (final e in slots.entries) {...bottle(e.key), 'slot': e.value},
  ],
};

void main() {
  group('유리병 자리', () {
    test('자리는 11곳이고 서로 겹치지 않는다', () {
      const slots = BottleField.slots;
      expect(slots, hasLength(11));
      for (var a = 0; a < slots.length; a++) {
        for (var b = a + 1; b < slots.length; b++) {
          final ra = slots[a] & const Size(56, 100);
          final rb = slots[b] & const Size(56, 100);
          expect(ra.overlaps(rb), isFalse, reason: '$a번과 $b번 자리가 겹친다');
        }
      }
    });
  });

  group('밀치기 계산', () {
    test('민 방향 쪽 가까운 자리가 비어 있으면 그 자리로 한 번만 간다', () {
      // 0번(60,200)에서 오른쪽으로 밀면 가장 가까운 오른쪽 자리는 8번(150,180)이다.
      final moves = pushChain(
        start: 0,
        direction: const Offset(1, 0),
        occupied: {0},
      );
      expect(moves, [const SlotMove(0, 8)]);
    });

    test('가는 길에 유리병이 있으면 그 유리병을 밀치고, 밀려난 유리병도 다음 자리로 간다', () {
      final moves = pushChain(
        start: 0,
        direction: const Offset(1, 0),
        occupied: {0, 8},
      );
      expect(moves.first, const SlotMove(0, 8));
      expect(moves, hasLength(2));
      expect(moves[1].from, 8);
      expect({0, 8}.contains(moves[1].to), isFalse);
    });

    test('10개가 가득이어도 어느 유리병을 어느 쪽으로 밀든 빈자리에서 끝나고 겹치지 않는다', () {
      for (var empty = 0; empty < 11; empty++) {
        final occupied = {
          for (var i = 0; i < 11; i++)
            if (i != empty) i,
        };
        for (final start in occupied) {
          for (final dir in const [
            Offset(1, 0),
            Offset(-1, 0),
            Offset(0.95, 0.3),
            Offset(-0.95, -0.3),
          ]) {
            final moves = pushChain(
              start: start,
              direction: dir,
              occupied: occupied,
            );
            expect(moves, isNotEmpty);
            expect(moves.first.from, start);
            expect(moves.last.to, empty, reason: '마지막 유리병은 빈자리로 간다');
            for (var i = 1; i < moves.length; i++) {
              expect(moves[i].from, moves[i - 1].to, reason: '밀친 자리를 차지한다');
            }
            // 이동을 모두 적용한 뒤에도 유리병 10개가 서로 다른 자리에 있다.
            final after = {...occupied}..remove(start);
            after.add(empty);
            expect(after, hasLength(10));
            expect(moves.map((m) => m.to).toSet(), hasLength(moves.length));
          }
        }
      }
    });
  });

  group('내 바다의 물고기', () {
    testWidgets('유리병은 서버에 저장된 자리에 놓인다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaWithSlots({1: 3, 2: 10}));
      await tester.pumpWidget(
        testApp(SeaScreen(services: await makeServices(server))),
      );
      await settle(tester, ms: 2000);

      final g = BottleGeometry(tester.getSize(find.byType(BottleField)));
      final origin = tester.getTopLeft(find.byType(BottleField));
      Offset at(int id) =>
          tester.getTopLeft(
            find.byKey(ValueKey<Object>(('at', Key('bottle-$id')))),
          ) -
          origin;
      expect((at(1) - g.topLeft(3)).distance, lessThan(0.5));
      expect((at(2) - g.topLeft(10)).distance, lessThan(0.5));
    });

    testWidgets('20~40초 사이에 물고기가 지나가며 유리병을 밀고, 바뀐 자리를 서버에 저장한다', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaWithSlots({1: 0, 2: 8, 3: 5}))
        ..on('PUT', '/api/sea/me/slots', body: const <Object>[]);
      await tester.pumpWidget(
        testApp(
          SeaScreen(
            services: await makeServices(server),
            random: math.Random(7),
          ),
        ),
      );
      await settle(tester);

      // 20초 전에는 오지 않는다.
      for (var i = 0; i < 19; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('sea-fish')), findsNothing);
      // 40초 안에는 온다.
      for (var i = 0; i < 22; i++) {
        if (find.byKey(const Key('sea-fish')).evaluate().isNotEmpty) break;
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('sea-fish')), findsOneWidget);
      expect(server.count('PUT', '/api/sea/me/slots'), 0, reason: '아직 닿지 않았다');

      // 물고기가 지나가고 유리병이 새 자리에 멈출 때까지.
      await settle(tester, ms: 8000);
      expect(find.byKey(const Key('sea-fish')), findsNothing);
      expect(server.count('PUT', '/api/sea/me/slots'), 1);
      final sent =
          (server.bodyOf(server.of('PUT', '/api/sea/me/slots').single)['slots']
                  as List)
              .cast<Map<String, dynamic>>();
      expect(sent.map((e) => e['letterId']).toSet(), {1, 2, 3});
      final slots = sent.map((e) => e['slot'] as int).toList();
      expect(slots.toSet(), hasLength(3), reason: '서로 다른 자리');
      expect(slots.every((s) => s >= 0 && s <= 10), isTrue);
      expect(slots.toSet(), isNot({0, 8, 5}), reason: '적어도 한 병은 자리를 옮겼다');

      // 화면의 유리병도 보낸 자리에 있다.
      final g = BottleGeometry(tester.getSize(find.byType(BottleField)));
      final origin = tester.getTopLeft(find.byType(BottleField));
      for (final e in sent) {
        final at =
            tester.getTopLeft(
              find.byKey(
                ValueKey<Object>(('at', Key('bottle-${e['letterId']}'))),
              ),
            ) -
            origin;
        expect((at - g.topLeft(e['slot'] as int)).distance, lessThan(0.5));
      }
      // 밀린 뒤에도 유리병을 누를 수 있다.
      expect(find.byKey(const Key('bottle-1')).hitTestable(), findsOneWidget);
    });

    testWidgets('유리병이 없으면 물고기가 오지 않는다', (tester) async {
      usePhone(tester);
      final server = FakeServer()..on('GET', '/api/sea/me', body: seaJson([]));
      await tester.pumpWidget(
        testApp(
          SeaScreen(
            services: await makeServices(server),
            random: math.Random(7),
          ),
        ),
      );
      await settle(tester);
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('sea-fish')), findsNothing);
      }
      expect(server.count('PUT', '/api/sea/me/slots'), 0);
    });

    testWidgets('기기의 "움직임 줄이기"가 켜져 있으면 물고기가 오지 않는다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaWithSlots({1: 0}));
      final services = await makeServices(server);
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: SeaScreen(services: services, random: math.Random(7)),
            ),
          ),
        ),
      );
      await settle(tester);
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('sea-fish')), findsNothing);
      }
    });
  });

  group('다른 사람의 바다', () {
    testWidgets('유리병은 주인이 보는 자리(서버에 저장된 자리)에 놓인다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'GET',
          '/api/sea/users/Mina',
          body: {
            'username': 'Mina',
            'floatingCount': 2,
            'slots': [4, 10],
          },
        );
      await tester.pumpWidget(
        testApp(
          VisitSeaScreen(
            services: await makeServices(server),
            username: 'Mina',
          ),
        ),
      );
      await settle(tester, ms: 2000);

      final g = BottleGeometry(tester.getSize(find.byType(BottleField)));
      final origin = tester.getTopLeft(find.byType(BottleField));
      expect(find.byType(BottleIcon), findsNWidgets(2));
      Offset at(int i) =>
          tester.getTopLeft(find.byKey(ValueKey<Object>(('at', i)))) - origin;
      expect((at(0) - g.topLeft(4)).distance, lessThan(0.5));
      expect((at(1) - g.topLeft(10)).distance, lessThan(0.5));
    });
  });
}
