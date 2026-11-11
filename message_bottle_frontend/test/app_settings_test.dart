import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:message_bottle_frontend/app_services.dart';
import 'package:message_bottle_frontend/main.dart';
import 'package:message_bottle_frontend/screens/home_screen.dart';
import 'package:message_bottle_frontend/screens/login_screen.dart';
import 'package:message_bottle_frontend/screens/sea_screen.dart';
import 'package:message_bottle_frontend/sea_settings.dart';
import 'package:message_bottle_frontend/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

Map<String, dynamic> inboxItem(int id) => {
  'archiveId': id,
  'letterId': id + 100,
  'senderUsername': 'LongUserName12345678',
  'anonymous': false,
  'preview': '보관한 편지 $id 의 내용이 조금 길게 이어집니다',
  'sentAt': '2026-11-05T10:00:00',
  'archivedAt': '2026-11-06T10:00:00',
  'replied': id.isOdd,
};

FakeServer seaServer() => FakeServer()
  ..on('GET', '/api/sea/me', body: seaJson([1, 2, 3]))
  ..on('GET', '/api/letters/1', body: letterJson())
  ..on('GET', '/api/inbox', body: [inboxItem(1), inboxItem(2), inboxItem(3)])
  ..withSettings();

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('sea-menu')));
  await settle(tester, ms: 600);
}

