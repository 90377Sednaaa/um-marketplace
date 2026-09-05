import 'package:cloud_firestore/cloud_firestore.dart';

/// A member-visible notification (CONTEXT: Notification, ADR 0005 —
/// `notifications/{id}`, owner-gated; deliveries are written server-side
/// by Cloud Functions, reads are the member's own).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String ownerId;

  /// 'offer' | 'message' | 'sold' | 'rating' — the v1 event set.
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      type: data['type'] as String? ?? 'message',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The notifications surface the UI depends on (injected, fake-able in
/// tests). Stage 1 is read-side only: the bell count and the center;
/// event generation lands with the FCM/Functions stage (ADR 0005).
abstract interface class NotificationStore {
  /// The member's notifications, newest first (realtime).
  Stream<List<AppNotification>> notificationsStream(String ownerId);

  /// Marks one notification read (self-owned update, rule-permitted).
  Future<void> markRead(String id);
}

class FirestoreNotificationStore implements NotificationStore {
  FirestoreNotificationStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppNotification>> notificationsStream(String ownerId) {
    return _firestore
        .collection('notifications')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> markRead(String id) async {
    await _firestore.collection('notifications').doc(id).update({
      'read': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
