import 'package:flutter/material.dart';

/// Layar Sesi Ekskul — Tab "Presensi Cepat" + Tab "Materi Latihan"
/// (dokumen desain bagian 5.1).
///
/// FASE 0: hanya kerangka tab. Logic presensi (cycle status, scan QR,
/// expand nilai keaktifan) dan submit diisi di Fase 1.3 / 2.x.
class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sesi Ekskul'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Presensi Cepat'),
              Tab(text: 'Materi Latihan'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Tab Presensi — Fase 1.3')),
            Center(child: Text('Tab Materi Latihan — Fase 1.3')),
          ],
        ),
        bottomNavigationBar: const Padding(
          padding: EdgeInsets.all(12),
          child: FilledButton(
            onPressed: null,
            child: Text('Submit Presensi & Materi'),
          ),
        ),
      ),
    );
  }
}
