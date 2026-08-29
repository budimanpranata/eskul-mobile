import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications.dart';

/// Tab Notifikasi (dokumen desain bagian 5.2).
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    void refresh() {
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadCountProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: () async {
              await repo.markAllRead();
              refresh();
            },
            child: const Text('Tandai semua dibaca'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(unreadCountProvider);
          ref.invalidate(notificationsListProvider);
          await ref.read(notificationsListProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('Gagal memuat notifikasi.\n$e', textAlign: TextAlign.center)),
          ]),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('Belum ada notifikasi.')),
              ]);
            }
            return ListView.separated(
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = page.items[i];
                return ListTile(
                  tileColor: n.isRead ? null : const Color(0xFFE9F4F0),
                  leading: Icon(
                    n.isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: n.isRead ? Colors.grey : const Color(0xFF1E6F5C),
                  ),
                  title: Text(n.title,
                      style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
                  subtitle: Text([
                    if (n.body != null) n.body!,
                    _fmt(n.sentAt),
                  ].join('\n')),
                  isThreeLine: n.body != null,
                  onTap: n.isRead
                      ? null
                      : () async {
                          await repo.markRead([n.id]);
                          refresh();
                        },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
