import 'package:cloud_firestore/cloud_firestore.dart';

/// A Rating (ADR 0004): one vote per party per completed deal, doc id
/// `{listingId}_{raterId}` — the rules validate the deal (`isCompletedDeal`:
/// chat matches the listing, listing is sold, parties are the chat's
/// buyer/seller) and stars 1–5; ratings are immutable and publicly
/// readable (they are the market's trust signal).
class Rating {
  const Rating({
    required this.listingId,
    required this.raterId,
    required this.rateeId,
    required this.stars,
    required this.chatId,
    this.createdAt,
  });

  final String listingId;
  final String raterId;
  final String rateeId;
  final int stars;
  final String chatId;
  final DateTime? createdAt;

  factory Rating.fromDoc(String id, Map<String, dynamic> data) {
    return Rating(
      listingId: data['listingId'] as String? ?? '',
      raterId: data['raterId'] as String? ?? '',
      rateeId: data['rateeId'] as String? ?? '',
      stars: (data['stars'] as num?)?.toInt() ?? 0,
      chatId: data['chatId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The DESIGN.md seller-strip/profile line: `★ 4.5 · 2 trades`, or the
/// placeholder while a member has no completed-deal ratings yet. Trade
/// count = ratings received (ADR 0004 approximation: a deal counts only
/// when the other party rated).
String ratingSummaryText(List<Rating> ratings) {
  if (ratings.isEmpty) return '★ — · no trades yet';
  final avg =
      ratings.map((r) => r.stars).reduce((a, b) => a + b) / ratings.length;
  final count = ratings.length;
  return '★ ${avg.toStringAsFixed(1)} · $count ${count == 1 ? 'trade' : 'trades'}';
}

/// The ratings surface the UI depends on (injected, fake-able in tests).
abstract interface class RatingStore {
  /// All ratings a member received, newest first (public trust signal —
  /// feeds the Profile card and seller strips).
  Stream<List<Rating>> ratingsFor(String rateeId);

  /// The rater's own vote on a listing (doc id is deterministic and
  /// ratings are immutable, so a one-shot read is enough).
  Future<Rating?> myRatingFor(String listingId, String raterId);

  /// Casts a vote; the rules reject invalid deals and double votes.
  Future<void> rate({
    required String listingId,
    required String chatId,
    required String raterId,
    required String rateeId,
    required int stars,
  });
}

class FirestoreRatingStore implements RatingStore {
  FirestoreRatingStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Rating>> ratingsFor(String rateeId) {
    return _firestore
        .collection('ratings')
        .where('rateeId', isEqualTo: rateeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Rating.fromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<Rating?> myRatingFor(String listingId, String raterId) async {
    final doc = _firestore.collection('ratings').doc('${listingId}_$raterId');
    final snapshot = await doc.get();
    return snapshot.exists
        ? Rating.fromDoc(snapshot.id, snapshot.data()!)
        : null;
  }

  @override
  Future<void> rate({
    required String listingId,
    required String chatId,
    required String raterId,
    required String rateeId,
    required int stars,
  }) async {
    await _firestore.collection('ratings').doc('${listingId}_$raterId').set({
      'listingId': listingId,
      'raterId': raterId,
      'rateeId': rateeId,
      'stars': stars,
      'chatId': chatId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
