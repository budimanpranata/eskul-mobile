import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/coach_providers.dart';
import 'coach_home_page.dart';
import 'coach_profile_page.dart';
import 'coach_scan_tab.dart';

/// Kerangka mode Pembina: Beranda (dashboard) · Scan QR · Profil.
class CoachShell extends ConsumerStatefulWidget {
  const CoachShell({super.key});

  @override
  ConsumerState<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends ConsumerState<CoachShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(syncSchedulerProvider); // mesin sinkron offline aktif di semua tab

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CoachHomePage(),
          CoachScanTab(),
          CoachProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 0 || i == 1) {
            ref.invalidate(todaySessionsProvider);
          }
          if (i == 0 || i == 2) {
            ref.invalidate(coachSummaryProvider);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
