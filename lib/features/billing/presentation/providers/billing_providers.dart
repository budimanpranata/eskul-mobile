import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/billing_repository.dart';
import '../../domain/entities/billing_entities.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepositoryImpl(ref.watch(dioProvider));
});

/// GET /parent/billing/invoices?studentId= — tagihan anak yang sedang dipilih.
final invoicesProvider =
    FutureProvider.autoDispose.family<List<Invoice>, String>((ref, studentId) {
  return ref.watch(billingRepositoryProvider).invoices(studentId);
});

final invoiceDetailProvider =
    FutureProvider.autoDispose.family<InvoiceDetail, String>((ref, invoiceId) {
  return ref.watch(billingRepositoryProvider).invoiceDetail(invoiceId);
});
