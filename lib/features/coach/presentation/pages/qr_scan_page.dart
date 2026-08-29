import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../domain/entities/coach_entities.dart';
import '../providers/coach_providers.dart';

/// Layar scan QR kartu siswa (dokumen desain bagian 5.1).
/// Tetap terbuka untuk scan beruntun; tiap kartu valid langsung set HADIR.
class QrScanPage extends ConsumerStatefulWidget {
  const QrScanPage({super.key, required this.extracurricularId});
  final String extracurricularId;

  @override
  ConsumerState<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends ConsumerState<QrScanPage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  String? _lastToken;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Overlay umpan balik.
  String? _flashMsg;
  bool _flashOk = true;
  int _scannedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    // Debounce token yang sama dalam 2 detik.
    final now = DateTime.now();
    if (raw == _lastToken && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _lastToken = raw;
    _lastAt = now;

    setState(() => _busy = true);
    try {
      final student = await ref.read(coachRepositoryProvider).resolveQr(
            qrToken: raw,
            extracurricularId: widget.extracurricularId,
          );
      ref
          .read(attendanceDraftsProvider.notifier)
          .setStatus(widget.extracurricularId, student.id, AttendanceStatus.hadir);
      await HapticFeedback.mediumImpact();
      unawaited(SystemSound.play(SystemSoundType.click));
      _scannedCount++;
      _showFlash('✓ ${student.fullName} — Hadir', ok: true);
    } on QrScanException catch (e) {
      await HapticFeedback.heavyImpact();
      _showFlash('✕ ${e.message}', ok: false);
    } catch (e) {
      _showFlash('✕ Gagal: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFlash(String msg, {required bool ok}) {
    if (!mounted) return;
    setState(() {
      _flashMsg = msg;
      _flashOk = ok;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _flashMsg == msg) setState(() => _flashMsg = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Kartu Siswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // bingkai bidik
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (_flashMsg != null)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _flashOk ? const Color(0xE61E6F5C) : const Color(0xE6B0402F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_flashMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            bottom: 32,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: Text('Selesai ($_scannedCount ter-scan)'),
            ),
          ),
        ],
      ),
    );
  }
}
