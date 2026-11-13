import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/config.dart';
import 'package:message_bottle_frontend/network_guard.dart';
import 'package:message_bottle_frontend/screens/login_screen.dart';

import 'support.dart';

/// iOS에서도 앱이 돌아가는 데 필요한 설정과 동작.
/// 실제 iOS 빌드(Xcode)는 Mac에서만 할 수 있어 여기서는 설정 파일과 Dart 쪽 동작을 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('서버 주소', () {
    test('Android 에뮬레이터는 10.0.2.2, iOS 시뮬레이터는 localhost가 기본이다', () {
      expect(defaultApiBaseUrl(TargetPlatform.android), 'http://10.0.2.2:8080');
      expect(defaultApiBaseUrl(TargetPlatform.iOS), 'http://localhost:8080');
    });

    test('기기에 따라 기본 주소가 바뀐다', () {
      const given = String.fromEnvironment('API_BASE_URL');
      if (given.isNotEmpty) {
        expect(apiBaseUrl, given);
        return;
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(apiBaseUrl, 'http://localhost:8080');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(apiBaseUrl, 'http://10.0.2.2:8080');
    });
  });

  group('iOS 프로젝트 설정', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    /// plist에서 [key] 바로 다음에 오는 값(태그 포함)을 돌려준다.
    String valueAfter(String source, String key) {
      final at = source.indexOf('<key>$key</key>');
      expect(at, isNonNegative, reason: '$key 가 Info.plist에 없다');
      return source.substring(at + '<key>$key</key>'.length).trimLeft();
    }

    test('Info.plist의 태그가 짝이 맞는다', () {
      for (final tag in ['dict', 'array', 'string', 'key']) {
        expect(
          '<$tag>'.allMatches(plist).length,
          '</$tag>'.allMatches(plist).length,
          reason: '<$tag>',
        );
      }
    });

    test('평문 HTTP 서버에 접속할 수 있다 (Android의 usesCleartextTraffic과 같다)', () {
      final ats = valueAfter(plist, 'NSAppTransportSecurity');
      expect(ats, startsWith('<dict>'));
      final dict = ats.substring(0, ats.indexOf('</dict>'));
      expect(valueAfter(dict, 'NSAllowsArbitraryLoads'), startsWith('<true/>'));
      expect(
        valueAfter(dict, 'NSAllowsLocalNetworking'),
        startsWith('<true/>'),
      );
    });

    test('같은 LAN의 서버에 접속할 때 보여 줄 안내 문구가 있다', () {
      expect(
        valueAfter(plist, 'NSLocalNetworkUsageDescription'),
        matches(RegExp(r'^<string>.+</string>')),
      );
    });

    test('네트워크 확인 통로의 이름이 앱·Android·iOS에서 같다', () {
      const name = 'message_bottle/network';
      expect(File('lib/network_guard.dart').readAsStringSync(), contains(name));
      expect(
        File(
          'android/app/src/main/kotlin/com/example/message_bottle_frontend/MainActivity.kt',
        ).readAsStringSync(),
        contains(name),
      );
      expect(appDelegate, contains('"$name"'));
      expect(appDelegate, contains('"isOnline"'));
    });

    test('Swift 파일이 모두 Xcode 프로젝트에 들어 있다', () {
      for (final file in Directory('ios/Runner').listSync()) {
        final name = file.uri.pathSegments.last;
        if (!name.endsWith('.swift')) continue;
        expect(project, contains('$name in Sources'), reason: name);
      }
    });
  });

  group('iOS에서의 동작', () {
    const channel = MethodChannel('message_bottle/network');
    void answer(Object? Function(MethodCall call)? handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            handler == null ? null : (call) async => handler(call),
          );
    }

    tearDown(() => answer(null));

    test('기기가 알려 준 연결 상태를 그대로 쓴다', () async {
      final asked = <String>[];
      answer((call) {
        asked.add(call.method);
        return false;
      });
      expect(await deviceOffline(), isTrue);
      answer((call) => true);
      expect(await deviceOffline(), isFalse);
      expect(asked, ['isOnline']);
    });

    test('iOS에서는 앱을 스스로 종료하지 않는다', () {
      expect(canExitApp, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(canExitApp, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS에서 로그인 화면이 오류 없이 그려진다', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        usePhone(tester);
        await tester.pumpWidget(
          testApp(LoginScreen(services: await makeServices(FakeServer()))),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsWidgets);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
