import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/app_screen.dart';
import 'router_page.dart';

class CamiApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: navy),
      home: RouterPage(
        initialScreen: initialScreen,
        apiClient: apiClient,
        rtspThumbnailCapture: rtspThumbnailCapture,
      ),
    );
  }
}
