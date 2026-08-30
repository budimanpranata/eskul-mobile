import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/coach_providers.dart';

const _kPrimary = Color(0xFF1E6F5C);
const _kBg = Color(0xFFF4F6F5);

/// Tab Profil untuk mode Pembina — identitas akun + ringkasan + keluar.
class CoachProfilePage extends ConsumerWidget {
  const CoachProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final meAsync = ref.watch(authMeProvider);
    final summaryAsync = ref.watch(coachSummaryProvider);
    final name = session?.fullName ?? 'Pembina';
    final me = meAsync.value ?? const {};
    final email = (me['email'] as String?) ?? '-';
    final phone = (me['phoneNumber'] as String?) ?? '-';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(title: const Text('Profil')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(authMeProvider);
          ref.invalidate(coachSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _kPrimary.withValues(alpha: 0.15),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700, color: _kPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Pembina',
                        style: TextStyle(
                            color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _Section(
              title: 'Akun',
              child: Column(
                children: [
                  _InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
                  const Divider(height: 1),
                  _InfoRow(icon: Icons.phone_outlined, label: 'No. HP', value: phone),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _Section(
              title: 'Ringkasan',
              child: summaryAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const _InfoRow(
                  icon: Icons.info_outline,
                  label: 'Status',
                  value: 'Tidak tersedia saat offline',
                ),
                data: (s) => Column(
                  children: [
                    _InfoRow(
                        icon: Icons.groups_2_outlined,
                        label: 'Total murid',
                        value: '${s.totalStudents}'),
                    const Divider(height: 1),
                    _InfoRow(
                        icon: Icons.sports_kabaddi_outlined,
                        label: 'Ekskul diampu',
                        value: '${s.totalExtracurriculars}'),
                    const Divider(height: 1),
                    _InfoRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Jadwal / minggu',
                        value: '${s.weeklySchedules}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout, color: Color(0xFFB0402F)),
              label: const Text('Keluar', style: TextStyle(color: Color(0xFFB0402F))),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Color(0xFFE0B4AC)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu login kembali untuk mengakses sesi latihan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(authSessionProvider.notifier).logout();
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAE8)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
