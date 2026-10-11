import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logo.png',
    width: 128,
    height: 128,
    fit: BoxFit.contain,
  );
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
