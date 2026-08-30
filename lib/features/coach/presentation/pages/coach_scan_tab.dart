import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coach_providers.dart';
import 'qr_scan_page.dart';

const _kPrimary = Color(0xFF1E6F5C);
const _kBg = Color(0xFFF4F6F5);

/// Tab "Scan QR" — pilih sesi latihan lebih dulu, lalu buka kamera pemindai.
/// Pemindaian butuh konteks ekskul (resolveQr) + draft presensi per-ekskul.
class CoachScanTab extends ConsumerWidget {
  const CoachScanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todaySessionsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(title: const Text('Scan QR')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaySessionsProvider);
          try {
            await ref.read(todaySessionsProvider.future);
          } catch (_) {/* biarkan UI menampilkan error */}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: _kPrimary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pilih sesi latihan, lalu pindai kartu QR tiap siswa. '
                      'Setiap kartu valid langsung ditandai Hadir.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF3B5B52)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Sesi Latihan Hari Ini',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _Card(
                child: Column(
                  children: [
                    const Text('Gagal memuat jadwal.', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(todaySessionsProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result.sessions.isEmpty) {
                  return _Card(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada sesi untuk hari ${result.dayLabel}.\n'
                          'Buka scanner lewat halaman sesi bila perlu.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final s in result.sessions) ...[
                      _ScanTile(
                        name: s.extracurricularName,
                        subtitle: '${s.startTime}–${s.endTime}'
                            '${s.location != null ? ' · ${s.location}' : ''}'
                            ' · ${s.memberCount} siswa',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QrScanPage(extracurricularId: s.extracurricularId),
                          ),
                        ),
                      ),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EAE8)),
        ),
        child: child,
      );
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.name, required this.subtitle, required this.onTap});
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAE8)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner, color: _kPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
