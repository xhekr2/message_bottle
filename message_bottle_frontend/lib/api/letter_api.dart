import '../models.dart';
import 'api_client.dart';

/// 편지 관련 API. 경로와 DTO는 백엔드와 같다.
class LetterApi {
  LetterApi(this._client);
  final ApiClient _client;

  /// 내 바다. 호출하면 서버가 "열었지만 처리하지 않은 편지"를 버린다(앱 시작 시 판단). 편지를 열어 둔 동안에는 부르지 않는다.
  Future<SeaData> sea() async => SeaData.fromJson(
    await _client.get('/api/sea/me') as Map<String, dynamic>,
  );

  /// 내 바다를 공개(true)/비공개(false)로 바꾼다. 서버가 확인한 값을 돌려준다.
  Future<bool> setSeaPublic(bool isPublic) async {
    final res = await _client.patch(
      '/api/users/me/sea-visibility',
      body: {'visibility': isPublic ? 'PUBLIC' : 'PRIVATE'},
    ) as Map<String, dynamic>;
    return res['visibility'] == 'PUBLIC';
  }

  /// 다른 사용자의 공개 바다 방문. 비공개면 서버가 403으로 막는다.
  Future<PublicSea> visitSea(String username) async => PublicSea.fromJson(
    await _client.get('/api/sea/users/${Uri.encodeComponent(username)}')
        as Map<String, dynamic>,
  );

  /// 바다의 편지를 연다(서버가 열람 시각을 기록한다).
  Future<DetailData> openLetter(int id) async => DetailData.fromLetterJson(
    await _client.get('/api/letters/$id') as Map<String, dynamic>,
  );

  Future<void> send({
    required String receiverUsername,
    required String content,
    required bool anonymous,
  }) async {
    await _client.post(
      '/api/letters',
      body: {
        'receiverUsername': receiverUsername,
        'content': content,
        'anonymous': anonymous,
      },
    );
  }

  Future<void> archive(int letterId) async =>
      _client.post('/api/letters/$letterId/archive');

  Future<void> discard(int letterId) async =>
      _client.post('/api/letters/$letterId/discard');

  Future<void> reply(int letterId, String content) async => _client.post(
    '/api/letters/$letterId/replies',
    body: {'content': content},
  );

  Future<List<InboxItem>> inbox() async {
    final list = await _client.get('/api/inbox') as List;
    return list
        .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DetailData> inboxDetail(int archiveId) async =>
      DetailData.fromInboxJson(
        await _client.get('/api/inbox/$archiveId') as Map<String, dynamic>,
      );

  Future<void> deleteFromInbox(int archiveId) async =>
      _client.delete('/api/inbox/$archiveId');

  Future<List<SentItem>> sent() async {
    final list = await _client.get('/api/sent') as List;
    return list
        .map((e) => SentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DetailData> sentDetail(int letterId) async => DetailData.fromSentJson(
    await _client.get('/api/sent/$letterId') as Map<String, dynamic>,
  );

  /// 답장의 이전(부모) 편지. 내가 볼 수 없으면 서버가 404를 준다.
  Future<DetailData> parentOf(int letterId) async => DetailData.fromParentJson(
    await _client.get('/api/letters/$letterId/parent') as Map<String, dynamic>,
  );

  /// 공유 바다에 익명으로 편지를 띄운다.
  Future<void> writeShared(String content) async =>
      _client.post('/api/shared-sea/letters', body: {'content': content});

  /// 공유 바다에서 무작위로 편지 하나를 낚는다. 남은 편지가 없으면 404(메시지 "남아있는 편지가 없어요!").
  Future<SharedLetter> fishShared() async => SharedLetter.fromJson(
    await _client.post('/api/shared-sea/fish') as Map<String, dynamic>,
  );

  /// 낚은 편지의 익명 작성자 바다로 답장한다. 이미 답장이 된 편지면 404.
  Future<void> replyShared(int sharedId, String content) async => _client.post(
    '/api/shared-sea/letters/$sharedId/replies',
    body: {'content': content},
  );

  /// 받는 사람 검색(부분 일치, 대소문자 구분). 아이디만 돌려준다.
  Future<List<String>> searchUsers(String query) async {
    final list = await _client.get(
      '/api/users/search',
      query: {'username': query},
    ) as List;
    return list
        .map((e) => (e as Map<String, dynamic>)['username'] as String)
        .toList();
  }
}
