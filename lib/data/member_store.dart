import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_service.dart';

/// The single Admin's UM Address (ADR 0003). The security rules seed the
/// forge-proof `isAdmin` flag from this same address; the app mirrors the
/// computation so the create write satisfies the rules.
const String kAdminEmail = 'l.murillo.546842@umindanao.edu.ph';

/// A member's account document — `members/{uid}` (ADR 0007).
class Member {
  const Member({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isAdmin = false,
    this.banned = false,
    this.blocked = const {},
  });

  final String uid;
  final String email;

  /// Derived from the UM Address (initial + surname, ADR 0007) — never
  /// contains the PII 6-digit ID.
  final String displayName;

  /// Seeded at create by the rules when the address matches [kAdminEmail].
  final bool isAdmin;

  /// Set by the Admin (ADR 0003); banned members cannot write anything.
  final bool banned;

  /// Members this account has blocked (CONTEXT: Block) — the rules stop
  /// blocked pairs from messaging.
  final Set<String> blocked;

  factory Member.fromDoc(String uid, Map<String, dynamic> data) {
    final blockedData = data['blocked'];
    return Member(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      isAdmin: data['isAdmin'] as bool? ?? false,
      banned: data['banned'] as bool? ?? false,
      blocked: blockedData is Map
          ? blockedData.keys.whereType<String>().toSet()
          : const {},
    );
  }
}

/// The member-account surface the UI depends on (injected, fake-able in
/// tests; no Firebase in widget tests).
abstract interface class MemberStore {
  /// Live member document; null while signed in but no account yet.
  Stream<Member?> memberChanges(String uid);

  /// Creates the Member Account if it does not exist yet (get-then-set,
  /// matching the create rule in firestore.rules). Returns the member.
  Future<Member?> ensureMemberAccount(AuthUser authUser);
}

class FirestoreMemberStore implements MemberStore {
  FirestoreMemberStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<Member?> memberChanges(String uid) {
    return _firestore
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : Member.fromDoc(snapshot.id, data);
    });
  }

  @override
  Future<Member?> ensureMemberAccount(AuthUser authUser) async {
    final doc = _firestore.collection('members').doc(authUser.uid);
    final existing = await doc.get();
    final data = existing.exists ? existing.data() : null;
    if (data != null) return Member.fromDoc(authUser.uid, data);

    // Shape must satisfy the member create rule: email == Google-verified
    // token email, isAdmin computed from the address, banned false, empty
    // blocked map.
    await doc.set({
      'uid': authUser.uid,
      'email': authUser.email,
      'displayName': authUser.displayName,
      'isAdmin': authUser.email == kAdminEmail,
      'banned': false,
      'blocked': <String, bool>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final created = await doc.get();
    return Member.fromDoc(authUser.uid, created.data()!);
  }
}