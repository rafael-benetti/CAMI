import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/app_screen.dart';
import '../../core/services/ipsec_vpn.dart';
import 'router_page.dart';

class CamiApp extends StatefulWidget {
  final Screen initialScreen;
  final ApiClient apiClient;
  final Future<Uint8List?> Function(String streamUrl)? rtspThumbnailCapture;

  const CamiApp({
    super.key,
    this.initialScreen = Screen.login,
    this.apiClient = const ApiClient(),
    this.rtspThumbnailCapture,
  });

  @override
  State<CamiApp> createState() => _CamiAppState();
}

class _CamiAppState extends State<CamiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `paused` is emitted when the user closes or backgrounds the app. VPN
    // teardown is intentionally immediate: this profile must only exist while
    // CAMI is visibly in use.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(IpsecVpn.disconnect());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: navy),
      home: RouterPage(
        initialScreen: widget.initialScreen,
        apiClient: widget.apiClient,
        rtspThumbnailCapture: widget.rtspThumbnailCapture,
      ),
    );
  }
}
