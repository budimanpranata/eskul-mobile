import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/user_role.dart';
import '../../domain/entities/auth_session.dart';
import '../providers/auth_providers.dart';

/// Layar Splash & Login (dokumen desain bagian 5.1 / 5.2).
///
/// FASE 0: form belum memanggil API. Dua tombol "simulasi role" disediakan
/// sementara agar navigasi Pembina/Orang Tua bisa ditinjau tanpa backend.
/// Simulasi ini dicabut di Fase 1.1.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  void _simulateLogin(WidgetRef ref, UserRole role) {
    ref.read(authSessionProvider.notifier).setSession(
          AuthSession(
            userId: 'dummy-${role.code}',
            fullName: role == UserRole.pembina ? 'Pembina Demo' : 'Orang Tua Demo',
            role: role,
            accessToken: 'dummy',
            refreshToken: 'dummy',
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ekskul SD',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kerangka Fase 0 — form login belum aktif',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email / No. HP',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                enabled: false,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Sementara — pilih mode untuk meninjau UI:',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _simulateLogin(ref, UserRole.pembina),
                child: const Text('Masuk sebagai Pembina'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => _simulateLogin(ref, UserRole.orangtua),
                child: const Text('Masuk sebagai Orang Tua'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
