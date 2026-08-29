import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_storage.dart';

/// Registrasi token perangkat ke backend (`POST /notifications/devices`).
///
/// FASE 1.5: untuk sekarang memakai token stub per-instalasi (disimpan di secure
/// storage). Integrasi `firebase_messaging` menggantikan pembuatan token ini —
/// alur backend & UI notifikasi in-app sudah final.
Future<void> registerDeviceToken(Dio dio, SecureStorage storage) async {
  var token = await storage.deviceToken;
  if (token == null || token.isEmpty) {
    token = 'stub-${const Uuid().v4()}';
    await storage.saveDeviceToken(token);
  }
  final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  try {
    await dio.post<dynamic>('/notifications/devices', data: {'token': token, 'platform': platform});
  } catch (_) {
    // registrasi token bukan hal kritis; abaikan kegagalan.
  }
}
