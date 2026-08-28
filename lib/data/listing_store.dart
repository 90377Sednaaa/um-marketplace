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
    this.description = '',
    this.location,
    this.photos = const [],
  });

  final String title;
  final double price;
  final String category;
  final String condition;
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
      if (location != null && location!.isNotEmpty) 'location': location,
      'photos': photos,
    };
  }
}

/// The listings surface the UI depends on (injected, fake-able in tests).
abstract interface class ListingStore {
  /// Recent active listings for the Home feed (realtime).
  Stream<List<Listing>> activeListingsStream();

  /// Live single-listing watch (get-then-listen): the thread screen uses
  /// it for the pinned snippet and the status banner.
  Stream<Listing?> listingChanges(String id);

  /// Publishes a new Listing as the given seller (rules require an
  /// existing, unbanned member account for the seller).
  Future<void> createListing(String sellerId, ListingDraft draft);
}

class FirestoreListingsStore implements ListingStore {
  FirestoreListingsStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Listing>> activeListingsStream() {
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(20)
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