import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/auth_session.dart';
import '../../models/camera_item.dart';
import '../../models/vpn_configuration.dart';
import '../errors/api_exception.dart';

class ApiClient {
  final String baseUrl;
  final http.Client? client;

  const ApiClient({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://13.140.42.71:8080/api/v1',
    ),
    this.client,
  });

  Future<AuthSession> login(String email, String password) async {
    return _authenticate('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AuthSession> register(
    String name,
    String email,
    String password,
  ) async {
    return _authenticate('/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await (client ?? http.Client())
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = data['error'] as Map<String, dynamic>?;
        throw ApiException(
          error?['message'] as String? ??
              'Não foi possível conectar ao servidor.',
        );
      }
      return AuthSession(
        token: data['token'] as String,
        user: data['user'] as Map<String, dynamic>,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Não foi possível conectar ao backend. Verifique se ele está rodando.',
      );
    }
  }

  http.Client get _http => client ?? http.Client();

  Future<List<CameraItem>> fetchCameras(String token) async {
    final response = await _request('GET', '/cameras', token: token);
    final items = (response['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return items.map(CameraItem.fromJson).toList();
  }

  Future<CameraItem> fetchCamera(String token, int id) async {
    final response = await _request('GET', '/cameras/$id', token: token);
    return CameraItem.fromJson(response['camera'] as Map<String, dynamic>);
  }

  Future<CameraItem> createCamera(
    String token, {
    required String name,
    required String place,
    required String rtspUrl,
  }) async {
    final response = await _request(
      'POST',
      '/cameras',
      token: token,
      body: {'name': name, 'location': place, 'rtsp_url': rtspUrl},
    );
    return CameraItem.fromJson(response['camera'] as Map<String, dynamic>);
  }

  Future<CameraItem> updateCamera(
    String token,
    int id, {
    required String name,
    required String place,
    required String rtspUrl,
  }) async {
    final response = await _request(
      'PATCH',
      '/cameras/$id',
      token: token,
      body: {'name': name, 'location': place, 'rtsp_url': rtspUrl},
    );
    return CameraItem.fromJson(response['camera'] as Map<String, dynamic>);
  }

  Future<void> deleteCamera(String token, int id) async {
    await _request('DELETE', '/cameras/$id', token: token);
  }

  Future<Map<String, dynamic>> testCamera(String token, int id) async {
    return _request('POST', '/cameras/$id/test', token: token);
  }

  Future<Map<String, dynamic>> fetchCameraStatus(String token, int id) {
    return _request('GET', '/cameras/$id/status', token: token);
  }

  Future<VpnConfiguration> fetchVpnConfig(
    String token,
    VpnPlatform platform,
  ) async {
    final response = await _request(
      'GET',
      '/vpn/config/${platform.apiValue}',
      token: token,
    );
    return VpnConfiguration.fromJson(
      response['config'] as Map<String, dynamic>,
    );
  }

  Future<VpnConfiguration?> fetchAdminVpnConfig(
    String token,
    VpnPlatform platform,
  ) async {
    final response = await _request(
      'GET',
      '/admin/vpn-configurations/${platform.apiValue}',
      token: token,
    );
    final config = response['config'];
    if (config == null) return null;
    return VpnConfiguration.fromJson(config as Map<String, dynamic>);
  }

  Future<VpnConfiguration> saveAdminVpnConfig(
    String token,
    VpnConfiguration configuration,
  ) async {
    final response = await _request(
      'PATCH',
      '/admin/vpn-configurations/${configuration.platform.apiValue}',
      token: token,
      body: configuration.toJson(),
    );
    return VpnConfiguration.fromJson(
      response['config'] as Map<String, dynamic>,
    );
  }

  Future<List<Map<String, dynamic>>> fetchUsers(String token) async {
    final response = await _request('GET', '/users', token: token);
    return (response['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchCameraPermissions(
    String token,
    int cameraId,
  ) async {
    final response = await _request(
      'GET',
      '/cameras/$cameraId/permissions',
      token: token,
    );
    return (response['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> grantCameraAccess(
    String token,
    int cameraId,
    int userId, {
    String accessLevel = 'view',
  }) async {
    await _request(
      'POST',
      '/cameras/$cameraId/permissions',
      token: token,
      body: {'user_id': userId, 'access_level': accessLevel},
    );
  }

  Future<void> revokeCameraAccess(
    String token,
    int cameraId,
    int userId,
  ) async {
    await _request(
      'DELETE',
      '/cameras/$cameraId/permissions/$userId',
      token: token,
    );
  }

  Future<void> updateUserAccess(
    String token,
    int userId, {
    required String role,
    required bool canCreateCameras,
  }) async {
    await _request(
      'PATCH',
      '/users/$userId',
      token: token,
      body: {'role': role, 'can_create_cameras': canCreateCameras},
    );
  }

  Future<List<Map<String, dynamic>>> fetchGroups(String token) async {
    final response = await _request('GET', '/groups', token: token);
    return (response['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<int> createGroup(String token, String name) async {
    final response = await _request(
      'POST',
      '/groups',
      token: token,
      body: {'name': name},
    );
    return (response['id'] as num).toInt();
  }

  Future<void> addCameraToGroup(String token, int groupId, int cameraId) async {
    await _request(
      'POST',
      '/groups/$groupId/cameras',
      token: token,
      body: {'camera_id': cameraId},
    );
  }

  Future<void> grantGroupAccess(
    String token,
    int groupId,
    int userId,
    String accessLevel,
  ) async {
    await _request(
      'POST',
      '/groups/$groupId/members',
      token: token,
      body: {'user_id': userId, 'access_level': accessLevel},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 15));
    final text = await response.stream.bytesToString();
    final data = text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'] as Map<String, dynamic>?;
      throw ApiException(
        error?['message'] as String? ?? 'Erro na comunicação com o backend.',
      );
    }
    return data;
  }
}
