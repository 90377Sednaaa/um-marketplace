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

  /// One-shot member read (self-read is always allowed; other members are
  /// not readable by design — use denormalized names across boundaries).
  Future<Member?> fetchMember(String uid);

  /// Creates the Member Account if it does not exist yet (get-then-set,
  /// matching the create rule in firestore.rules). Returns the member.
  Future<Member?> ensureMemberAccount(AuthUser authUser);

  /// Admin: member lookup by display-name prefix (ADRs 0003/0007 — names
  /// are public-safe; the full UM email stays admin/self-only).
  Stream<List<Member>> searchMembers(String displayNamePrefix);

  /// Admin: flips the banned flag (the rules restrict the update to the
  /// banned field only).
  Future<void> setBanned(String uid, bool banned);
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
  Future<Member?> fetchMember(String uid) async {
    final doc = _firestore.collection('members').doc(uid);
    final snapshot = await doc.get();
    final data = snapshot.data();
    return data == null ? null : Member.fromDoc(snapshot.id, data);
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

  @override
  Stream<List<Member>> searchMembers(String displayNamePrefix) {
    final prefix = displayNamePrefix.trim();
    if (prefix.isEmpty) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('members')
        .where('displayName', isGreaterThanOrEqualTo: prefix)
        .where('displayName', isLessThan: '$prefix\uf8ff')
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Member.fromDoc(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<void> setBanned(String uid, bool banned) async {
    await _firestore.collection('members').doc(uid).update({
      'banned': banned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}