import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:message_bottle_frontend/app_services.dart';
import 'package:message_bottle_frontend/theme.dart';
import 'package:message_bottle_frontend/widgets/toast.dart';
import 'package:shared_preferences/shared_preferences.dart';

const settingsPath = '/api/users/me/settings';

Map<String, dynamic> defaultSettingsJson() => {
  'seaTone': 'DAY',
  'textStep': 1,
  'idleSeconds': 5,
  'waveType': 'BOTH',
};

/// 서버 대신 쓰는 가짜 응답. 경로(쿼리 제외)와 메서드로 응답을 정하고 받은 요청을 기록한다.
class FakeServer {
  final List<http.Request> requests = [];
  final Map<String, http.Response Function(http.Request)> _routes = {};

  static http.Response json(Object? body, {int status = 200}) =>
      http.Response.bytes(
        body == null ? const [] : utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  void on(
    String method,
    String path, {
    Object? body,
    int status = 200,
    http.Response Function(http.Request)? handler,
  }) {
    _routes['$method $path'] = handler ?? (_) => json(body, status: status);
  }

  late final http.Client client = MockClient((req) async {
    requests.add(req);
    final route = _routes['${req.method} ${req.url.path}'];
    if (route == null) {
      return json({
        'message': '없는 경로: ${req.method} ${req.url.path}',
      }, status: 404);
    }
    return route(req);
  });

  int count(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path).length;

  Iterable<http.Request> of(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path);

  Map<String, dynamic> bodyOf(http.Request r) =>
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

  /// 서버에 저장된 화면 설정(사용자별 설정 API). [withSettings]를 부르면 GET/PUT에 응답한다.
  Map<String, dynamic> settings = defaultSettingsJson();

  void withSettings([Map<String, dynamic>? initial]) {
    if (initial != null) settings = initial;
    on('GET', settingsPath, handler: (_) => json(settings));
    on(
      'PUT',
      settingsPath,
      handler: (req) {
        settings = bodyOf(req);
        return json(settings);
      },
    );
  }
}

Future<AppServices> makeServices(
  FakeServer server, {
  bool loggedIn = true,
}) async {
  SharedPreferences.setMockInitialValues(
    loggedIn
        ? {
            'access_token': 'access',
            'refresh_token': 'refresh',
            'username': 'Abc123',
          }
        : {},
  );
  return AppServices.create(httpClient: server.client);
}

Widget testApp(Widget home) =>
    MaterialApp(navigatorKey: appNavigatorKey, theme: buildTheme(), home: home);

/// 휴대폰 크기(400x850 논리 픽셀) 화면으로 맞춘다.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1700);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(Toast.hide);
}

/// 바다처럼 계속 움직이는 화면에서는 pumpAndSettle이 끝나지 않으므로 시간을 조금씩 흘려 보낸다.
Future<void> settle(WidgetTester tester, {int ms = 800}) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [screen]을 "열기" 버튼으로 push해서 보여 준다. 화면이 닫히면서 돌려준 값은 [results]에 쌓인다.
Future<List<Object?>> showScreen(WidgetTester tester, Widget screen) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    testApp(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(builder: (_) => screen),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await settle(tester, ms: 500);
  return results;
}

/// 시스템 뒤로 가기(또는 뒤로 가기 제스처)와 같은 동작.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester, ms: 1000);
}

Map<String, dynamic> bottle(int id) => {
  'id': id,
  'sentAt': '2026-11-10T10:00:00',
};

Map<String, dynamic> seaJson(List<int> ids) => {
  'floatingCount': ids.length,
  'capacity': 10,
  'letters': ids.map(bottle).toList(),
};

Map<String, dynamic> letterJson({
  int id = 1,
  String? counterpart = 'Mina',
  bool anonymous = false,
  String content = '안녕하세요!\n바다 건너에서 보냅니다.',
  bool canReply = true,
  bool canArchive = true,
}) => {
  'id': id,
  'role': 'RECEIVER',
  'counterpartUsername': counterpart,
  'anonymous': anonymous,
  'content': content,
  'sentAt': '2026-11-09T10:00:00',
  'canReply': canReply,
  'canArchive': canArchive,
};
