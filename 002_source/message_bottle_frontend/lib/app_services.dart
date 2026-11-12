import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api/api_client.dart';
import 'api/auth_api.dart';
import 'api/letter_api.dart';
import 'api/token_storage.dart';
import 'sea_settings.dart';

/// 임시 저장한 답장(원본 편지 id → 내용). 편지를 열어 둔 동안만 필요하므로 서버에 보내지 않고 앱이 메모리에 둔다.
/// 앱이 종료되면 열어 본 편지가 버려지므로 임시 저장도 함께 사라진다.
class ReplyDrafts {
  final Map<int, String> _drafts = {};

  String? of(int letterId) => _drafts[letterId];
  bool has(int letterId) => _drafts.containsKey(letterId);
  void save(int letterId, String text) => _drafts[letterId] = text;
  void remove(int letterId) => _drafts.remove(letterId);
  void clear() => _drafts.clear();
}

/// 화면들이 함께 쓰는 서비스 묶음. 테스트에서는 [httpClient]에 가짜 클라이언트를 넣는다.
class AppServices {
  AppServices._(
    this.storage,
    this.auth,
    this.client,
    this.letters, {
    this.offlineProbe,
    this.exitApp,
  });

  /// [offlineProbe]를 주면 앱이 기기의 네트워크 연결을 지켜보다가 끊기면 안내한다(network_guard.dart).
  /// 테스트에서는 주지 않거나 가짜를 넣는다.
  factory AppServices.create({
    http.Client? httpClient,
    TokenStorage? storage,
    Future<bool> Function()? offlineProbe,
    void Function()? exitApp,
  }) {
    storage ??= TokenStorage();
    final auth = AuthApi(storage, client: httpClient);
    final client = ApiClient(auth, client: httpClient);
    return AppServices._(
      storage,
      auth,
      client,
      LetterApi(client),
      offlineProbe: offlineProbe,
      exitApp: exitApp,
    );
  }

  final TokenStorage storage;
  final AuthApi auth;
  final ApiClient client;
  final LetterApi letters;
  final ReplyDrafts drafts = ReplyDrafts();

  /// 사용자별 화면 설정. 서버에 저장한다.
  late final SeaSettings settings = SeaSettings(client: client);

  /// 기기에 네트워크 연결이 하나도 없으면 true를 돌려주는 확인 함수. null이면 지켜보지 않는다.
  final Future<bool> Function()? offlineProbe;

  /// 앱을 종료한다(네트워크가 끊겼을 때).
  final void Function()? exitApp;

  /// 바다에서 연 편지가 열려 있는 동안 true. 이때는 네트워크가 끊겨도 앱을 종료하지 않는다
  /// (종료하면 열어 둔 편지가 버려지기 때문이다).
  final ValueNotifier<bool> letterOpen = ValueNotifier(false);
}
