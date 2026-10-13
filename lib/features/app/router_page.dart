import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/services/frigate_client.dart';
import '../../core/services/biometric_auth.dart';
import '../../core/navigation/app_screen.dart';
import '../../core/services/video_thumbnail_capture.dart';
import '../../data/cache/camera_card_cache.dart';
import '../../data/cache/thumbnail_cache.dart';
import '../../models/auth_session.dart';
import '../../models/camera_item.dart';
import 'app_branding.dart';
import '../auth/presentation/login_page.dart';
import '../cameras/presentation/add_camera_page.dart';
import '../dashboard/presentation/app_page.dart';
import '../live/presentation/live_camera_page.dart';

class RouterPage extends StatefulWidget {
  final Screen initialScreen;
  final ApiClient apiClient;
  final FrigateClient frigateClient;
  final Future<Uint8List?> Function(String streamUrl)? rtspThumbnailCapture;

  const RouterPage({
    super.key,
    this.initialScreen = Screen.login,
    this.apiClient = const ApiClient(),
    this.frigateClient = const FrigateClient(),
    this.rtspThumbnailCapture,
  });
  @override
  State<RouterPage> createState() => _RouterPageState();
}

class _RouterPageState extends State<RouterPage> {
  static const _thumbnailFreshFor = Duration(minutes: 30);

  late Screen screen;
  bool restoringSession = false;
  String? authToken;
  bool isAdmin = false;
  bool canCreateCameras = false;
  CameraItem? selectedCamera;
  CameraItem? editingCamera;
  final List<CameraItem> cameras = [];
  final Set<int> thumbnailJobs = <int>{};
  int thumbnailRefreshGeneration = 0;
  String? cameraCacheKey;

