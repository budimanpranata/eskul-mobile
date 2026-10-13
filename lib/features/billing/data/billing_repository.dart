import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/entities/billing_entities.dart';

abstract interface class BillingRepository {
  Future<List<Invoice>> invoices(String studentId);
  Future<InvoiceDetail> invoiceDetail(String invoiceId);

  /// [method] = 'TRANSFER' | 'CASH'. [proofFile] wajib untuk TRANSFER.
  Future<InvoiceDetail> pay(
    String invoiceId, {
    required String method,
    String? note,
    File? proofFile,
  });
}

class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<Invoice>> invoices(String studentId) async {
    final r = await _dio.get<List<dynamic>>(
      '/parent/billing/invoices',
      queryParameters: {'studentId': studentId},
    );
    final code = r.statusCode ?? 0;
    if (code != 200) throw _messageException(r);
    return (r.data ?? []).map((e) => Invoice.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<InvoiceDetail> invoiceDetail(String invoiceId) async {
    final r = await _dio.get<dynamic>('/parent/billing/invoices/$invoiceId');
    final code = r.statusCode ?? 0;
    if (code == 403 && r.data is Map && (r.data as Map)['error'] == 'UNAUTHORIZED_RELATION') {
      throw const UnauthorizedInvoiceException();
    }
    if (code != 200) throw _messageException(r);
    return InvoiceDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  @override
  Future<InvoiceDetail> pay(
    String invoiceId, {
    required String method,
    String? note,
    File? proofFile,
  }) async {
    final form = FormData.fromMap({
      'method': method,
      if (note != null && note.isNotEmpty) 'note': note,
      if (proofFile != null) 'file': await MultipartFile.fromFile(proofFile.path, filename: proofFile.path.split(Platform.pathSeparator).last),
    });
    final r = await _dio.post<dynamic>('/parent/billing/invoices/$invoiceId/pay', data: form);
    final code = r.statusCode ?? 0;
    if (code != 201 && code != 200) throw _messageException(r);
    return InvoiceDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Exception _messageException(Response<dynamic> r) {
    final data = r.data;
    if (data is Map) {
      if (data['error'] == 'VALIDATION_ERROR' && data['details'] is List) {
        return Exception((data['details'] as List).map((d) => (d as Map)['message']).join(', '));
      }
      if (data['message'] is String) return Exception(data['message'] as String);
    }
    return Exception('Permintaan gagal (HTTP ${r.statusCode}).');
  }
}

/// Relasi belum/tidak APPROVED utk siswa pemilik tagihan ini (403 UNAUTHORIZED_RELATION).
class UnauthorizedInvoiceException implements Exception {
  const UnauthorizedInvoiceException();
}
