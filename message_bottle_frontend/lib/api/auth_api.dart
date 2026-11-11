import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// 인증 API: 가입 / 로그인 / 토큰 갱신 / 로그아웃.
/// 요청·응답 모양은 백엔드 DTO(SignupRequest, LoginRequest, RefreshRequest, TokenResponse)와 같다.
class AuthApi {
  AuthApi(this.storage, {http.Client? client})
    : _client = client ?? http.Client();

  final TokenStorage storage;
  final http.Client _client;
  Future<bool>? _refreshing;

  Future<void> signup(String username, String password) async {
    final res = await _post('/api/auth/signup', {
      'username': username,
      'password': password,
    });
    if (res.statusCode != 201) throw _toException(res);
  }

  Future<void> login(String username, String password) async {
    final res = await _post('/api/auth/login', {
      'username': username,
      'password': password,
    });
    if (res.statusCode != 200) throw _toException(res);
    await _saveTokens(res);
    await storage.saveUsername(username);
  }

  /// 새 토큰을 받았으면 true, 서버가 리프레시 토큰을 거부했으면 false(세션 종료).
  /// 서버에 닿지 못하면 [ApiException]을 던져서 호출한 쪽이 재시도할 수 있게 한다.
  Future<bool> refresh() async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) return false;
    final res = await _post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
    if (res.statusCode == 200) {
      await _saveTokens(res);
      return true;
    }
    if (res.statusCode == 401 || res.statusCode == 400) {
      await storage.clear();
      return false;
    }
    throw _toException(res);
  }

  /// 동시에 여러 요청이 401을 받아도 갱신은 한 번만 한다.
  Future<bool> refreshShared() {
    return _refreshing ??= refresh().whenComplete(() => _refreshing = null);
  }

  /// 서버에서 리프레시 토큰을 폐기하고(실패해도) 기기의 세션은 항상 지운다.
  Future<void> logout() async {
    final refreshToken = await storage.readRefreshToken();
    try {
      if (refreshToken != null) {
        await _post('/api/auth/logout', {'refreshToken': refreshToken});
      }
    } on ApiException {
      // 오프라인이어도 기기에서는 로그아웃한다.
    } finally {
      await storage.clear();
    }
  }

  Future<void> _saveTokens(http.Response res) async {
    final body = _decode(res);
    final access = body['accessToken'];
    final refresh = body['refreshToken'];
    if (access is! String || refresh is! String) {
      throw ApiException('서버 응답이 올바르지 않습니다.', statusCode: res.statusCode);
    }
    await storage.save(access, refresh);
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return guardNetwork(
      () => _client.post(
        Uri.parse('$apiBaseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  ApiException _toException(http.Response res) {
    final message = _decode(res)['message'];
    return ApiException(
      message is String ? message : '요청을 처리하지 못했습니다. (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
}
