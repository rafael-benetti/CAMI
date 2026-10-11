import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';

class CameraPermissionsSheet extends StatefulWidget {
  final ApiClient apiClient;
  final String token;
  final int cameraId;
  final String cameraName;

  const CameraPermissionsSheet({
    super.key,
    required this.apiClient,
    required this.token,
    required this.cameraId,
    required this.cameraName,
  });

  @override
  State<CameraPermissionsSheet> createState() => _CameraPermissionsSheetState();
}

class _CameraPermissionsSheetState extends State<CameraPermissionsSheet> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = const [];
  Set<int> directAccessUserIds = <int>{};
  final Set<int> changingUserIds = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiClient.fetchUsers(widget.token),
        widget.apiClient.fetchCameraPermissions(widget.token, widget.cameraId),
      ]);
      if (!mounted) return;
      final permissions = results[1];
      setState(() {
        users = results[0];
        directAccessUserIds = permissions
            .map((permission) => (permission['user_id'] as num).toInt())
            .toSet();
      });
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> setAccess(Map<String, dynamic> user, bool enabled) async {
    final userId = (user['id'] as num).toInt();
    if (changingUserIds.contains(userId)) return;
    setState(() => changingUserIds.add(userId));
    try {
      if (enabled) {
        await widget.apiClient.grantCameraAccess(
          widget.token,
          widget.cameraId,
          userId,
        );
      } else {
        await widget.apiClient.revokeCameraAccess(
          widget.token,
          widget.cameraId,
          userId,
        );
      }
      if (!mounted) return;
      setState(() {
        if (enabled) {
          directAccessUserIds.add(userId);
        } else {
          directAccessUserIds.remove(userId);
        }
      });
    } on ApiException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) setState(() => changingUserIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .78;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, color: blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Acessos: ${widget.cameraName}',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Usuários autorizados verão esta câmera automaticamente após entrar no app.',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              else if (users.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Nenhum usuário cadastrado.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: panelBorder),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userId = (user['id'] as num).toInt();
                      final isAdmin = user['role'] == 'admin';
                      final hasDirectAccess = directAccessUserIds.contains(
                        userId,
                      );
                      final changing = changingUserIds.contains(userId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(user['name'] as String? ?? 'Usuário'),
                        subtitle: Text(
                          isAdmin
                              ? 'Administrador: acesso total'
                              : user['email'] as String? ?? '',
                          style: const TextStyle(color: muted, fontSize: 9),
                        ),
                        trailing: changing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch(
                                value: isAdmin || hasDirectAccess,
                                onChanged: isAdmin
                                    ? null
                                    : (enabled) =>
                                          unawaited(setAccess(user, enabled)),
                              ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
