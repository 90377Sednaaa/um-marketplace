import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Fixed category set (CONTEXT: Category) used by Home tiles, filtering
/// and the Sell flow.
const List<String> kListingCategories = [
  'textbooks',
  'gadgets',
  'org merch',
  'dorm essentials',
  'review materials',
];

const List<String> kListingConditions = ['new', 'like new', 'good', 'fair'];

/// Photos live inside the Listing document (ADR 0006); two compressed
/// photos stay comfortably under the 1 MiB document limit by design.
const int kMaxListingPhotos = 2;

/// How many active listings the Browse screen fetches to filter
/// client-side (Firestore cannot substring-search text fields).
const int kBrowseFetchLimit = 200;

/// Client-side filter state for Browse (DESIGN.md screen 2). All fields
/// are null = no constraint; category/condition use the fixed sets from
/// [kListingCategories]/[kListingConditions].
class BrowseFilters {
  const BrowseFilters({
    this.category,
    this.condition,
    this.minPrice,
    this.maxPrice,
  });

  final String? category;
  final String? condition;
  final double? minPrice;
  final double? maxPrice;

  bool get isActive =>
      category != null ||
      condition != null ||
      minPrice != null ||
      maxPrice != null;

  BrowseFilters copyWith({String? category, String? condition}) {
    return BrowseFilters(
      category: category ?? this.category,
      condition: condition ?? this.condition,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }
}

/// Filters listings client-side for Browse: case-insensitive substring on
/// title + description, equality on category/condition, inclusive price
/// range. Input order is preserved (the stream arrives newest-first).
List<Listing> filterListings(
  List<Listing> listings, {
  required String query,
  BrowseFilters filters = const BrowseFilters(),
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final listing in listings)
      if (_matches(listing, q, filters)) listing,
  ];
}

bool _matches(Listing listing, String query, BrowseFilters filters) {
  if (query.isNotEmpty &&
      !listing.title.toLowerCase().contains(query) &&
      !listing.description.toLowerCase().contains(query)) {
    return false;
  }
  if (filters.category != null && listing.category != filters.category) {
    return false;
  }
  if (filters.condition != null && listing.condition != filters.condition) {
    return false;
  }
  if (filters.minPrice != null && listing.price < filters.minPrice!) {
    return false;
  }
  if (filters.maxPrice != null && listing.price > filters.maxPrice!) {
    return false;
  }
  return true;
}

/// A Listing document (ADR 0007, `listings/{id}`).
class Listing {
  const Listing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    this.sellerDisplayName = '',
    this.location,
    this.photos = const [],
    this.status = 'active',
    this.createdAt,
  });

  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String category;
  final String condition;

  /// Public display name, denormalized at create (rules validate it
  /// against the seller's member doc) — the seller strip reads it without
  /// crossing the members read boundary (ADR 0007).
  final String sellerDisplayName;
  final String? location;
  final List<Uint8List> photos;

  /// 'active' | 'sold' | 'hidden' — the seller's terminal states.
  final String status;
  final DateTime? createdAt;

  factory Listing.fromDoc(String id, Map<String, dynamic> data) {
    return Listing(
      id: id,
      sellerId: data['sellerId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num? ?? 0).toDouble(),
      category: data['category'] as String? ?? '',
      condition: data['condition'] as String? ?? '',
      sellerDisplayName: data['sellerDisplayName'] as String? ?? '',
      location: data['location'] as String?,
      photos: (data['photos'] as List<dynamic>? ?? const [])
          .whereType<Uint8List>()
          .toList(),
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// The seller's input when creating a Listing.
class ListingDraft {
  const ListingDraft({
    required this.title,
    required this.price,
    required this.category,
    required this.condition,
    required this.sellerDisplayName,
    this.description = '',
    this.location,
    this.photos = const [],
  });

  final String title;
  final double price;
  final String category;
  final String condition;
  final String sellerDisplayName;
  final String description;
  final String? location;
  final List<Uint8List> photos;

  Map<String, dynamic> toData() {
    return {
      'title': title,
      'price': price,
      'category': category,
      'condition': condition,
      'description': description,
      'sellerDisplayName': sellerDisplayName,
      if (location != null && location!.isNotEmpty) 'location': location,
      'photos': photos,
    };
  }
}

/// The listings surface the UI depends on (injected, fake-able in tests).
abstract interface class ListingStore {
  /// Recent active listings for the Home feed (realtime). Browse fetches
  /// a larger window ([kBrowseFetchLimit]) and filters client-side.
  Stream<List<Listing>> activeListingsStream({int limit = 20});

  /// All of the seller's own listings, newest first (realtime) — the
  /// Profile "my listings" list; the rules let sellers read their own
  /// sold/hidden rows too.
  Stream<List<Listing>> myListingsStream(String sellerId);

  /// Live single-listing watch (get-then-listen): the thread screen uses
  /// it for the pinned snippet and the status banner.
  Stream<Listing?> listingChanges(String id);

  /// Publishes a new Listing as the given seller (rules require an
  /// existing, unbanned member account for the seller).
  Future<void> createListing(String sellerId, ListingDraft draft);

  /// Flips a listing to the terminal 'sold' state (CONTEXT: Sold; the
  /// rules allow the seller that transition from 'active').
  Future<void> markSold(String listingId);

  /// Admin: hides every active listing of a member (the ban flow uses it
  /// so a banned member's listings disappear, CONTEXT: Ban). Returns the
  /// number of listings hidden.
  Future<int> hideAllListingsOf(String sellerId);
}

class FirestoreListingsStore implements ListingStore {
  FirestoreListingsStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Listing>> activeListingsStream({int limit = 20}) {
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Listing.fromDoc(doc.id, doc.data()))
            .toList());
  }

  @override
  Stream<Listing?> listingChanges(String id) {
    return _firestore
        .collection('listings')
        .doc(id)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? Listing.fromDoc(snapshot.id, snapshot.data()!)
            : null);
  }

  @override
  Stream<List<Listing>> myListingsStream(String sellerId) {
    return _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Listing.fromDoc(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<void> markSold(String listingId) async {
    await _firestore.collection('listings').doc(listingId).update({
      'status': 'sold',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<int> hideAllListingsOf(String sellerId) async {
    final snapshot = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'active')
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': 'hidden',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  @override
  Future<void> createListing(String sellerId, ListingDraft draft) async {
    await _firestore.collection('listings').add({
      ...draft.toData(),
      'sellerId': sellerId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}