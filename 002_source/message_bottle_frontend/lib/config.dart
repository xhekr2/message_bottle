import 'package:flutter/foundation.dart';

/// 빌드·실행할 때 준 서버 주소. 예:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080`
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// 주소를 따로 주지 않았을 때 쓰는 개발용 서버 주소.
/// Android 에뮬레이터에서는 10.0.2.2가 서버 PC이고, iOS 시뮬레이터는 Mac과 네트워크를 함께 써서 localhost가 서버다.
String defaultApiBaseUrl(TargetPlatform platform) =>
    platform == TargetPlatform.android
    ? 'http://10.0.2.2:8080'
    : 'http://localhost:8080';

/// 서버 주소. 실제 기기에서는 `API_BASE_URL`로 서버의 주소를 준다.
String get apiBaseUrl => _apiBaseUrlOverride.isNotEmpty
    ? _apiBaseUrlOverride
    : defaultApiBaseUrl(defaultTargetPlatform);
