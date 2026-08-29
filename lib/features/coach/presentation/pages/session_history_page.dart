import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_session_store.dart';
import '../providers/coach_providers.dart';

/// Layar "Riwayat Sesi" (dokumen desain bagian 5.1) — badge status per sesi.
class SessionHistoryPage extends ConsumerWidget {
  const SessionHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Sesi'),
        actions: [
          TextButton(
            onPressed: () async {
              final report = await ref.read(manualSyncProvider)();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Sinkron: ${report.synced} terkirim, '
                      '${report.stillPending} masih menunggu.'),
                ));
              }
            },
            child: const Text('Sinkronkan'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingSessionsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('Belum ada sesi tersimpan di perangkat.')),
              ]);
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = rows[i];
                return ListTile(
                  title: Text(s.extracurricularName ?? s.extracurricularId),
                  subtitle: Text([
                    s.sessionDate,
                    if (s.attemptCount > 0) 'percobaan sync: ${s.attemptCount}',
                    if (s.lastError != null) 'terakhir: ${s.lastError}',
                  ].join(' · ')),
                  isThreeLine: s.lastError != null,
                  trailing: _StatusBadge(s.status),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SyncStatus.draft => ('Draft', const Color(0xFF6B7280)),
      SyncStatus.pendingSync => ('Pending Sync', const Color(0xFFB07C2F)),
      SyncStatus.synced => ('Synced', const Color(0xFF1E6F5C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
