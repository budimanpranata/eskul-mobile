import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/notifications.dart';
import '../../../notifications/notifications_page.dart';
import 'parent_home_page.dart';

/// Kerangka mode Orang Tua: Dashboard + tab Notifikasi (badge unread).
class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [ParentHomePage(), NotificationsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) {
            ref.invalidate(notificationsListProvider);
            ref.invalidate(unreadCountProvider);
          }
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Notifikasi',
          ),
        ],
      ),
    );
  }
}
