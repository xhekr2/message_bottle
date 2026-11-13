/// 백엔드 응답 DTO와 같은 모양의 모델. 서버의 LocalDateTime 문자열은 기기 시간대로 읽는다.
DateTime? _date(dynamic s) => s is String ? DateTime.tryParse(s) : null;

/// 날짜 표시: 1분 안이면 "방금", 그 외에는 "11월 9일".
String formatDate(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final n = now ?? DateTime.now();
  if (n.difference(d).abs() < const Duration(minutes: 1)) return '방금';
  return '${d.month}월 ${d.day}일';
}

class Bottle {
  const Bottle({required this.id, this.sentAt, this.slot});
  final int id;
  final DateTime? sentAt;

  /// 서버에 저장된 바다의 자리(0~10).
  final int? slot;

  factory Bottle.fromJson(Map<String, dynamic> j) => Bottle(
    id: j['id'] as int,
    sentAt: _date(j['sentAt']),
    slot: j['slot'] as int?,
  );
}

class SeaData {
  const SeaData({
    required this.floatingCount,
    required this.capacity,
    required this.letters,
    this.isPublic = false,
  });
  final int floatingCount;
  final int capacity;
  final List<Bottle> letters;

  /// 내 바다를 다른 사람에게 공개하고 있는지(기본은 비공개).
  final bool isPublic;

  SeaData withPublic(bool value) => SeaData(
    floatingCount: floatingCount,
    capacity: capacity,
    letters: letters,
    isPublic: value,
  );

