import 'package:cloud_firestore/cloud_firestore.dart';

/// A Report (CONTEXT: Report, ADR 0003): a verified member records what
/// they saw and why; only the Admin may read or act on reports. The rules
/// require `reporterId == auth.uid`, `status == 'open'`, a non-empty
/// reason, and at least one target (reportedUid / listingId / chatId).
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.status,
    required this.reason,
    this.reportedUid,
    this.listingId,
    this.chatId,
    this.createdAt,
  });

  final String id;
  final String reporterId;

  /// 'open' | 'resolved' — the Admin resolves reports after acting.
  final String status;
  final String reason;
  final String? reportedUid;
  final String? listingId;
  final String? chatId;
  final DateTime? createdAt;

  factory Report.fromDoc(String id, Map<String, dynamic> data) {
    return Report(
      id: id,
      reporterId: data['reporterId'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      reason: data['reason'] as String? ?? '',
      reportedUid: data['reportedUid'] as String?,
      listingId: data['listingId'] as String?,
      chatId: data['chatId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The reports surface the UI depends on (injected, fake-able in tests).
abstract interface class ReportStore {
  /// Open reports, newest first — Admin only (the read rule gates it).
  Stream<List<Report>> openReportsStream();

  /// Files a report; the rules require one target and a non-empty reason.
  Future<void> submitReport({
    required String reporterId,
    required String reason,
    String? reportedUid,
    String? listingId,
    String? chatId,
  });

  /// Marks a report resolved (after the Admin acts on it).
  Future<void> resolveReport(String reportId);
}

class FirestoreReportStore implements ReportStore {
  FirestoreReportStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Report>> openReportsStream() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Report.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> submitReport({
    required String reporterId,
    required String reason,
    String? reportedUid,
    String? listingId,
    String? chatId,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'status': 'open',
      'reason': reason,
      'reportedUid': ?reportedUid,
      'listingId': ?listingId,
      'chatId': ?chatId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> resolveReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'resolved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
