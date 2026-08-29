import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Pendaftaran mandiri Orang Tua (dokumen desain bagian 5.2).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _relationType = 'IBU';
  bool _consent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider.notifier).registerParent(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phoneNumber: _phone.text.trim(),
            password: _password.text,
            relationType: _relationType,
            consent: _consent,
          );
      // redirect go_router menangani navigasi ke /parent.
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty &&
        _email.text.trim().contains('@') &&
        _password.text.length >= 8 &&
        _consent;

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar sebagai Orang Tua')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nama lengkap', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'No. HP (opsional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            onChanged: (_) => setState(() {}),
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (min. 8 karakter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _relationType,
            decoration: const InputDecoration(labelText: 'Hubungan', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'AYAH', child: Text('Ayah')),
              DropdownMenuItem(value: 'IBU', child: Text('Ibu')),
              DropdownMenuItem(value: 'WALI', child: Text('Wali')),
            ],
            onChanged: (v) => setState(() => _relationType = v ?? 'IBU'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            title: const Text(
              'Saya menyetujui pengumpulan & penggunaan data anak saya untuk keperluan ekstrakurikuler.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading || !valid ? null : _submit,
            child: Text(_loading ? 'Memproses…' : 'Daftar'),
          ),
        ],
      ),
    );
  }
}
