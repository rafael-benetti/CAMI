import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SettingsContent extends StatelessWidget {
  final VoidCallback onLogout;

  const SettingsContent({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Card(
        color: panel,
        child: ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Sair', style: TextStyle(fontSize: 11)),
          onTap: onLogout,
        ),
      ),
    ],
  );
}
