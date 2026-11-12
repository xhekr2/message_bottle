import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'api_exception.dart';
import 'auth_api.dart';

/// 로그인이 필요한 API 호출. 액세스 토큰이 만료되어 401을 받으면 앱이 알아서 토큰을 갱신하고
/// 한 번 다시 요청한다(앱 실행 중에는 로그인이 만료되지 않는다). 갱신까지 거부되면 [onSessionExpired]를 부른다.
class ApiClient {
  ApiClient(this.auth, {http.Client? client})
    : _client = client ?? http.Client();

  final AuthApi auth;
  final http.Client _client;
  void Function()? onSessionExpired;

  /// 서버에 닿지 못했을 때 부른다(네트워크가 끊겼는지 바로 확인하도록).
  void Function()? onNetworkError;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _request('PUT', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    var res = await _send(method, path, query, body);
    if (res.statusCode == 401) {
      final refreshed = await auth.refreshShared();
      if (!refreshed) {
        onSessionExpired?.call();
        throw ApiException(
          '로그인이 만료되었습니다. 다시 로그인해주세요.',
          statusCode: 401,
          sessionExpired: true,
        );
      }
      res = await _send(method, path, query, body);
      if (res.statusCode == 401) {
        onSessionExpired?.call();
        throw ApiException(
          '로그인이 만료되었습니다. 다시 로그인해주세요.',
          statusCode: 401,
          sessionExpired: true,
        );
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw _toException(res);
  }

  Future<http.Response> _send(
    String method,
    String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
  ) async {
    final token = await auth.storage.readAccessToken();
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      return await guardNetwork(() {
        switch (method) {
          case 'PUT':
            return _client.put(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const {}),
            );
          case 'PATCH':
            return _client.patch(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const {}),
            );
          case 'POST':
            return _client.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const {}),
            );
          case 'DELETE':
            return _client.delete(uri, headers: headers);
          default:
            return _client.get(uri, headers: headers);
        }
      });
    } on ApiException catch (e) {
      if (e.isNetworkError) onNetworkError?.call();
      rethrow;
    }
  }

  ApiException _toException(http.Response res) {
    String? message;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {}
    return ApiException(
      message ?? '요청을 처리하지 못했습니다. (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
}
