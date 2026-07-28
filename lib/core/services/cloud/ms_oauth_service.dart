import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class MsOAuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'ms_token';
  static const _refreshKey = 'ms_refresh';
  static const _expiresKey = 'ms_expires';
  static const _emailKey = 'ms_email';

  final String clientId;
  final String tenant;
  static const _scope =
      'Files.ReadWrite.AppFolder offline_access User.Read';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? _email;

  MsOAuthService({
    required this.clientId,
    this.tenant = 'common',
  });

  bool get isAuthenticated => _accessToken != null;
  String? get accountEmail => _email;

  Future<void> loadFromStorage() async {
    _accessToken = await _storage.read(key: _tokenKey);
    _refreshToken = await _storage.read(key: _refreshKey);
    final expiresStr = await _storage.read(key: _expiresKey);
    _expiresAt = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
    _email = await _storage.read(key: _emailKey);
  }

  Future<bool> loginDeviceCode() async {
    final deviceResponse = await http.post(
      Uri.parse(
          'https://login.microsoftonline.com/$tenant/oauth2/v2.0/devicecode'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'scope': _scope,
      },
    );

    if (deviceResponse.statusCode != 200) return false;

    final deviceData = json.decode(deviceResponse.body);
    final deviceCode = deviceData['device_code'] as String;
    final userCode = deviceData['user_code'] as String;
    final verificationUri = deviceData['verification_uri'] as String;
    final interval = deviceData['interval'] as int? ?? 5;
    final expiresIn = deviceData['expires_in'] as int;

    _onShowCode?.call(verificationUri, userCode);

    final deadline = DateTime.now().add(Duration(seconds: expiresIn));

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: interval));

      final tokenResponse = await http.post(
        Uri.parse(
            'https://login.microsoftonline.com/$tenant/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': clientId,
          'device_code': deviceCode,
        },
      );

      if (tokenResponse.statusCode == 200) {
        final tokenData = json.decode(tokenResponse.body);
        await _saveTokens(tokenData);
        await _fetchUserInfo();
        return true;
      }

      final error = json.decode(tokenResponse.body);
      if (error['error'] == 'authorization_pending') continue;
      if (error['error'] == 'slow_down') continue;
      return false;
    }

    return false;
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(
            'https://login.microsoftonline.com/$tenant/oauth2/v2.0/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': clientId,
          'refresh_token': _refreshToken,
        },
      );

      if (response.statusCode == 200) {
        await _saveTokens(json.decode(response.body));
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<String?> getValidAccessToken() async {
    if (_accessToken == null) return null;

    if (_expiresAt != null &&
        DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 5)))) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) {
        await logout();
        return null;
      }
    }

    return _accessToken;
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _email = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _expiresKey);
    await _storage.delete(key: _emailKey);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await _storage.write(key: _tokenKey, value: _accessToken);
    if (_refreshToken != null) {
      await _storage.write(key: _refreshKey, value: _refreshToken);
    }
    await _storage.write(key: _expiresKey, value: _expiresAt!.toIso8601String());
  }

  Future<void> _fetchUserInfo() async {
    if (_accessToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _email = data['userPrincipalName'] as String?;
        if (_email != null) {
          await _storage.write(key: _emailKey, value: _email);
        }
      }
    } catch (_) {}
  }

  void Function(String verificationUri, String userCode)? _onShowCode;
  void setOnShowCode(void Function(String uri, String code) callback) {
    _onShowCode = callback;
  }
}
