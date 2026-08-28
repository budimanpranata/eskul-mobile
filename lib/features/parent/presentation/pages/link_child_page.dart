import 'package:flutter/material.dart';

/// Layar "Hubungkan ke Anak" untuk akun ortu baru (dokumen desain bagian 5.2).
/// Input NIS + nama siswa → POST /parent/link-request → menunggu approval admin.
///
/// FASE 0: kerangka form. Submit & polling status diisi di Fase 1.4 / 2.4.
class LinkChildPage extends StatelessWidget {
  const LinkChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hubungkan ke Anak')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              enabled: false,
              decoration: InputDecoration(labelText: 'NIS Siswa', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            TextField(
              enabled: false,
              decoration: InputDecoration(labelText: 'Nama Siswa', border: OutlineInputBorder()),
            ),
            SizedBox(height: 24),
            FilledButton(onPressed: null, child: Text('Ajukan')),
          ],
        ),
      ),
    );
  }
}
