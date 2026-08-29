import 'package:dio/dio.dart';

import '../domain/entities/coach_entities.dart';

/// Hasil upaya submit (online / offline / gagal validasi).
sealed class SubmitOutcome {}

class SubmitSynced extends SubmitOutcome {
  SubmitSynced(this.result);
  final SubmitResult result;
}

/// Server menjawab 409 — sudah pernah tersinkron. Diperlakukan sebagai sukses.
class SubmitAlreadySynced extends SubmitOutcome {
  SubmitAlreadySynced(this.serverSessionId);
  final String? serverSessionId;
}

/// Offline atau koneksi putus → disimpan lokal (PENDING_SYNC).
class SubmitQueuedOffline extends SubmitOutcome {}

/// Interpretasi response `/attendance/submit` untuk dipakai submit langsung & SyncEngine.
sealed class SubmitInterpretation {}

class InterpretedSynced extends SubmitInterpretation {
  InterpretedSynced(this.result);
  final SubmitResult result;
}

class InterpretedAlreadySynced extends SubmitInterpretation {
  InterpretedAlreadySynced(this.serverSessionId);
  final String? serverSessionId;
}

class InterpretedValidationError extends SubmitInterpretation {
  InterpretedValidationError(this.exception);
  final SubmitValidationException exception;
}

/// 5xx / bentuk tak terduga — layak di-retry.
class InterpretedRetryable extends SubmitInterpretation {
  InterpretedRetryable(this.message);
  final String message;
}

SubmitInterpretation interpretSubmitResponse(Response<dynamic> res) {
  final code = res.statusCode ?? 0;
  final body = res.data;

  if (code == 201) {
    return InterpretedSynced(SubmitResult.fromJson(Map<String, dynamic>.from(body as Map)));
  }
  if (code == 409) {
    final map = body is Map ? body : const {};
    return InterpretedAlreadySynced(map['existing_session_id'] as String?);
  }
  if (code == 422 && body is Map && body['details'] is List) {
    final details = (body['details'] as List)
        .map((e) => (
              field: (e as Map)['field'] as String? ?? '',
              message: e['message'] as String? ?? 'Tidak valid',
            ))
        .toList();
    return InterpretedValidationError(SubmitValidationException(details));
  }
  return InterpretedRetryable('HTTP $code');
}