  @override
  void initState() {
    super.initState();
    screen = widget.initialScreen;
    if (widget.initialScreen == Screen.login) {
      restoringSession = true;
      unawaited(restoreSession());
    }
  }

  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('cami.auth_token');
    final encodedUser = preferences.getString('cami.auth_user');
    Map<String, dynamic>? user;
    if (encodedUser != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(encodedUser) as Map);
      } catch (_) {
        user = null;
      }
    }
    final restoredUser = user;
    if (token != null && restoredUser != null) {
      final enabled =
          preferences.getBool('cami.biometric_enabled') ??
          await BiometricAuth.isAvailable();
      if (enabled) {
        await preferences.setBool('cami.biometric_enabled', true);
        final authenticated = await BiometricAuth.authenticate();
        if (!authenticated) {
          if (mounted) setState(() => restoringSession = false);
          return;
        }
      }
      final cacheKey = CameraCardCache.keyFor(restoredUser);
      final cachedCameras = await CameraCardCache.load(cacheKey);
      if (!mounted) return;
      setState(() {
        authToken = token;
        cameraCacheKey = cacheKey;
        isAdmin = false;
        canCreateCameras = false;
        cameras
          ..clear()
          ..addAll(cachedCameras);
        screen = Screen.home;
        restoringSession = false;
      });
      unawaited(loadCachedThumbnails(cachedCameras));
      unawaited(initializeAuthenticatedSession());
    } else {
      if (!mounted) return;
      setState(() => restoringSession = false);
    }
  }

  void go(Screen next) => setState(() => screen = next);

  Future<void> loadCameras() async {
    final token = authToken;
    if (token == null) return;
    try {
      final frigateCameras = await widget.frigateClient.fetchCameras(
        token: token,
      );
      final loaded = frigateCameras
          .map(
            (camera) => CameraItem(
              id: frigateCameraId(camera.name),
              name: FrigateClient.displayName(camera.name),
              place: 'Frigate',
              rtspUrl: widget.frigateClient.liveUrl(camera.name),
              online: true,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        cameras
          ..clear()
          ..addAll(loaded);
      });
      unawaited(CameraCardCache.save(cameraCacheKey, loaded));
      final cachedCameraIds = await loadCachedThumbnails(loaded);
      if (!mounted) return;
      unawaited(refreshCameraThumbnails(skipCameraIds: cachedCameraIds));
    } on FrigateException {
      // A Home vazia continua utilizável; o próximo reload poderá tentar novamente.
    }
  }

  Future<void> initializeAuthenticatedSession() async {
    await loadCameras();
  }

  Future<Set<int>> loadCachedThumbnails(List<CameraItem> loaded) async {
    final entries = await Future.wait(
      loaded.map((camera) async {
        final id = camera.id;
        if (id == null) return (camera, null);
        return (camera, await ThumbnailCache.readEntry(id));
      }),
    );
    if (!mounted) return <int>{};

    final freshCameraIds = <int>{};
    final thumbnails = <int, Uint8List>{};
    final now = DateTime.now();
    for (final entry in entries) {
      final id = entry.$1.id;
      final cached = entry.$2;
      if (id == null || cached == null) continue;
      thumbnails[id] = cached.bytes;
      if (cached.isFresh(_thumbnailFreshFor, now)) freshCameraIds.add(id);
    }
    if (thumbnails.isEmpty) return freshCameraIds;

    // Apply the disk cache in a single frame. Updating one thumbnail at a time
    // causes a rebuild per camera during session restoration.
    setState(() {
      for (var index = 0; index < cameras.length; index++) {
        final camera = cameras[index];
        final thumbnail = camera.id == null ? null : thumbnails[camera.id];
        if (thumbnail == null) continue;
        cameras[index] = CameraItem(
          id: camera.id,
          name: camera.name,
          place: camera.place,
          rtspUrl: camera.rtspUrl,
          online: camera.online,
          thumbnail: thumbnail,
        );
      }
    });
    return freshCameraIds;
  }

  Future<void> refreshCameraThumbnails({
    Set<int> skipCameraIds = const <int>{},
  }) async {
    final generation = ++thumbnailRefreshGeneration;
    final pending = cameras
        .where(
          (camera) =>
              camera.id != null &&
              !skipCameraIds.contains(camera.id) &&
              camera.thumbnail == null &&
              camera.rtspUrl.isNotEmpty,
        )
        .toList();

    // Frames HTTP são baratos, mas a grade não pode competir com o stream que
    // o usuário está assistindo. Limitar a dois reduz o uso de rede móvel.
    while (pending.isNotEmpty &&
        mounted &&
        generation == thumbnailRefreshGeneration) {
      final batch = <CameraItem>[];
      while (batch.length < 2 && pending.isNotEmpty) {
        final camera = pending.removeAt(0);
        if (camera.id != null && thumbnailJobs.add(camera.id!)) {
          batch.add(camera);
        }
      }
      if (batch.isEmpty) continue;
      if (mounted) setState(() {});

      await Future.wait(
        batch.map((camera) async {
          try {
            final frigateCamera = widget.frigateClient.cameraNameFromLiveUrl(
              camera.rtspUrl,
            );
            final thumbnail = frigateCamera == null
                ? null
                : await widget.frigateClient.fetchLatestFrame(
                    frigateCamera,
                    token: authToken ?? '',
                  );
            if (thumbnail != null && thumbnail.isNotEmpty && mounted) {
              updateCameraThumbnail(camera, thumbnail);
            }
          } finally {
            thumbnailJobs.remove(camera.id);
            if (mounted) setState(() {});
          }
        }),
      );
    }
  }

  Future<void> saveCamera(CameraItem camera) async {
    final normalizedUrl = camera.rtspUrl.trim();
    final duplicate = cameras.any(
      (existing) =>
          existing.id != camera.id && existing.rtspUrl.trim() == normalizedUrl,
    );
    if (duplicate) {
      throw const ApiException('Esta câmera já está cadastrada.');
    }
    final token = authToken;
    if (token == null) {
      setState(() {
        if (editingCamera == null) {
          cameras.add(camera);
        } else {
          final index = cameras.indexOf(editingCamera!);
          if (index >= 0) cameras[index] = camera;
        }
        editingCamera = null;
        screen = Screen.home;
      });
      return;
    }
    final saved = camera.id == null
        ? await widget.apiClient.createCamera(
            token,
            name: camera.name,
            place: camera.place,
            rtspUrl: camera.rtspUrl,
          )
        : await widget.apiClient.updateCamera(
            token,
            camera.id!,
            name: camera.name,
            place: camera.place,
            rtspUrl: camera.rtspUrl,
          );
    final withThumbnail = CameraItem(
      id: saved.id,
      name: saved.name,
      place: saved.place,
      rtspUrl: saved.rtspUrl,
      online: saved.online,
      thumbnail: camera.thumbnail,
    );
    setState(() {
      if (editingCamera == null) {
        cameras.add(withThumbnail);
      } else {
        final index = cameras.indexOf(editingCamera!);
        if (index >= 0) cameras[index] = withThumbnail;
      }
      editingCamera = null;
      screen = Screen.home;
    });
  }

  void handleAuthenticated(AuthSession session) {
    setState(() {
      authToken = session.token;
      isAdmin = false;
      canCreateCameras = false;
      cameraCacheKey = CameraCardCache.keyFor(session.user);
      screen = Screen.home;
    });
    unawaited(saveSession(session));
    unawaited(enableBiometricsAfterFirstLogin());
    unawaited(initializeAuthenticatedSession());
  }

  Future<void> saveSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('cami.auth_token', session.token);
    await preferences.setString('cami.auth_user', jsonEncode(session.user));
  }

  Future<void> enableBiometricsAfterFirstLogin() async {
    if (!await BiometricAuth.isAvailable()) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('cami.biometric_enabled', true);
  }

  Future<void> logout() async {
    thumbnailRefreshGeneration++;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('cami.auth_token');
    await preferences.remove('cami.auth_user');
    if (!mounted) return;
    setState(() {
      authToken = null;
      isAdmin = false;
      canCreateCameras = false;
      cameraCacheKey = null;
      cameras.clear();
      thumbnailJobs.clear();
      selectedCamera = null;
      screen = Screen.login;
    });
  }

  void editCamera(CameraItem camera) {
    setState(() {
      editingCamera = camera;
      screen = Screen.addCamera;
    });
  }

  void openCamera(CameraItem camera) {
    setState(() {
      selectedCamera = camera;
      screen = Screen.live;
    });
  }

  void updateCameraThumbnail(CameraItem camera, Uint8List thumbnail) {
    final index = cameras.indexOf(camera);
    if (index < 0) return;
    final updated = CameraItem(
      id: camera.id,
      name: camera.name,
      place: camera.place,
      rtspUrl: camera.rtspUrl,
      online: camera.online,
      thumbnail: thumbnail,
    );
    if (camera.id != null) {
      unawaited(ThumbnailCache.write(camera.id!, thumbnail));
    }
    setState(() {
      cameras[index] = updated;
      if (identical(selectedCamera, camera)) selectedCamera = updated;
    });
  }

  void removeCamera(CameraItem camera) {
    if (authToken != null && camera.id != null) {
      unawaited(widget.apiClient.deleteCamera(authToken!, camera.id!));
    }
    setState(() {
      cameras.remove(camera);
      selectedCamera = null;
      screen = Screen.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (restoringSession) {
      return const SplashPage();
    }
    if (screen == Screen.splash) {
      return const SplashPage();
    }
    if (screen == Screen.login) {
      return LoginPage(
        frigateClient: widget.frigateClient,
        onAuthenticated: handleAuthenticated,
      );
    }
    if (screen == Screen.addCamera) {
      return AddCameraPage(
        initialCamera: editingCamera,
        onCancel: () {
          editingCamera = null;
          go(Screen.home);
        },
        onSave: saveCamera,
        // O stream RTSP deve ser testado pelo próprio aparelho. A API externa
        // só persiste os dados e não precisa ter rota até a rede das câmeras.
        onTestConnection: widget.rtspThumbnailCapture ?? captureVideoThumbnail,
      );
    }
    if (screen == Screen.live) {
      final camera = selectedCamera ?? cameras.first;
      return LiveCameraPage(
        camera: camera,
        frigateClient: widget.frigateClient,
        onBack: () => go(Screen.home),
        streamAccessToken: authToken,
        onThumbnailCaptured: (thumbnail) =>
            updateCameraThumbnail(camera, thumbnail),
      );
    }
    return AppPage(
      screen: screen,
      go: go,
      cameras: cameras,
      onOpenCamera: openCamera,
      onRefreshCameras: loadCameras,
      canAddCamera: false,
      onLogout: logout,
      frigateClient: widget.frigateClient,
      frigateToken: authToken,
      thumbnailLoadingIds: thumbnailJobs,
    );
  }

  int frigateCameraId(String name) {
    var hash = 0x811c9dc5;
    for (final codeUnit in name.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @override
  void dispose() {
    thumbnailRefreshGeneration++;
    super.dispose();
  }
}
