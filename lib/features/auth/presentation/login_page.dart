import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/frigate_client.dart';
import '../../../models/auth_session.dart';
import '../../app/app_branding.dart';

class LoginPage extends StatefulWidget {
  final FrigateClient frigateClient;
  final ValueChanged<AuthSession> onAuthenticated;

  const LoginPage({
    super.key,
    required this.frigateClient,
    required this.onAuthenticated,
  });
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  String? errorMessage;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Preencha todos os campos.');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final session = await widget.frigateClient.login(username, password);
      if (mounted) widget.onAuthenticated(session);
    } on FrigateException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 45),
            const Center(child: Logo()),
            const SizedBox(height: 35),
            Center(
              child: Text(
                'Bem-vindo de volta',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Entre com sua conta do Frigate',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 34),
            TextField(
              controller: usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Usuário Frigate',
                hintText: 'Seu usuário',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: !showPassword,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: 'Senha',
                hintText: 'Sua senha',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => showPassword = !showPassword),
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: muted,
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : submit,
                style: ElevatedButton.styleFrom(backgroundColor: blue),
                child: loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
