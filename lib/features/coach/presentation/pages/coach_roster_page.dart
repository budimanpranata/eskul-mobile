import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/coach_providers.dart';

const _kPrimary = Color(0xFF1E6F5C);
const _kBg = Color(0xFFF4F6F5);

/// Daftar siswa sebuah ekskul + rekap ringkas. Ketuk siswa → perkembangannya.
class CoachRosterPage extends ConsumerWidget {
  const CoachRosterPage({super.key, required this.extracurricularId, required this.name});
  final String extracurricularId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ekskulStudentsProvider(extracurricularId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ekskulStudentsProvider(extracurricularId));
          await ref.read(ekskulStudentsProvider(extracurricularId).future).catchError((_) => throw '');
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => context.push('/coach/session/$extracurricularId'),
              icon: const Icon(Icons.checklist),
              label: const Text('Mulai / Lanjutkan Presensi'),
            ),
            const SizedBox(height: 18),
            const Text('Anggota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Ketuk siswa untuk melihat kehadiran & penilaian selama ini.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _Card(
                child: Column(children: [
                  const Text('Gagal memuat daftar siswa.', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(ekskulStudentsProvider(extracurricularId)),
                    child: const Text('Coba lagi'),
                  ),
                ]),
              ),
              data: (roster) {
                if (roster.students.isEmpty) {
                  return const _Card(child: Text('Belum ada siswa terdaftar di ekskul ini.'));
                }
                return Column(
                  children: [
                    for (final s in roster.students) ...[
                      _StudentTile(
                        name: s.fullName,
                        subtitle:
                            'Kelas ${s.classGrade}  ·  ${s.sessions} sesi  ·  Hadir ${s.attendancePct.toStringAsFixed(0)}%',
                        avgActiveness: s.avgActiveness,
                        onTap: () => context.push(
                          '/coach/ekskul/$extracurricularId/student/${s.id}',
                          extra: s.fullName,
                        ),
                      ),
                      const SizedBox(height: 8),
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

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.name,
    required this.subtitle,
    required this.avgActiveness,
    required this.onTap,
  });
  final String name;
  final String subtitle;
  final double? avgActiveness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EAE8)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE4EFEA),
                child: Text(name.characters.first.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF155440), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              if (avgActiveness != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EFEA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(avgActiveness!.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF155440))),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EAE8)),
        ),
        child: child,
      );
}
