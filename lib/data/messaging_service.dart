import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// The FCM lifecycle surface (ADR 0005): register the device for a member
/// (permission, channel, token upsert, refresh), unregister on sign-out.
/// Widget tests inject a fake so the plugin is never touched in tests.
abstract interface class MessagingService {
  /// Call after the Member Account exists (MemberGate).
  Future<void> registerForMember(String uid);

  /// Call before signing out: cancels listeners and deletes the device doc.
  Future<void> unregister();
}

class FirestoreMessagingService implements MessagingService {
  FirestoreMessagingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _uid;
  String? _token;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _refreshSub;

  Future<void> _upsertToken(String uid, String token) async {
    await _firestore
        .collection('members')
        .doc(uid)
        .collection('devices')
        .doc(token)
        .set(
      {
        'token': token,
        'ownerId': uid,
        'platform': 'android',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> registerForMember(String uid) async {
    _uid = uid;
    try {
      await _messaging.requestPermission();
    } catch (_) {
      // Permission request unavailable or denied — the center still works.
    }
    // The 'deals' channel (manifest default_notification_channel_id) is
    // created by the FCM SDK itself on the first push — no Android-specific
    // plugin API needed.
    final token = await _messaging.getToken();
    _token = token;
    if (token != null) {
      await _upsertToken(uid, token);
    }
    _refreshSub ??= _messaging.onTokenRefresh.listen((refreshed) async {
      _token = refreshed;
      await _upsertToken(uid, refreshed);
    });
    _messageSub ??= FirebaseMessaging.onMessage.listen((_) {
      // Foreground banner intentionally absent (ADR 0005 stage cut): the
      // notification center is stream-fed and updates live instead.
    });
  }

  @override
  Future<void> unregister() async {
    await _messageSub?.cancel();
    await _refreshSub?.cancel();
    _messageSub = null;
    _refreshSub = null;
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    if (uid != null && token != null) {
      try {
        await _firestore
            .collection('members')
            .doc(uid)
            .collection('devices')
            .doc(token)
            .delete();
      } catch (_) {
        // Best-effort cleanup; the token record prunes itself server-side.
      }
    }
  }
}