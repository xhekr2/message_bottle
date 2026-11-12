import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:message_bottle_frontend/api/api_exception.dart';
import 'package:message_bottle_frontend/models.dart';
import 'package:message_bottle_frontend/validators.dart';

import 'support.dart';

void main() {
  group('validators', () {
    test('username', () {
      expect(validateUsername('Abc123'), isNull);
      expect(validateUsername('a' * 20), isNull);
      expect(validateUsername('abc'), isNotNull);
      expect(validateUsername('a' * 21), isNotNull);
      expect(validateUsername('abc_123'), isNotNull);
      expect(validateUsername('아이디테스트'), isNotNull);
      expect(validateUsername(''), isNotNull);
    });

    test('password', () {
      expect(validatePassword('Pass#word12*'), isNull);
      expect(validatePassword('p' * 20), isNull);
      expect(validatePassword('short1!'), isNotNull);
      expect(validatePassword('p' * 21), isNotNull);
      expect(validatePassword('pass word1'), isNotNull);
      expect(validatePassword('비밀번호12345678'), isNotNull);
      expect(validatePassword(''), isNotNull);
    });
  });

  group('ApiClient token refresh', () {
    test('401 이면 앱이 토큰을 갱신하고 한 번 다시 요청한다', () async {
      final server = FakeServer();
      var seaCalls = 0;
      server.on(
        'GET',
        '/api/sea/me',
        handler: (req) {
          seaCalls++;
          return req.headers['Authorization'] == 'Bearer newAccess'
              ? FakeServer.json(seaJson([1]))
              : FakeServer.json(null, status: 401);
        },
      );
      server.on(
        'POST',
        '/api/auth/refresh',
        body: {
          'accessToken': 'newAccess',
          'refreshToken': 'newRefresh',
          'tokenType': 'Bearer',
        },
      );
      final services = await makeServices(server);

      final sea = await services.letters.sea();

      expect(sea.letters.single.id, 1);
      expect(seaCalls, 2);
      expect(server.count('POST', '/api/auth/refresh'), 1);
      expect(await services.storage.readAccessToken(), 'newAccess');
      expect(await services.storage.readRefreshToken(), 'newRefresh');
    });

    test('동시에 401을 받아도 갱신은 한 번만 한다', () async {
      final server = FakeServer();
      server.on(
        'GET',
        '/api/sea/me',
        handler: (req) => req.headers['Authorization'] == 'Bearer newAccess'
            ? FakeServer.json(seaJson([]))
            : FakeServer.json(null, status: 401),
      );
      server.on(
        'GET',
        '/api/inbox',
        handler: (req) => req.headers['Authorization'] == 'Bearer newAccess'
            ? FakeServer.json([])
            : FakeServer.json(null, status: 401),
      );
      server.on(
        'POST',
        '/api/auth/refresh',
        body: {
          'accessToken': 'newAccess',
          'refreshToken': 'newRefresh',
          'tokenType': 'Bearer',
        },
      );
      final services = await makeServices(server);

      await Future.wait([services.letters.sea(), services.letters.inbox()]);

      expect(server.count('POST', '/api/auth/refresh'), 1);
    });

    test('갱신까지 거부되면 세션 만료로 알리고 기기의 토큰을 지운다', () async {
      final server = FakeServer();
      server.on('GET', '/api/sea/me', status: 401);
      server.on(
        'POST',
        '/api/auth/refresh',
        body: {'message': '유효하지 않거나 만료된 리프레시 토큰입니다.'},
        status: 401,
      );
      final services = await makeServices(server);
      var expired = 0;
      services.client.onSessionExpired = () => expired++;

      await expectLater(
        services.letters.sea(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.sessionExpired,
            'sessionExpired',
            true,
          ),
        ),
      );
      expect(expired, 1);
      expect(await services.storage.readRefreshToken(), isNull);
    });

    test('서버에 닿지 못하면 네트워크 오류로 알린다(성공으로 처리하지 않는다)', () async {
      final server = FakeServer();
      server.on(
        'GET',
        '/api/sea/me',
        handler: (_) => throw http.ClientException('연결 실패'),
      );
      final services = await makeServices(server);

      await expectLater(
        services.letters.sea(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkError,
            'isNetworkError',
            true,
          ),
        ),
      );
    });

    test('서버 오류 메시지를 그대로 전달하고, 오류 본문이 없으면 기본 문구를 쓴다', () async {
      final server = FakeServer();
      server.on(
        'POST',
        '/api/letters/1/replies',
        body: {'message': '익명 편지에는 답장할 수 없습니다.'},
        status: 400,
      );
      server.on(
        'POST',
        '/api/letters/2/archive',
        handler: (_) => http.Response('', 500),
      );
      final services = await makeServices(server);

      await expectLater(
        services.letters.reply(1, 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '익명 편지에는 답장할 수 없습니다.',
          ),
        ),
      );
      await expectLater(
        services.letters.archive(2),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
    });
  });

  group('API 요청 모양', () {
    test('편지 발송은 receiverUsername, content, anonymous를 보낸다', () async {
      final server = FakeServer();
      server.on('POST', '/api/letters', body: {'id': 1}, status: 201);
      final services = await makeServices(server);

      await services.letters.send(
        receiverUsername: 'Mina',
        content: '안녕',
        anonymous: true,
      );

      expect(server.bodyOf(server.of('POST', '/api/letters').single), {
        'receiverUsername': 'Mina',
        'content': '안녕',
        'anonymous': true,
      });
    });

    test('받는 사람 검색은 username 쿼리로 부르고 아이디만 돌려준다', () async {
      final server = FakeServer();
      server.on(
        'GET',
        '/api/users/search',
        body: [
          {'username': 'abc123'},
          {'username': 'Abc123'},
        ],
      );
      final services = await makeServices(server);

      final found = await services.letters.searchUsers('bc');

      expect(found, ['abc123', 'Abc123']);
      expect(
        server
            .of('GET', '/api/users/search')
            .single
            .url
            .queryParameters['username'],
        'bc',
      );
    });
  });

  group('models', () {
    test('formatDate', () {
      final now = DateTime(2026, 11, 10, 12, 0, 30);
      expect(formatDate(DateTime(2026, 11, 10, 12, 0, 0), now: now), '방금');
      expect(formatDate(DateTime(2026, 11, 9, 8), now: now), '11월 9일');
      expect(formatDate(null), '');
    });

    test('익명 편지의 상대 아이디는 서버가 주지 않고 제목은 익명의 유리병이다', () {
      final d = DetailData.fromLetterJson(
        letterJson(counterpart: null, anonymous: true, canReply: false),
      );
      expect(d.counterpart, isNull);
      expect(d.heading, '익명의 유리병');
      expect(d.canReply, isFalse);
    });

    test('보낸 편지 제목', () {
      final d = DetailData.fromSentJson({
        'id': 3,
        'receiverUsername': 'Bob123',
        'anonymous': true,
        'content': 'x',
        'sentAt': '2026-11-09T10:00:00',
      });
      expect(d.heading, 'Bob123 님에게 보낸 편지 (익명)');
      expect(d.mode, DetailMode.sent);
    });
  });
}
