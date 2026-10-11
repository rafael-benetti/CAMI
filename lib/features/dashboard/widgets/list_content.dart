import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ListContent extends StatelessWidget {
  final String title;
  final IconData icon;
  const ListContent({super.key, required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 12),
      Card(
        color: panel,
        child: ListTile(
          leading: Icon(icon, color: const Color(0xff93c5fd)),
          title: const Text('Ainda não há itens aqui.'),
          subtitle: const Text(
            'Os dados reais aparecerão quando estiverem disponíveis.',
            style: TextStyle(color: muted, fontSize: 8),
          ),
        ),
      ),
    ],
  );
}
