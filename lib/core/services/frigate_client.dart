import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/auth_session.dart';
import '../../models/frigate_storage.dart';

class FrigateException implements Exception {
  final String message;

  const FrigateException(this.message);
}

class FrigateCamera {
  final String name;

  const FrigateCamera(this.name);
}

class FrigateRecording {
  final DateTime start;
  final DateTime end;

  const FrigateRecording({required this.start, required this.end});

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) =>
      start.isBefore(rangeEnd) && end.isAfter(rangeStart);
}

/// Cliente do Frigate acessado pelo aparelho através da VPN.
///
/// Nenhuma credencial RTSP passa por esta integração: o app recebe vídeo e
/// frames do Frigate, que continua sendo o único cliente das câmeras.
class FrigateClient {
  final String baseUrl;
  final http.Client? client;

  const FrigateClient({
    this.baseUrl = const String.fromEnvironment(
      'FRIGATE_BASE_URL',
      defaultValue: 'http://192.168.2.212:5001',
    ),
    this.client,
  });

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final root = Uri.parse(baseUrl);
    final rootPath = root.path.endsWith('/')
        ? root.path.substring(0, root.path.length - 1)
        : root.path;
    return root.replace(
      path: '$rootPath$path',
      queryParameters: queryParameters,
    );
  }

  /// Quickly checks whether the private Frigate host is already reachable.
  /// Any HTTP reply (including an authentication reply) means the local network
  /// is available and a VPN connection is unnecessary.
  Future<bool> isReachable({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final ownedClient = client == null ? http.Client() : null;
    final activeClient = client ?? ownedClient!;
    try {
      await activeClient.get(_uri('/api/version')).timeout(timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      ownedClient?.close();
    }
  }

  Future<http.Response> _getAuthenticated(Uri uri, {String? token}) async {
    try {
      return await (client ?? http.Client())
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const FrigateException(
        'Não foi possível alcançar o Frigate. Verifique a VPN e o endereço configurado.',
      );
    }
  }

  /// Opens a Frigate session and returns its JWT for subsequent API calls.
  ///
  /// Frigate sends the token as the `frigate_token` cookie. Some reverse
  /// proxies also return it in the JSON body, so both forms are accepted.
  Future<AuthSession> login(String username, String password) async {
    final http.Response response;
    try {
      response = await (client ?? http.Client())
          .post(
            _uri('/api/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'user': username.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const FrigateException(
        'Não foi possível alcançar o Frigate. Verifique a VPN e o endereço configurado.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FrigateException(
        _messageFrom(response.body, 'Usuário ou senha inválidos.'),
      );
    }

    final token = _tokenFrom(response);
    if (token == null || token.isEmpty) {
      throw const FrigateException('O Frigate não retornou uma sessão válida.');
    }

    final auth = await _getAuthenticated(_uri('/api/auth'), token: token);
    if (auth.statusCode < 200 || auth.statusCode >= 300) {
      throw const FrigateException(
        'Não foi possível validar a sessão no Frigate.',
      );
    }

    final remoteUser = auth.headers['remote-user'] ?? username.trim();
    return AuthSession(
      token: token,
      user: {
        'name': remoteUser,
        'email': remoteUser,
        // O app usa somente recursos de visualização do Frigate. A
        // administração continua sendo feita pela interface do próprio NVR.
        'role': 'viewer',
        'can_create_cameras': false,
      },
    );
  }

  Future<List<FrigateCamera>> fetchCameras({required String token}) async {
    Map<String, dynamic>? config;
    Map<String, dynamic>? streams;

    try {
      final response = await _getAuthenticated(
        _uri('/api/config'),
        token: token,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) config = decoded;
      }
    } on FrigateException {
      rethrow;
    } catch (_) {
      // Em algumas instalações a listagem de streams ainda está disponível.
    }

    try {
      final response = await _getAuthenticated(
        _uri('/api/go2rtc/streams'),
        token: token,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) streams = decoded;
      }
    } on FrigateException {
      if (config == null) rethrow;
    } catch (_) {
      // A configuração ainda é uma fonte válida de nomes de câmeras.
    }

    final configured = _cameraNames(config?['cameras']);
    final availableStreams = _cameraNames(streams);
    final names = availableStreams.isNotEmpty ? availableStreams : configured;
    if (names.isEmpty) {
      throw const FrigateException(
        'O Frigate não retornou nenhuma câmera. Verifique a sessão e a configuração do go2rtc.',
      );
    }
    return names.map(FrigateCamera.new).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Reads the documented Prometheus storage gauges from Frigate. The values
  /// are bytes reported by the operating system for each mounted filesystem.
  Future<FrigateStorageStats> fetchStorageStats({required String token}) async {
    final response = await _getAuthenticated(
      _uri('/api/metrics'),
      token: token,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FrigateException(
        'Não foi possível consultar o armazenamento.',
      );
    }

    final values = <String, Map<String, int>>{};
    final metric = RegExp(
      r'^frigate_storage_(free|total|used)_bytes\{([^}]*)\}\s+([0-9.eE+\-]+)$',
    );
    final storageLabel = RegExp(r'(?:^|,)storage="([^"]*)"');
    for (final line in response.body.split('\n')) {
      final match = metric.firstMatch(line.trim());
      if (match == null) continue;
      final label = storageLabel.firstMatch(match.group(2)!);
      final path = label?.group(1);
      final value = double.tryParse(match.group(3)!);
      if (path == null || value == null || value.isNegative) continue;
      values.putIfAbsent(path, () => <String, int>{})[match.group(1)!] = value
          .round();
    }

    final volumes =
        values.entries
            .map(
              (entry) => FrigateStorageVolume(
                path: entry.key,
                totalBytes: entry.value['total'] ?? 0,
                usedBytes: entry.value['used'] ?? 0,
                freeBytes: entry.value['free'] ?? 0,
              ),
            )
            .where((volume) => volume.totalBytes > 0)
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (volumes.isEmpty) {
      throw const FrigateException(
        'O Frigate não informou métricas de armazenamento.',
      );
    }
    return FrigateStorageStats(volumes);
  }

  /// Lists the recording segments available for a camera in the requested
  /// range. Frigate timestamps are Unix seconds.
  Future<List<FrigateRecording>> fetchRecordings({
    required String camera,
    required DateTime after,
    required DateTime before,
    required String token,
  }) async {
    final response = await _getAuthenticated(
      _uri(
        '/api/${Uri.encodeComponent(camera)}/recordings',
        queryParameters: {
          'after': (after.millisecondsSinceEpoch / 1000).toStringAsFixed(3),
          'before': (before.millisecondsSinceEpoch / 1000).toStringAsFixed(3),
        },
      ),
      token: token,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FrigateException('Não foi possível carregar as gravações.');
    }
    try {
      final decoded = jsonDecode(response.body);
      final items = _recordingItems(decoded);
      if (items == null) {
        throw const FormatException('Resposta sem lista de segmentos.');
      }
      final recordings = <FrigateRecording>[];
      for (final item in items.whereType<Map>()) {
        final start = _timestamp(
          item['start_time'] ?? item['start'] ?? item['startTime'],
        );
        final end = _timestamp(
          item['end_time'] ?? item['end'] ?? item['endTime'],
        );
        if (start != null && end != null && end.isAfter(start)) {
          recordings.add(FrigateRecording(start: start, end: end));
        }
      }
      return recordings..sort((a, b) => a.start.compareTo(b.start));
    } catch (_) {
      throw const FrigateException('O Frigate retornou gravações inválidas.');
    }
  }

  List? _recordingItems(Object? value) {
    if (value is List) return value;
    if (value is! Map) return null;
    for (final key in const ['recordings', 'segments', 'data', 'results']) {
      final nested = value[key];
      if (nested is List) return nested;
    }
    return null;
  }

  String recordingHlsUrl({
    required String camera,
    required DateTime start,
    required DateTime end,
  }) {
    final startSeconds = (start.millisecondsSinceEpoch / 1000).toStringAsFixed(
      3,
    );
    final endSeconds = (end.millisecondsSinceEpoch / 1000).toStringAsFixed(3);
    return _uri(
      '/api/vod/${Uri.encodeComponent(camera)}/start/$startSeconds/end/$endSeconds/master.m3u8',
    ).toString();
  }

  /// Downloads a generated MP4 clip to disk before playback. This avoids
  /// relying on the player to forward authentication for every HLS segment.
  Future<void> downloadRecordingClip({
    required String camera,
    required DateTime start,
    required DateTime end,
    required String token,
    required File destination,
  }) async {
    final startSeconds = (start.millisecondsSinceEpoch / 1000).toStringAsFixed(
      3,
    );
    final endSeconds = (end.millisecondsSinceEpoch / 1000).toStringAsFixed(3);
    final uri = _uri(
      '/api/${Uri.encodeComponent(camera)}/start/$startSeconds/end/$endSeconds/clip.mp4',
    );
    final ownedClient = client == null ? http.Client() : null;
    final activeClient = client ?? ownedClient!;
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll({
          ..._headers(token),
          'Accept': 'video/mp4,application/json',
        });
      final response = await activeClient
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw FrigateException(
          _messageFrom(body, 'Não foi possível preparar esta gravação.'),
        );
      }
      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();
      try {
        await sink.addStream(response.stream);
      } finally {
        await sink.close();
      }
      if (!await destination.exists() || await destination.length() == 0) {
        throw const FrigateException('O Frigate retornou uma gravação vazia.');
      }
    } on FrigateException {
      rethrow;
    } catch (_) {
      throw const FrigateException('Não foi possível baixar esta gravação.');
    } finally {
      ownedClient?.close();
    }
  }

  Set<String> _cameraNames(Object? value) {
    if (value is! Map) return <String>{};
    return value.keys
        .whereType<String>()
        .where((name) => name.isNotEmpty && name.toLowerCase() != 'birdseye')
        .toSet();
  }

  String liveUrl(String cameraName) => _uri(
    '/api/go2rtc/api/stream.m3u8',
    queryParameters: {'src': cameraName},
  ).toString();

  Future<Uint8List?> fetchLatestFrame(
    String cameraName, {
    required String token,
  }) async {
    try {
      final response = await _getAuthenticated(
        _uri(
          '/api/${Uri.encodeComponent(cameraName)}/latest.jpg',
          queryParameters: const {'height': '480', 'quality': '70'},
        ),
        token: token,
      );
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      return response.bodyBytes;
    } on FrigateException {
      return null;
    }
  }

  String? cameraNameFromLiveUrl(String streamUrl) {
    try {
      final uri = Uri.parse(streamUrl);
      final expected = _uri('/api/go2rtc/api/stream.m3u8');
      if (uri.scheme != expected.scheme ||
          uri.host != expected.host ||
          uri.port != expected.port ||
          uri.path != expected.path) {
        return null;
      }
      final name = uri.queryParameters['src'];
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  static String normalizedName(String value) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = value.toLowerCase();
    final withoutAccents = lower
        .split('')
        .map((character) => accents[character] ?? character)
        .join();
    return withoutAccents.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String displayName(String streamName) => streamName
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) ...{
      'Authorization': 'Bearer $token',
      'Cookie': 'frigate_token=$token',
    },
  };

  String? _tokenFrom(http.Response response) {
    final cookie = response.headers['set-cookie'];
    final match = cookie == null
        ? null
        : RegExp(r'(?:^|[,;]\s*)frigate_token=([^;,\s]+)').firstMatch(cookie);
    if (match != null) return Uri.decodeComponent(match.group(1)!);

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        for (final key in const [
          'token',
          'access_token',
          'accessToken',
          'frigate_token',
        ]) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } catch (_) {
      // The documented cookie is sufficient for standard Frigate installs.
    }
    return null;
  }

  String _messageFrom(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Use the safe, user-facing fallback below.
    }
    return fallback;
  }

  DateTime? _timestamp(Object? value) {
    if (value is String) {
      final iso = DateTime.tryParse(value);
      if (iso != null) return iso.toLocal();
    }
    final raw = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
    if (raw == null || raw <= 0) return null;
    // A API do Frigate usa segundos, mas alguns proxies serializam o mesmo
    // campo em milissegundos. Ambos são aceitos para não invalidar o histórico.
    final seconds = raw > 100000000000 ? raw / 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  }
}
