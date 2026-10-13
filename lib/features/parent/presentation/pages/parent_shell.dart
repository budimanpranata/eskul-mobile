import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../billing/presentation/pages/billing_page.dart';
import '../../../notifications/notifications.dart';
import '../../../notifications/notifications_page.dart';
import 'parent_home_page.dart';

/// Kerangka mode Orang Tua: Dashboard + Tagihan + tab Notifikasi (badge unread).
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
        children: const [ParentHomePage(), BillingPage(), NotificationsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 2) {
            ref.invalidate(notificationsListProvider);
            ref.invalidate(unreadCountProvider);
          }
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Tagihan'),
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
