import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

/// Home Dashboard Orang Tua (dokumen desain bagian 5.2):
/// selector anak, kartu ringkasan kehadiran, grafik keaktifan, timeline materi.
///
/// FASE 0: placeholder. Konsumsi GET /parent/child-progress/{id} diisi di Fase 1.4.
class ParentHomePage extends ConsumerWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perkembangan Anak'),
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
            'Kerangka mode Orang Tua.\nDashboard kehadiran, grafik keaktifan, dan timeline materi diisi di Fase 1.4 / 3.2.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
