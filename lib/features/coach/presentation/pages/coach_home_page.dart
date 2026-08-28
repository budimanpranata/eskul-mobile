import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

/// Home Pembina — kartu "Jadwal Hari Ini" (dokumen desain bagian 5.1).
///
/// FASE 0: placeholder. Daftar sesi (GET /coach/today-sessions) diisi di Fase 1.3.
class CoachHomePage extends ConsumerWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Hari Ini'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authSessionProvider.notifier).clear(),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Kerangka mode Pembina.\nList jadwal ekskul hari ini + alur presensi diisi di Fase 1.3.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
