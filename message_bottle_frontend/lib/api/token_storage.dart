import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _usernameKey = 'username';

  Future<String?> readAccessToken() async =>
      (await SharedPreferences.getInstance()).getString(_accessKey);

  Future<String?> readRefreshToken() async =>
      (await SharedPreferences.getInstance()).getString(_refreshKey);

  Future<String?> readUsername() async =>
      (await SharedPreferences.getInstance()).getString(_usernameKey);

  Future<void> save(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_usernameKey);
  }
}
