import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
    this.sessionExpired = false,
  });

  final String message;
  final int? statusCode;

  /// 서버에 닿지 못한 경우. 성공으로 보여주지 않고 재시도를 안내해야 한다.
  final bool isNetworkError;

  /// 토큰 갱신까지 거부되어 다시 로그인해야 하는 경우.
  final bool sessionExpired;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

const String networkErrorMessage = '서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인해주세요.';

/// http 호출에서 생기는 연결 오류를 [ApiException]으로 바꾼다.
Future<T> guardNetwork<T>(Future<T> Function() call) async {
  try {
    return await call().timeout(const Duration(seconds: 10));
  } on TimeoutException {
    throw ApiException('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.', isNetworkError: true);
  } on SocketException {
    throw ApiException(networkErrorMessage, isNetworkError: true);
  } on http.ClientException {
    throw ApiException(networkErrorMessage, isNetworkError: true);
  }
}
