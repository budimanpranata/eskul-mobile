import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../parent/domain/entities/parent_entities.dart';
import '../../../parent/presentation/providers/parent_providers.dart';
import '../../domain/entities/billing_entities.dart';
import '../providers/billing_providers.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

const _accent = Color(0xFF1E6F5C);

(String, Color) _statusLook(InvoiceStatus s) => switch (s) {
      InvoiceStatus.unpaid => ('Belum Bayar', const Color(0xFF64748B)),
      InvoiceStatus.pendingVerification => ('Menunggu Verifikasi', const Color(0xFFB07C2F)),
      InvoiceStatus.paid => ('Lunas', _accent),
      InvoiceStatus.cancelled => ('Dibatalkan', const Color(0xFFB0402F)),
    };

/// Tab "Tagihan" — mode Orang Tua: lihat & bayar tagihan ekskul anak.
class BillingPage extends ConsumerWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tagihan Ekskul')),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat data.\n$e', textAlign: TextAlign.center)),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Hubungkan akun ke anak terlebih dahulu di tab Dashboard.', textAlign: TextAlign.center),
              ),
            );
          }
          final selectedId = ref.watch(selectedChildProvider) ?? children.first.id;
          final active = children.firstWhere((c) => c.id == selectedId, orElse: () => children.first);
          return Column(
            children: [
              if (children.length > 1) _ChildSelector(children: children, selectedId: active.id),
              Expanded(child: _InvoiceList(studentId: active.id, studentName: active.fullName)),
            ],
          );
        },
      ),
    );
  }
}

class _ChildSelector extends ConsumerWidget {
  const _ChildSelector({required this.children, required this.selectedId});
  final List<Child> children;
  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = children[i];
          return ChoiceChip(
            selected: c.id == selectedId,
            label: Text(c.fullName.split(' ').first),
            onSelected: (_) => ref.read(selectedChildProvider.notifier).select(c.id),
          );
        },
      ),
    );
  }
}

class _InvoiceList extends ConsumerWidget {
  const _InvoiceList({required this.studentId, required this.studentName});
  final String studentId;
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider(studentId));

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(invoicesProvider(studentId).future),
      child: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Gagal memuat tagihan.\n$e', textAlign: TextAlign.center),
            ),
          ],
        ),
        data: (invoices) {
          if (invoices.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Belum ada tagihan untuk anak ini.', textAlign: TextAlign.center)),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, i) => _InvoiceCard(invoice: invoices[i], studentId: studentId),
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.studentId});
  final Invoice invoice;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusLook(invoice.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openDetail(context, invoice.id, studentId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(invoice.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              ),
              if (invoice.extracurricularName != null) ...[
                const SizedBox(height: 2),
                Text(invoice.extracurricularName!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_idr.format(invoice.amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('Periode ${invoice.period}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              if (invoice.dueDate != null) ...[
                const SizedBox(height: 2),
                Text('Jatuh tempo: ${invoice.dueDate}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String invoiceId, String studentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InvoiceDetailSheet(invoiceId: invoiceId, studentId: studentId),
    );
  }
}

class _InvoiceDetailSheet extends ConsumerWidget {
  const _InvoiceDetailSheet({required this.invoiceId, required this.studentId});
  final String invoiceId;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat detail.\n$e')),
        data: (detail) {
          final inv = detail.invoice;
          final (label, color) = _statusLook(inv.status);
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(inv.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (inv.extracurricularName != null) Text(inv.extracurricularName!, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_idr.format(inv.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Periode ${inv.period}${inv.dueDate != null ? ' · Jatuh tempo ${inv.dueDate}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(inv.notes!, style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const Divider(height: 32),
              const Text('Riwayat Pengajuan Pembayaran', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (detail.payments.isEmpty)
                const Text('Belum ada pengajuan pembayaran.', style: TextStyle(color: Colors.black54))
              else
                for (final p in detail.payments) _PaymentHistoryTile(payment: p),
              const SizedBox(height: 20),
              if (inv.isPayable)
                FilledButton.icon(
                  icon: const Icon(Icons.payment),
                  label: const Text('Bayar Sekarang'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _PayForm(invoiceId: invoiceId, studentId: studentId),
                    );
                  },
                )
              else if (inv.status == InvoiceStatus.pendingVerification)
                const Text(
                  'Pengajuan pembayaran sedang menunggu verifikasi admin sekolah.',
                  style: TextStyle(color: Colors.black54),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({required this.payment});
  final PaymentEntry payment;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (payment.status) {
      PaymentStatus.approved => 'Disetujui',
      PaymentStatus.rejected => 'Ditolak',
      PaymentStatus.pending => 'Menunggu',
    };
    final statusColor = switch (payment.status) {
      PaymentStatus.approved => _accent,
      PaymentStatus.rejected => const Color(0xFFB0402F),
      PaymentStatus.pending => const Color(0xFFB07C2F),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(payment.method == PaymentMethod.transfer ? 'Transfer' : 'Tunai', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          if (payment.note != null && payment.note!.isNotEmpty)
            Text('"${payment.note}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
          if (payment.rejectionReason != null)
            Text('Alasan: ${payment.rejectionReason}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ],
      ),
    );
  }
}

class _PayForm extends ConsumerStatefulWidget {
  const _PayForm({required this.invoiceId, required this.studentId});
  final String invoiceId;
  final String studentId;

  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  String _method = 'TRANSFER';
  final _note = TextEditingController();
  File? _proof;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked != null) setState(() => _proof = File(picked.path));
  }

  Future<void> _submit() async {
    if (_method == 'TRANSFER' && _proof == null) {
      setState(() => _error = 'Unggah bukti transfer terlebih dahulu.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(billingRepositoryProvider).pay(
            widget.invoiceId,
            method: _method,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            proofFile: _proof,
          );
      ref.invalidate(invoicesProvider(widget.studentId));
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan pembayaran terkirim. Menunggu verifikasi admin.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajukan Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'TRANSFER', label: Text('Transfer'), icon: Icon(Icons.account_balance)),
              ButtonSegment(value: 'CASH', label: Text('Tunai'), icon: Icon(Icons.payments)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() {
              _method = s.first;
              if (_method == 'CASH') _proof = null;
            }),
          ),
          const SizedBox(height: 14),
          if (_method == 'TRANSFER') ...[
            const Text('Bukti Transfer', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_proof != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_proof!, height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Bayar tunai langsung ke admin/pembina sekolah, lalu ajukan di sini agar tercatat dan divalidasi admin.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Mengirim…' : 'Kirim Pengajuan'),
          ),
        ],
      ),
    );
  }
}
