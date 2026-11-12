import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/models.dart';
import 'package:message_bottle_frontend/screens/letter_detail_screen.dart';

import 'support.dart';

DetailData seaLetter({int id = 1, bool anonymous = false}) =>
    DetailData.fromLetterJson(
      letterJson(
        id: id,
        anonymous: anonymous,
        counterpart: anonymous ? null : 'Mina',
        canReply: !anonymous,
      ),
    );

void main() {
  group('편지 상세(바다에서 연 편지)', () {
    testWidgets('일반 편지: 우상단 X, 하단 답장·보관이 있고 뒤로 가기 화살표는 없다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      expect(find.text('Mina 님의 편지'), findsOneWidget);
      expect(find.byKey(const Key('detail-reply')), findsOneWidget);
      expect(find.byKey(const Key('detail-archive')), findsOneWidget);
      expect(find.byKey(const Key('detail-back')), findsNothing);

      // X는 오른쪽 위, 화면 오른쪽 가장자리에 붙어 있다
      final x = tester.getRect(find.byKey(const Key('detail-discard')));
      expect(x.right, greaterThan(400 - 20));
      expect(x.top, lessThan(80));
      expect(x.width, greaterThanOrEqualTo(48));
      expect(x.height, greaterThanOrEqualTo(48));
    });

    testWidgets('익명 편지: 하단은 보관만 있고 발신자 정보가 없다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      await showScreen(
        tester,
        LetterDetailScreen(
          services: services,
          data: seaLetter(anonymous: true),
        ),
      );

      expect(find.text('익명의 유리병'), findsOneWidget);
      expect(find.byKey(const Key('detail-archive')), findsOneWidget);
      expect(find.byKey(const Key('detail-reply')), findsNothing);
      expect(find.textContaining('Mina'), findsNothing);
    });

    testWidgets('뒤로 가기(시스템)는 편지를 닫지도 삭제하지도 않는다', (tester) async {
      usePhone(tester);
      final server = FakeServer();
      final services = await makeServices(server);
      final results = await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await systemBack(tester);

      expect(find.byKey(const Key('detail-heading')), findsOneWidget);
      expect(results, isEmpty);
      expect(server.requests, isEmpty);
    });

    testWidgets('X를 누르면 확인을 거쳐 영구 삭제하고, 취소하면 편지가 그대로 있다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('POST', '/api/letters/1/discard', status: 204);
      final services = await makeServices(server);
      services.drafts.save(1, '쓰던 답장');
      final results = await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-discard')));
      await settle(tester);
      expect(find.text('이 편지를 버릴까요?'), findsOneWidget);
      expect(find.textContaining('받은 편지함에 저장되지 않습니다'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await settle(tester);
      expect(find.byKey(const Key('detail-heading')), findsOneWidget);
      expect(server.requests, isEmpty);

      await tester.tap(find.byKey(const Key('detail-discard')));
      await settle(tester);
      await tester.tap(find.text('버리기'));
      await settle(tester, ms: 1000);

      expect(server.count('POST', '/api/letters/1/discard'), 1);
      expect(find.byKey(const Key('detail-heading')), findsNothing);
      expect(results, [DetailResult.discarded]);
      expect(services.drafts.has(1), isFalse, reason: '버린 편지의 임시 저장도 지운다');
      expect(find.text('편지를 버렸어요.'), findsOneWidget);
    });

    testWidgets('버리기가 서버에서 실패하면 편지는 그대로 있고 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/letters/1/discard',
          body: {'message': '서버 오류'},
          status: 500,
        );
      final services = await makeServices(server);
      final results = await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-discard')));
      await settle(tester);
      await tester.tap(find.text('버리기'));
      await settle(tester, ms: 1000);

      expect(find.byKey(const Key('detail-heading')), findsOneWidget);
      expect(results, isEmpty);
      expect(find.text('삭제하지 못했습니다. 편지는 그대로 있어요.'), findsOneWidget);
    });

    testWidgets('보관이 실패하면 성공으로 보이지 않고 편지가 그대로 남는다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/letters/1/archive',
          body: {'message': '서버 오류'},
          status: 500,
        );
      final services = await makeServices(server);
      final results = await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-archive')));
      await settle(tester, ms: 1000);

      expect(results, isEmpty);
      expect(find.byKey(const Key('detail-heading')), findsOneWidget);
      expect(find.text('보관하지 못했습니다. 편지는 그대로 있어요. 다시 시도해주세요.'), findsOneWidget);
      expect(find.text('받은 편지함에 보관했어요.'), findsNothing);
      // 다시 누를 수 있다
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const Key('detail-archive')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  group('편지함에서 연 편지', () {
    testWidgets('받은 편지함: 좌상단 뒤로 가기만 있고 X·답장·보관은 없으며 뒤로 가기로 닫힌다', (
      tester,
    ) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      final data = DetailData.fromInboxJson({
        'archiveId': 5,
        'letterId': 1,
        'senderUsername': 'Mina',
        'anonymous': false,
        'content': '보관한 편지',
        'sentAt': '2026-11-05T10:00:00',
        'archivedAt': '2026-11-06T10:00:00',
        'replied': false,
      });
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: data),
      );

      expect(find.byKey(const Key('detail-back')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('detail-back'))).left,
        lessThan(20),
      );
      expect(find.byKey(const Key('detail-discard')), findsNothing);
      expect(find.byKey(const Key('detail-reply')), findsNothing);
      expect(find.byKey(const Key('detail-archive')), findsNothing);

      await systemBack(tester);
      expect(find.byKey(const Key('detail-heading')), findsNothing);
    });

    testWidgets('보낸 편지함: 읽기 전용이고 삭제 수단이 없다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      final data = DetailData.fromSentJson({
        'id': 3,
        'receiverUsername': 'Bob123',
        'anonymous': true,
        'content': '보낸 편지',
        'sentAt': '2026-11-09T10:00:00',
      });
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: data),
      );

      expect(find.text('Bob123 님에게 보낸 편지 (익명)'), findsOneWidget);
      expect(find.byKey(const Key('detail-discard')), findsNothing);
      expect(find.byKey(const Key('detail-archive')), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('답장', () {
    testWidgets('답장을 보내면 서버가 확인한 뒤 모든 화면이 닫히고 결과가 replied다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on('POST', '/api/letters/1/replies', body: {'id': 20}, status: 201);
      final services = await makeServices(server);
      final results = await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);
      expect(find.text('Mina 님에게 답장'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('reply-text')),
        '답장해 주셔서 고마워요.',
      );
      await tester.tap(find.byKey(const Key('reply-send')));
      await settle(tester, ms: 1000);

      final req = server.of('POST', '/api/letters/1/replies').single;
      expect(server.bodyOf(req), {
        'content': '답장해 주셔서 고마워요.',
      }, reason: '답장에는 익명 필드가 없다');
      expect(results, [DetailResult.replied]);
      expect(find.byKey(const Key('reply-text')), findsNothing);
      expect(find.text('답장을 보냈어요. 원래 편지는 받은 편지함에 보관했어요.'), findsOneWidget);
    });

    testWidgets('내용이 비어 있으면 보내지 않고 안내한다', (tester) async {
      usePhone(tester);
      final server = FakeServer();
      final services = await makeServices(server);
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );
      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('reply-text')), '   ');
      await tester.tap(find.byKey(const Key('reply-send')));
      await settle(tester);

      expect(find.textContaining('답장 내용을 입력해주세요.'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('보내기가 실패하면 입력이 그대로 남고 원본 편지로 처리되지 않는다', (tester) async {
      usePhone(tester);
      final server = FakeServer()
        ..on(
          'POST',
          '/api/letters/1/replies',
          body: {'message': '서버 오류'},
          status: 500,
        );
      final services = await makeServices(server);
      final results = await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );
      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('reply-text')), '보낼 내용');
      await tester.tap(find.byKey(const Key('reply-send')));
      await settle(tester, ms: 1000);

      expect(find.textContaining('서버 오류'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reply-text')))
            .controller!
            .text,
        '보낼 내용',
      );
      expect(results, isEmpty);
      expect(find.text('답장을 보냈어요. 원래 편지는 받은 편지함에 보관했어요.'), findsNothing);
    });

    testWidgets('돌아가면 임시 저장되고, 다시 답장할 때 불러오기(확인)로 이어 쓴다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('reply-text')), '쓰다 만 답장');
      await tester.tap(find.byTooltip('돌아가기 (작성한 내용은 임시 저장)'));
      await settle(tester);

      expect(find.text('작성한 답장을 임시 저장했어요.'), findsOneWidget);
      expect(
        find.byKey(const Key('detail-heading')),
        findsOneWidget,
        reason: '원본 편지로 돌아가 내용을 다시 볼 수 있다',
      );
      expect(find.byKey(const Key('detail-content')), findsOneWidget);
      expect(services.drafts.of(1), '쓰다 만 답장');

      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);
      expect(find.text('임시 저장한 답장이 있어요'), findsOneWidget);
      expect(find.text('불러올까요? 취소를 누르면 새로 씁니다.'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await settle(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reply-text')))
            .controller!
            .text,
        '쓰다 만 답장',
      );
      expect(find.text('임시 저장한 답장을 불러왔어요.'), findsOneWidget);
    });

    testWidgets('불러오기 확인에서 취소하면 이전 임시 저장을 버리고 새로 쓴다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      services.drafts.save(1, '예전에 쓴 답장');
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);
      await tester.tap(find.text('취소'));
      await settle(tester);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('reply-text')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('임시 저장한 답장을 불러왔어요.'), findsNothing);
      expect(services.drafts.has(1), isFalse, reason: '이전 임시 저장은 그 자리에서 버린다');
    });

    testWidgets('내용 없이 돌아가면 임시 저장하지 않고, Android 뒤로 가기도 돌아가기와 같다', (
      tester,
    ) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );
      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);

      await systemBack(tester); // 비어 있음

      expect(find.byKey(const Key('reply-text')), findsNothing);
      expect(services.drafts.has(1), isFalse);

      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('reply-text')), '내용 있음');
      await systemBack(tester); // 내용 있음 → 임시 저장

      expect(services.drafts.of(1), '내용 있음');
      expect(find.byKey(const Key('detail-heading')), findsOneWidget);
    });

    testWidgets('임시 저장 확인 창을 뒤로 가기로 닫으면 아무것도 바꾸지 않는다', (tester) async {
      usePhone(tester);
      final services = await makeServices(FakeServer());
      services.drafts.save(1, '남겨 둔 답장');
      await showScreen(
        tester,
        LetterDetailScreen(services: services, data: seaLetter()),
      );

      await tester.tap(find.byKey(const Key('detail-reply')));
      await settle(tester);
      await systemBack(tester); // 확인 창만 닫힌다

      expect(find.text('임시 저장한 답장이 있어요'), findsNothing);
      expect(find.byKey(const Key('reply-text')), findsNothing);
      expect(services.drafts.of(1), '남겨 둔 답장');
    });
  });
}
