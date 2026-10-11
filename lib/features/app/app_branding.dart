import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: blue,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.videocam_outlined, size: 25),
        ),
        const SizedBox(width: 10),
        const Text(
          'CAMI',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Logo(),
              SizedBox(height: 16),
              Text(
                'Segurança ao seu alcance',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              SizedBox(height: 45),
              CircularProgressIndicator(color: blue, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}
