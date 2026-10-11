import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class LiveControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const LiveControl({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? const Color(0xff3b1d25) : panel,
            border: Border.all(color: active ? Colors.redAccent : panelBorder),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: active ? Colors.redAccent : Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: muted, fontSize: 7)),
      ],
    ),
  );
}
