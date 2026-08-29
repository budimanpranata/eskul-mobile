import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> r) =>
    r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);

/// `true` bila perangkat kemungkinan online (heuristik connectivity_plus).
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();
  yield _isOnline(await conn.checkConnectivity());
  yield* conn.onConnectivityChanged.map(_isOnline);
});

/// Cek satu-kali (dipakai sebelum submit).
Future<bool> isDeviceOnline() async => _isOnline(await Connectivity().checkConnectivity());
