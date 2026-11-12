import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:message_bottle_frontend/screens/login_screen.dart';
import 'package:message_bottle_frontend/screens/splash_screen.dart';

import 'support.dart';

const tokens = {
  'accessToken': 'a1',
  'refreshToken': 'r1',
  'tokenType': 'Bearer',
};

void main() {
  group('로그인', () {
    testWidgets('비어 있으면 입력 칸 아래에 안내하고 서버를 부르지 않는다', (tester) async {
      usePhone(tester);
      final server = FakeServer();
      await tester.pumpWidget(
        testApp(
          LoginScreen(services: await makeServices(server, loggedIn: false)),
        ),
      );
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await settle(tester);

      expect(find.text('아이디를 입력해주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해주세요.'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('로그인하면 토큰과 아이디를 저장하고 내 바다로 간다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('POST', '/api/auth/login', body: tokens)
        ..on('GET', '/api/sea/me', body: seaJson([5]));
      final services = await makeServices(server, loggedIn: false);
      await tester.pumpWidget(testApp(LoginScreen(services: services)));
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '아이디'),
        'Abc123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'Pass#word12*',
      );
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await settle(tester, ms: 1000);

      expect(server.bodyOf(server.of('POST', '/api/auth/login').single), {
        'username': 'Abc123',
        'password': 'Pass#word12*',
      });
      expect(await services.storage.readAccessToken(), 'a1');
      expect(await services.storage.readRefreshToken(), 'r1');
      expect(await services.storage.readUsername(), 'Abc123');
      expect(find.byKey(const Key('bottle-5')), findsOneWidget);
    });

    testWidgets('아이디나 비밀번호가 틀리면 서버 메시지를 보여주고 로그인 화면에 남는다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/auth/login',
          body: {'message': '아이디 또는 비밀번호가 올바르지 않습니다.'},
          status: 401,
        );
      await tester.pumpWidget(
        testApp(
          LoginScreen(services: await makeServices(server, loggedIn: false)),
        ),
      );
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '아이디'),
        'Abc123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'wrongpass1',
      );
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await settle(tester, ms: 1000);

      expect(find.textContaining('아이디 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    });

    testWidgets('서버에 닿지 못하면 연결 안내를 보여준다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/auth/login',
          handler: (_) => throw http.ClientException('연결 실패'),
        );
      await tester.pumpWidget(
        testApp(
          LoginScreen(services: await makeServices(server, loggedIn: false)),
        ),
      );
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, '아이디'),
        'Abc123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'Pass#word12*',
      );
      await tester.tap(find.widgetWithText(FilledButton, '로그인'));
      await settle(tester, ms: 1000);

      expect(find.textContaining('서버에 연결할 수 없습니다'), findsOneWidget);
    });
  });

  group('회원가입', () {
    Future<void> openSignUp(WidgetTester tester, FakeServer server) async {
      await tester.pumpWidget(
        testApp(
          LoginScreen(services: await makeServices(server, loggedIn: false)),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('계정이 없나요? 회원가입'));
      await settle(tester);
    }

    testWidgets('아이디·비밀번호 규칙에 맞지 않으면 서버를 부르지 않고 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer();
      await openSignUp(tester, server);

      await tester.enterText(find.widgetWithText(TextFormField, '아이디'), 'ab_');
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'short',
      );
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await settle(tester);

      expect(find.text('아이디는 영문, 숫자만 사용하여 4~20자로 입력해주세요.'), findsOneWidget);
      expect(
        find.text('비밀번호는 영문, 숫자, 특수기호만 사용하여 8~20자로 입력해주세요.'),
        findsOneWidget,
      );
      expect(server.requests, isEmpty);
    });

    testWidgets('이미 있는 아이디(409)는 아이디 칸 아래에 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/auth/signup',
          body: {'message': '이미 사용 중인 아이디입니다.'},
          status: 409,
        );
      await openSignUp(tester, server);

      await tester.enterText(
        find.widgetWithText(TextFormField, '아이디'),
        'Abc123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'Pass#word12*',
      );
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await settle(tester, ms: 1000);

      expect(find.text('이미 사용 중인 아이디입니다.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '가입하기'), findsOneWidget);
    });

    testWidgets('가입이 서버에서 확인되면 로그인 화면으로 돌아와 아이디를 채우고 안내한다(자동 로그인은 하지 않는다)', (
      tester,
    ) async {
      usePhone(tester);
      final server = FakeServer()..on('POST', '/api/auth/signup', status: 201);
      await openSignUp(tester, server);

      await tester.enterText(
        find.widgetWithText(TextFormField, '아이디'),
        'NewUser1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'Pass#word12*',
      );
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await settle(tester, ms: 1000);

      expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, '아이디'))
            .controller!
            .text,
        'NewUser1',
      );
      expect(find.text('가입이 완료되었습니다. 로그인해주세요.'), findsOneWidget);
      expect(server.count('POST', '/api/auth/login'), 0);
    });

    testWidgets('서버에 닿지 못하면 입력을 그대로 두고 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/auth/signup',
          handler: (_) => throw http.ClientException('연결 실패'),
        );
      await openSignUp(tester, server);

      await tester.enterText(
        find.widgetWithText(TextFormField, '아이디'),
        'NewUser1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호'),
        'Pass#word12*',
      );
      await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
      await settle(tester, ms: 1000);

      expect(find.textContaining('입력한 내용은 그대로 있어요'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, '아이디'))
            .controller!
            .text,
        'NewUser1',
      );
    });
  });

  group('스플래시', () {
    testWidgets('저장된 세션이 유효하면 바다로 간다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('POST', '/api/auth/refresh', body: tokens)
        ..on('GET', '/api/sea/me', body: seaJson([3]));
      await tester.pumpWidget(
        testApp(SplashScreen(services: await makeServices(server))),
      );
      await settle(tester, ms: 1000);

      expect(find.byKey(const Key('bottle-3')), findsOneWidget);
    });

    testWidgets('세션이 거부되거나 없으면 로그인 화면으로 간다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('POST', '/api/auth/refresh', body: {'message': '만료'}, status: 401);
      await tester.pumpWidget(
        testApp(SplashScreen(services: await makeServices(server))),
      );
      await settle(tester, ms: 1000);

      expect(find.text('계정이 없나요? 회원가입'), findsOneWidget);
    });

    testWidgets('서버에 닿지 못하면 로그아웃으로 처리하지 않고 다시 시도하게 한다', (tester) async {
      usePhone(tester);
      var down = true;
      final server = FakeServer()
        ..on(
          'POST',
          '/api/auth/refresh',
          handler: (_) => down
              ? throw http.ClientException('연결 실패')
              : FakeServer.json(tokens),
        )
        ..on('GET', '/api/sea/me', body: seaJson([]));
      final services = await makeServices(server);
      await tester.pumpWidget(testApp(SplashScreen(services: services)));
      await settle(tester, ms: 1000);

      expect(find.text('다시 시도'), findsOneWidget);
      expect(
        await services.storage.readRefreshToken(),
        'refresh',
        reason: '세션은 그대로',
      );

      down = false;
      await tester.tap(find.text('다시 시도'));
      await settle(tester, ms: 1000);
      expect(find.byKey(const Key('sea-write')), findsOneWidget);
    });
  });
}