  factory SeaData.fromJson(Map<String, dynamic> j) => SeaData(
    floatingCount: j['floatingCount'] as int,
    capacity: j['capacity'] as int,
    isPublic: j['visibility'] == 'PUBLIC',
    letters: (j['letters'] as List)
        .map((e) => Bottle.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// 다른 사람의 공개 바다. 서버는 아이디, 떠 있는 유리병 개수, 유리병이 놓인 자리만 준다.
class PublicSea {
  const PublicSea({
    required this.username,
    required this.floatingCount,
    required this.slots,
  });
  final String username;
  final int floatingCount;

  /// 유리병이 놓인 자리 번호들. 주인이 자기 바다에서 보는 자리와 같다.
  final List<int> slots;

  factory PublicSea.fromJson(Map<String, dynamic> j) => PublicSea(
    username: j['username'] as String,
    floatingCount: j['floatingCount'] as int,
    slots:
        (j['slots'] as List?)?.cast<int>() ??
        List<int>.generate(j['floatingCount'] as int, (i) => i),
  );
}

enum DetailMode { sea, inbox, sent }

/// 편지 상세(S05)에 필요한 값. 익명 편지의 발신자 정보는 서버가 주지 않으므로 [counterpart]는 null이다.
class DetailData {
  const DetailData({
    required this.id,
    required this.mode,
    required this.anonymous,
    required this.content,
    this.counterpart,
    this.sentAt,
    this.canReply = false,
    this.canArchive = false,
    this.parentId,
  });

  final int id;
  final DetailMode mode;
  final bool anonymous;
  final String content;
  final String? counterpart;
  final DateTime? sentAt;
  final bool canReply;
  final bool canArchive;

  /// 이 편지가 답장이고 부모(이전) 편지를 내가 볼 수 있을 때 그 편지의 id.
  final int? parentId;

  /// 상단 제목: 받은 편지는 "OOO 님의 편지"/"익명의 유리병", 보낸 편지는 "OOO 님에게 보낸 편지".
  String get heading {
    if (mode == DetailMode.sent) {
      if (counterpart == null) {
        return anonymous ? '공유 바다에 띄운 편지' : '익명의 유리병에 보낸 답장';
      }
      return '$counterpart 님에게 보낸 편지${anonymous ? ' (익명)' : ''}';
    }
    return anonymous ? '익명의 유리병' : '$counterpart 님의 편지';
  }

  /// GET /api/letters/{id} (수신자가 바다에서 연 편지)
  factory DetailData.fromLetterJson(Map<String, dynamic> j) => DetailData(
    id: j['id'] as int,
    mode: DetailMode.sea,
    anonymous: j['anonymous'] as bool,
    content: j['content'] as String,
    counterpart: j['counterpartUsername'] as String?,
    sentAt: _date(j['sentAt']),
    canReply: j['canReply'] as bool,
    canArchive: j['canArchive'] as bool,
    parentId: j['parentLetterId'] as int?,
  );

  /// GET /api/inbox/{archiveId}
  factory DetailData.fromInboxJson(Map<String, dynamic> j) => DetailData(
    id: j['letterId'] as int,
    mode: DetailMode.inbox,
    anonymous: j['anonymous'] as bool,
    content: j['content'] as String,
    counterpart: j['senderUsername'] as String?,
    sentAt: _date(j['sentAt']),
    parentId: j['parentLetterId'] as int?,
  );

  /// GET /api/sent/{letterId}
  factory DetailData.fromSentJson(Map<String, dynamic> j) => DetailData(
    id: j['id'] as int,
    mode: DetailMode.sent,
    anonymous: j['anonymous'] as bool,
    content: j['content'] as String,
    counterpart: j['receiverUsername'] as String?,
    sentAt: _date(j['sentAt']),
    parentId: j['parentLetterId'] as int?,
  );

  /// GET /api/letters/{id}/parent: 답장의 이전 편지. 내가 보낸 편지(SENDER)는 보낸 편지처럼,
  /// 내가 받아 보관한 편지(RECEIVER)는 받은 편지처럼 읽기 전용으로 보여준다.
  factory DetailData.fromParentJson(Map<String, dynamic> j) => DetailData(
    id: j['id'] as int,
    mode: j['role'] == 'SENDER' ? DetailMode.sent : DetailMode.inbox,
    anonymous: j['anonymous'] as bool,
    content: j['content'] as String,
    counterpart: j['counterpartUsername'] as String?,
    sentAt: _date(j['sentAt']),
    parentId: j['parentLetterId'] as int?,
  );
}

class InboxItem {
  const InboxItem({
    required this.archiveId,
    required this.letterId,
    required this.anonymous,
    required this.preview,
    this.senderUsername,
    this.sentAt,
    this.archivedAt,
    this.replied = false,
  });

  final int archiveId;
  final int letterId;
  final String? senderUsername;
  final bool anonymous;
  final String preview;
  final DateTime? sentAt;
  final DateTime? archivedAt;
  final bool replied;

  String get senderLabel => anonymous ? '익명' : (senderUsername ?? '');

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
    archiveId: j['archiveId'] as int,
    letterId: j['letterId'] as int,
    senderUsername: j['senderUsername'] as String?,
    anonymous: j['anonymous'] as bool,
    preview: j['preview'] as String,
    sentAt: _date(j['sentAt']),
    archivedAt: _date(j['archivedAt']),
    replied: j['replied'] as bool,
  );
}

class SentItem {
  const SentItem({
    required this.id,
    required this.receiverUsername,
    required this.anonymous,
    required this.preview,
    this.sentAt,
  });

  final int id;

  /// 공유 바다에서 낚은 익명 편지에 보낸 답장은 받는 사람을 알려주지 않으므로 null이다.
  final String? receiverUsername;
  final bool anonymous;
  final String preview;

  String get receiverLabel => receiverUsername ?? '익명의 유리병';
  final DateTime? sentAt;

  factory SentItem.fromJson(Map<String, dynamic> j) => SentItem(
    id: j['id'] as int,
    receiverUsername: j['receiverUsername'] as String?,
    anonymous: j['anonymous'] as bool,
    preview: j['preview'] as String,
    sentAt: _date(j['sentAt']),
  );
}

/// 공유 바다에서 낚은 편지. 작성자는 익명이며 서버도 작성자 정보를 주지 않는다.
class SharedLetter {
  const SharedLetter({required this.id, required this.content, this.sentAt});
  final int id;
  final String content;
  final DateTime? sentAt;

  factory SharedLetter.fromJson(Map<String, dynamic> j) => SharedLetter(
    id: j['id'] as int,
    content: j['content'] as String,
    sentAt: _date(j['sentAt']),
  );
}
