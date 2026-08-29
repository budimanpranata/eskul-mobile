import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/parent_providers.dart';

/// Layar "Hubungkan ke Anak" (dokumen desain bagian 5.2).
class LinkChildPage extends ConsumerStatefulWidget {
  const LinkChildPage({super.key});

  @override
  ConsumerState<LinkChildPage> createState() => _LinkChildPageState();
}

class _LinkChildPageState extends ConsumerState<LinkChildPage> {
  final _nis = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _nis.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(parentRepositoryProvider).linkRequest(
            nis: _nis.text.trim(),
            studentName: _name.text.trim(),
          );
      ref.invalidate(childrenProvider);
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hubungkan ke Anak')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _submitted
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_top, size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Pengajuan terkirim.\nMenunggu persetujuan admin sekolah.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Masukkan NIS dan nama siswa persis seperti data sekolah.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nis,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'NIS Siswa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nama Siswa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading || _nis.text.trim().isEmpty || _name.text.trim().isEmpty
                        ? null
                        : _submit,
                    child: Text(_loading ? 'Mengirim…' : 'Ajukan'),
                  ),
                ],
              ),
      ),
    );
  }
}
