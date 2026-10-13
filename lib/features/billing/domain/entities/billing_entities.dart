/// Status tagihan (`backend/src/modules/billing/dto/billing.dto.ts`).
enum InvoiceStatus { unpaid, pendingVerification, paid, cancelled }

InvoiceStatus _statusFromJson(String s) => switch (s) {
      'PAID' => InvoiceStatus.paid,
      'PENDING_VERIFICATION' => InvoiceStatus.pendingVerification,
      'CANCELLED' => InvoiceStatus.cancelled,
      _ => InvoiceStatus.unpaid,
    };

enum PaymentMethod { transfer, cash }

enum PaymentStatus { pending, approved, rejected }

PaymentStatus _paymentStatusFromJson(String s) => switch (s) {
      'APPROVED' => PaymentStatus.approved,
      'REJECTED' => PaymentStatus.rejected,
      _ => PaymentStatus.pending,
    };

class InvoiceStudent {
  const InvoiceStudent({required this.id, required this.nis, required this.fullName, required this.classGrade});

  final String id;
  final String nis;
  final String fullName;
  final String classGrade;

  factory InvoiceStudent.fromJson(Map<String, dynamic> j) => InvoiceStudent(
        id: j['id'] as String,
        nis: j['nis'] as String,
        fullName: j['fullName'] as String,
        classGrade: j['classGrade'] as String,
      );
}

class LatestPayment {
  const LatestPayment({required this.id, required this.method, required this.status, required this.submittedAt});

  final String id;
  final PaymentMethod method;
  final PaymentStatus status;
  final String submittedAt;

  factory LatestPayment.fromJson(Map<String, dynamic> j) => LatestPayment(
        id: j['id'] as String,
        method: (j['method'] as String) == 'TRANSFER' ? PaymentMethod.transfer : PaymentMethod.cash,
        status: _paymentStatusFromJson(j['status'] as String),
        submittedAt: j['submittedAt'] as String,
      );
}

/// Satu tagihan ekskul untuk satu siswa (`GET /parent/billing/invoices`).
class Invoice {
  const Invoice({
    required this.id,
    required this.period,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.notes,
    required this.student,
    required this.extracurricularName,
    required this.latestPayment,
  });

  final String id;
  final String period;
  final String title;
  final int amount;
  final String? dueDate;
  final InvoiceStatus status;
  final String? notes;
  final InvoiceStudent student;
  final String? extracurricularName;
  final LatestPayment? latestPayment;

  bool get isPayable => status == InvoiceStatus.unpaid;

  factory Invoice.fromJson(Map<String, dynamic> j) {
    final ek = j['extracurricular'] as Map<String, dynamic>?;
    final lp = j['latestPayment'] as Map<String, dynamic>?;
    return Invoice(
      id: j['id'] as String,
      period: j['period'] as String,
      title: j['title'] as String,
      amount: (j['amount'] as num).toInt(),
      dueDate: j['dueDate'] as String?,
      status: _statusFromJson(j['status'] as String),
      notes: j['notes'] as String?,
      student: InvoiceStudent.fromJson(j['student'] as Map<String, dynamic>),
      extracurricularName: ek?['name'] as String?,
      latestPayment: lp == null ? null : LatestPayment.fromJson(lp),
    );
  }
}

/// Satu baris riwayat pengajuan pembayaran pada detail tagihan.
class PaymentEntry {
  const PaymentEntry({
    required this.id,
    required this.method,
    required this.status,
    required this.note,
    required this.submittedAt,
    required this.rejectionReason,
  });

  final String id;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? note;
  final String submittedAt;
  final String? rejectionReason;

  factory PaymentEntry.fromJson(Map<String, dynamic> j) => PaymentEntry(
        id: j['id'] as String,
        method: (j['method'] as String) == 'TRANSFER' ? PaymentMethod.transfer : PaymentMethod.cash,
        status: _paymentStatusFromJson(j['status'] as String),
        note: j['note'] as String?,
        submittedAt: j['submittedAt'] as String,
        rejectionReason: j['rejectionReason'] as String?,
      );
}

/// `GET /parent/billing/invoices/:id` — tagihan + riwayat pembayaran lengkap.
class InvoiceDetail {
  const InvoiceDetail({required this.invoice, required this.payments});

  final Invoice invoice;
  final List<PaymentEntry> payments;

  factory InvoiceDetail.fromJson(Map<String, dynamic> j) => InvoiceDetail(
        invoice: Invoice.fromJson(j),
        payments: ((j['payments'] as List?) ?? const [])
            .map((e) => PaymentEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
