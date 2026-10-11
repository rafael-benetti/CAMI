import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SettingsContent extends StatefulWidget {
  final VoidCallback onLogout;
  final Future<void> Function() onDisconnectVpn;

  const SettingsContent({
    super.key,
    required this.onLogout,
    required this.onDisconnectVpn,
  });

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  bool disconnectingVpn = false;

  Future<void> disconnectVpn() async {
    if (disconnectingVpn) return;
    setState(() => disconnectingVpn = true);
    try {
      await widget.onDisconnectVpn();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('VPN desconectada.')));
    } finally {
      if (mounted) setState(() => disconnectingVpn = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Card(
        color: panel,
        child: ListTile(
          leading: const Icon(Icons.vpn_key_off_outlined, color: blue),
          title: const Text('Desconectar VPN', style: TextStyle(fontSize: 11)),
          subtitle: const Text(
            'Interrompe o acesso à rede da prefeitura neste aparelho.',
            style: TextStyle(color: muted, fontSize: 8),
          ),
          trailing: disconnectingVpn
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.power_settings_new_outlined, color: muted),
          onTap: disconnectingVpn ? null : disconnectVpn,
        ),
      ),
      const SizedBox(height: 12),
      Card(
        color: panel,
        child: ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Sair', style: TextStyle(fontSize: 11)),
          onTap: widget.onLogout,
        ),
      ),
    ],
  );
}
