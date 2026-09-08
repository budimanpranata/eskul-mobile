import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/coach_entities.dart';
import '../providers/coach_providers.dart';

const _kPrimary = Color(0xFF1E6F5C);
const _kBg = Color(0xFFF4F6F5);

/// Beranda Pembina — dashboard ringkas + jadwal latihan hari ini (dokumen desain 5.1).
class CoachHomePage extends ConsumerWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncSchedulerProvider); // aktifkan mesin sinkron offline
    final online = ref.watch(connectivityProvider).value ?? true;
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;
    final name = ref.watch(authSessionProvider)?.fullName ?? 'Pembina';
    final summaryAsync = ref.watch(coachSummaryProvider);
    final todayAsync = ref.watch(todaySessionsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Beranda Pembina'),
        actions: [
          IconButton(
            tooltip: 'Riwayat Sesi',
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.history),
            ),
            onPressed: () => context.push('/coach/history'),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authSessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coachSummaryProvider);
          ref.invalidate(todaySessionsProvider);
          try {
            await ref.read(todaySessionsProvider.future);
          } catch (_) {/* biarkan UI menampilkan state error */}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            if (!online)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Mode offline — Anda tetap bisa melakukan presensi. Data akan '
                  'disinkronkan otomatis saat online.',
                  style: TextStyle(color: Color(0xFF7A5B00), fontSize: 13),
                ),
              ),

            // -------- kartu sambutan --------
            _GreetingCard(name: name, dayLabel: summaryAsync.value?.dayLabel),
            const SizedBox(height: 16),

            // -------- menu / statistik ringkas --------
            summaryAsync.when(
              loading: () => const _StatGridSkeleton(),
              error: (_, __) => const _StatUnavailable(),
              data: (s) => _StatGrid(summary: s),
            ),
            const SizedBox(height: 24),

            // -------- jadwal latihan hari ini --------
            Row(
              children: [
                const Icon(Icons.event_note, size: 20, color: _kPrimary),
                const SizedBox(width: 8),
                const Text('Jadwal Latihan Hari Ini',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (todayAsync.value != null)
                  Text('${todayAsync.value!.sessions.length} sesi',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorTile(
                message: 'Gagal memuat jadwal.',
                onRetry: () => ref.invalidate(todaySessionsProvider),
              ),
              data: (result) {
                if (result.sessions.isEmpty) {
                  return _EmptyToday(dayLabel: result.dayLabel);
                }
                return Column(
                  children: [
                    for (final s in result.sessions) ...[
                      _SessionCard(session: s),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ kartu sambutan ------------------------------ */
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name, this.dayLabel});
  final String name;
  final String? dayLabel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tanggal = '${now.day}/${now.month}/${now.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, Color(0xFF2E9C82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selamat datang,',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 2),
          Text(name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            [if (dayLabel != null && dayLabel!.isNotEmpty) dayLabel, tanggal].join(', '),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/* --------------------------- grid statistik/menu --------------------------- */
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});
  final CoachSummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTile(
        icon: Icons.groups_2,
        label: 'Total Murid',
        value: '${summary.totalStudents}',
        color: const Color(0xFF2F6FB0),
      ),
      _StatTile(
        icon: Icons.sports_kabaddi,
        label: 'Ekskul Diampu',
        value: '${summary.totalExtracurriculars}',
        color: _kPrimary,
      ),
      _StatTile(
        icon: Icons.calendar_month,
        label: 'Jadwal / Minggu',
        value: '${summary.weeklySchedules}',
        color: const Color(0xFF7A5AB0),
      ),
      _StatTile(
        icon: Icons.assignment_late_outlined,
        label: 'Perlu Disubmit',
        value: '${summary.pendingSubmitToday}',
        color: summary.pendingSubmitToday > 0
            ? const Color(0xFFB0402F)
            : Colors.grey.shade500,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: tiles,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAE8)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGridSkeleton extends StatelessWidget {
  const _StatGridSkeleton();
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6EAE8)),
            ),
          ),
        ),
      );
}

class _StatUnavailable extends StatelessWidget {
  const _StatUnavailable();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EAE8)),
        ),
        child: const Text('Ringkasan tidak tersedia saat offline.',
            style: TextStyle(color: Colors.black54, fontSize: 13)),
      );
}

/* ------------------------------ kartu sesi ------------------------------ */
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final TodaySession session;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          '/coach/ekskul/${session.extracurricularId}/students',
          extra: session.extracurricularName,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAE8)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(session.startTime,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: _kPrimary, fontSize: 13)),
                    Text(session.endTime,
                        style: const TextStyle(color: Colors.black45, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.extracurricularName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      '${session.memberCount} siswa'
                      '${session.location != null ? ' · ${session.location}' : ''}',
                      style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (session.isSubmitted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF3EA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: _kPrimary),
                      SizedBox(width: 4),
                      Text('Disubmit',
                          style: TextStyle(
                              color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.dayLabel});
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAE8)),
      ),
      child: Column(
        children: [
          Icon(Icons.free_breakfast_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('Tidak ada jadwal ekskul untuk hari $dayLabel.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAE8)),
      ),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