void main() {
  group('바다 색감', () {
    testWidgets('설정에서 밤바다를 고르면 화면이 어두운 색으로 바뀌고 서버에 저장된다', (tester) async {
      usePhone(tester);
      final server = seaServer();
      final services = await makeServices(server);
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: SeaScreen(services: services),
        ),
      );
      await settle(tester);
      expect(AppColors.night, isFalse);
      expect(find.byKey(const Key('night-sky')), findsNothing);

      await openDrawer(tester);
      expect(find.byKey(const Key('tone-value')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tone-night')));
      await settle(tester, ms: 600);

      expect(AppColors.night, isTrue);
      expect(find.byKey(const Key('night-sky')), findsOneWidget);
      final context = tester.element(find.byKey(const Key('sea-drawer')));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        AppPalette.dark.background,
      );
      expect(server.settings['seaTone'], 'NIGHT');
      expect(
        (await SharedPreferences.getInstance()).getKeys(),
        isNot(contains('sea_tone')),
        reason: '기기에는 저장하지 않는다',
      );

      await tester.tap(find.byKey(const Key('tone-day')));
      await settle(tester, ms: 600);
      expect(AppColors.night, isFalse);
      expect(find.byKey(const Key('night-sky')), findsNothing);
      expect(server.settings['seaTone'], 'DAY');
    });

    testWidgets('기기 설정을 고르면 기기의 어두운 화면 설정을 따른다', (tester) async {
      usePhone(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final services = await makeServices(seaServer());
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: SeaScreen(services: services),
        ),
      );
      await settle(tester);
      expect(AppColors.night, isFalse, reason: '기본은 아침바다');

      await services.settings.setTone(SeaTone.system);
      await settle(tester, ms: 300);
      expect(AppColors.night, isTrue);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await settle(tester, ms: 300);
      expect(AppColors.night, isFalse);
    });

    testWidgets('서버에 저장해 둔 색감과 글자 크기를 불러온다', (tester) async {
      final server = FakeServer()
        ..withSettings({
          'seaTone': 'NIGHT',
          'textStep': 3,
          'idleSeconds': 8,
          'waveType': 'CALM',
        });
      final services = await makeServices(server);
      await services.settings.load();
      expect(services.settings.tone, SeaTone.night);
      expect(services.settings.textScale, 1.3);
      expect(services.settings.idleSeconds, 8);
      expect(services.settings.waveType, WaveType.calm);
    });

    testWidgets('서버에서 불러오지 못하면 기본값으로 둔다', (tester) async {
      final services = await makeServices(
        FakeServer()
          ..on('GET', settingsPath, status: 500, body: {'message': '오류'}),
      );
      await services.settings.load();
      expect(services.settings.tone, SeaTone.day);
      expect(services.settings.textScale, 1.0);
    });
  });

  group('글자 크기', () {
    testWidgets('설정의 글자 크기를 바꾸면 화면 글자 배율이 바뀌고 서버에 저장된다', (tester) async {
      usePhone(tester);
      final server = seaServer();
      final services = await makeServices(server);
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: SeaScreen(services: services),
        ),
      );
      await settle(tester);
      double scaleNow() => MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('sea-menu'))),
      ).scale(100);

      expect(scaleNow(), closeTo(100, 0.01));
      await openDrawer(tester);
      expect(find.text('보통 (100%)'), findsOneWidget);
      expect(find.byKey(const Key('text-scale-preview')), findsOneWidget);

      await services.settings.setTextStep(4);
      await settle(tester, ms: 300);
      expect(find.text('가장 크게 (140%)'), findsOneWidget);
      expect(scaleNow(), closeTo(140, 0.01));
      expect(server.settings['textStep'], 4);

      await services.settings.setTextStep(0);
      await settle(tester, ms: 300);
      expect(find.text('작게 (85%)'), findsOneWidget);
      expect(scaleNow(), closeTo(85, 0.01));
    });

    testWidgets('범위는 85%~140%이고 기기 글자 크기와 곱해도 140%를 넘지 않는다', (tester) async {
      expect(SeaSettings.textScales.first, 0.85);
      expect(SeaSettings.textScales.last, 1.4);
      usePhone(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final services = await makeServices(seaServer());
      await services.settings.setTextStep(4);
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: SeaScreen(services: services),
        ),
      );
      await settle(tester);
      final scale = MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('sea-menu'))),
      ).scale(100);
      expect(scale, closeTo(140, 0.01));
    });

    for (final step in [0, 4]) {
      testWidgets(
        '글자 크기 ${SeaSettings.textScales[step]}배, 폭 360에서도 화면이 넘치지 않는다',
        (tester) async {
          tester.view.physicalSize = const Size(720, 1480);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final services = await makeServices(seaServer());
          await services.settings.setTextStep(step);
          await tester.pumpWidget(
            MessageBottleApp(
              services: services,
              home: HomeScreen(services: services),
            ),
          );
          await settle(tester);

          // 서랍(설정)
          await openDrawer(tester);
          expect(find.byKey(const Key('sea-logout')), findsOneWidget);
          await tester.tapAt(const Offset(350, 400)); // 서랍 바깥을 눌러 닫는다
          await settle(tester, ms: 600);

          // 받은 편지함
          await tester.tap(find.byKey(const Key('sea-inbox')));
          await settle(tester);
          expect(find.text('받은 편지함'), findsWidgets);
          await tester.tap(find.byKey(const Key('mailbox-close')));
          await settle(tester, ms: 600);

          // 편지 쓰기
          await tester.tap(find.byKey(const Key('sea-write')));
          await settle(tester);
          expect(find.text('편지 쓰기'), findsWidgets);
          await systemBack(tester);

          // 편지 상세
          await tester.tap(find.byKey(const Key('bottle-1')));
          await settle(tester, ms: 1200);
          final reply = tester.getRect(find.byKey(const Key('detail-reply')));
          final archive = tester.getRect(
            find.byKey(const Key('detail-archive')),
          );
          if (step == 4) {
            expect(
              archive.top,
              greaterThanOrEqualTo(reply.bottom),
              reason: '글자가 크면 버튼을 위아래로 쌓는다',
            );
          } else {
            expect(
              archive.left,
              greaterThanOrEqualTo(reply.right),
              reason: '보통은 옆으로 나란히 둔다',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('가장 큰 글자에서도 로그인 화면이 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(720, 1480);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final services = await makeServices(FakeServer(), loggedIn: false);
      await services.settings.setTextStep(4);
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: LoginScreen(services: services),
        ),
      );
      await settle(tester);
      expect(find.text('로그인'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('스켈레톤', () {
    /// 응답하기 전에 [gate]()가 끝나기를 기다리는 가짜 서버.
    Future<AppServices> slowServices(Future<void> Function() gate) async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'username': 'Abc123',
      });
      final bodies = <String, Object>{
        '/api/sea/me': seaJson([1, 2, 3]),
        '/api/letters/1': letterJson(),
        '/api/inbox': [inboxItem(1), inboxItem(2), inboxItem(3)],
      };
      return AppServices.create(
        httpClient: MockClient((req) async {
          await gate();
          return FakeServer.json(bodies[req.url.path]);
        }),
      );
    }

    testWidgets('바다를 불러오는 동안 유리병 자리에 스켈레톤을 보여 주고, 다 불러오면 유리병으로 바뀐다', (
      tester,
    ) async {
      usePhone(tester);
      final hold = Completer<void>();
      final services = await slowServices(() => hold.future);
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester, ms: 300);
      expect(find.byKey(const Key('sea-skeleton')), findsOneWidget);
      expect(find.text('유리병을 찾고 있어요…'), findsOneWidget);
      expect(find.byKey(const Key('bottle-1')), findsNothing);

      hold.complete();
      await settle(tester);
      expect(find.byKey(const Key('sea-skeleton')), findsNothing);
      expect(find.byKey(const Key('bottle-1')), findsOneWidget);
    });

    testWidgets('편지와 편지함을 불러오는 동안 스켈레톤을 보여 준다', (tester) async {
      usePhone(tester);
      var hold = Completer<void>()..complete();
      final services = await slowServices(() => hold.future);
      await tester.pumpWidget(testApp(SeaScreen(services: services)));
      await settle(tester);

      // 받은 편지함 목록
      hold = Completer<void>();
      await tester.tap(find.byKey(const Key('sea-inbox')));
      await settle(tester, ms: 400);
      expect(find.byKey(const Key('list-skeleton')), findsOneWidget);
      hold.complete();
      await settle(tester);
      expect(find.byKey(const Key('list-skeleton')), findsNothing);
      expect(find.byKey(const ValueKey('inbox-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mailbox-close')));
      await settle(tester, ms: 600);

      // 유리병을 눌러 편지를 여는 동안
      hold = Completer<void>();
      await tester.tap(find.byKey(const Key('bottle-1')));
      await settle(tester, ms: 300);
      expect(find.byKey(const Key('letter-skeleton')), findsOneWidget);
      hold.complete();
      await settle(tester, ms: 1200);
      expect(find.byKey(const Key('letter-skeleton')), findsNothing);
      expect(find.byKey(const Key('detail-content')), findsOneWidget);
    });
  });

  group('사용자별 설정', () {
    testWidgets('한 사용자가 바꾼 설정이 같은 기기의 다른 사용자에게 따라가지 않는다', (tester) async {
      usePhone(tester);
      // 서버는 사용자(토큰)별로 설정을 따로 갖고 있다.
      final stored = <String, Map<String, dynamic>>{
        'Alice1': defaultSettingsJson(),
        'Bob123': defaultSettingsJson(),
      };
      var current = 'Alice1';
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaJson([]))
        ..on('POST', '/api/auth/logout', body: null, status: 204)
        ..on(
          'POST',
          '/api/auth/login',
          handler: (req) {
            current =
                (jsonDecode(utf8.decode(req.bodyBytes)) as Map)['username']
                    as String;
            return FakeServer.json({
              'accessToken': 'a-$current',
              'refreshToken': 'r-$current',
              'tokenType': 'Bearer',
            });
          },
        )
        ..on(
          'GET',
          settingsPath,
          handler: (_) => FakeServer.json(stored[current]),
        )
        ..on(
          'PUT',
          settingsPath,
          handler: (req) {
            stored[current] =
                jsonDecode(utf8.decode(req.bodyBytes)) as Map<String, dynamic>;
            return FakeServer.json(stored[current]);
          },
        );
      final services = await makeServices(server);
      await services.settings.load();
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: SeaScreen(services: services),
        ),
      );
      await settle(tester);

      // 앨리스가 밤바다와 가장 큰 글자로 바꾼다.
      await services.settings.setTone(SeaTone.night);
      await services.settings.setTextStep(4);
      await settle(tester, ms: 300);
      expect(AppColors.night, isTrue);
      expect(stored['Alice1']!['seaTone'], 'NIGHT');
      expect(stored['Alice1']!['textStep'], 4);
      expect(stored['Bob123'], defaultSettingsJson(), reason: '밥의 설정은 그대로다');

      // 로그아웃하면 로그인 화면은 기본값으로 돌아간다.
      await openDrawer(tester);
      await tester.tap(find.byKey(const Key('sea-logout')));
      await settle(tester, ms: 600);
      await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
      await settle(tester, ms: 1000);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(AppColors.night, isFalse);
      expect(services.settings.textScale, 1.0);

      // 밥이 로그인하면 밥의 설정(기본값)이 적용된다.
      await tester.enterText(find.byType(TextFormField).at(0), 'Bob123');
      await tester.enterText(find.byType(TextFormField).at(1), 'password1!');
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await settle(tester, ms: 1200);
      expect(find.byKey(const Key('sea-menu')), findsOneWidget);
      expect(AppColors.night, isFalse);
      expect(services.settings.textScale, 1.0);

      // 밥이 바꿔도 앨리스의 설정은 그대로다.
      await services.settings.setTextStep(0);
      await settle(tester, ms: 300);
      expect(stored['Bob123']!['textStep'], 0);
      expect(stored['Alice1']!['textStep'], 4);
      expect(stored['Alice1']!['seaTone'], 'NIGHT');
    });

    testWidgets('서버에 저장하지 못하면 안내를 보여 준다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('GET', '/api/sea/me', body: seaJson([]))
        ..on('GET', settingsPath, body: defaultSettingsJson())
        ..on('PUT', settingsPath, status: 500, body: {'message': '서버 오류'});
      final services = await makeServices(server);
      await tester.pumpWidget(
        MessageBottleApp(
          services: services,
          home: SeaScreen(services: services),
        ),
      );
      await settle(tester);
      await services.settings.setTone(SeaTone.night);
      await settle(tester, ms: 300);
      expect(find.textContaining('설정을 서버에 저장하지 못했어요'), findsOneWidget);
    });

    testWidgets('설정을 연달아 바꿔도 요청이 겹치지 않고 마지막 값이 서버에 남는다', (tester) async {
      final server = FakeServer()..withSettings();
      final services = await makeServices(server);
      for (var step = 0; step <= 4; step++) {
        services.settings.setTextStep(step);
      }
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.settings['textStep'], 4);
      expect(server.count('PUT', settingsPath), lessThanOrEqualTo(2));
    });
  });
}
