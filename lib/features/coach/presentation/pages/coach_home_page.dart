import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/coach_entities.dart';
import '../providers/coach_providers.dart';

/// Home Pembina — kartu "Jadwal Hari Ini" (dokumen desain bagian 5.1).
class CoachHomePage extends ConsumerWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncToday = ref.watch(todaySessionsProvider);
    final name = ref.watch(authSessionProvider)?.fullName ?? 'Pembina';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Hari Ini'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(todaySessionsProvider.future),
        child: asyncToday.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Gagal memuat jadwal.\n$e', textAlign: TextAlign.center)),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(todaySessionsProvider),
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          ),
          data: (result) {
            if (result.sessions.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Text(
                      'Halo, $name.\nTidak ada jadwal ekskul untuk ${result.dayLabel} ini.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: result.sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _SessionCard(session: result.sessions[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final TodaySession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/coach/session/${session.extracurricularId}', extra: session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.extracurricularName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${session.startTime}–${session.endTime}'
                        '${session.location != null ? ' · ${session.location}' : ''}'),
                    Text('${session.memberCount} siswa',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              if (session.isSubmitted)
                const Chip(
                  label: Text('Sudah disubmit'),
                  backgroundColor: Color(0xFFDDF3EA),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
