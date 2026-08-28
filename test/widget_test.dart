import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:um_marketplace/app.dart';
import 'package:um_marketplace/auth/auth_service.dart';
import 'package:um_marketplace/data/listing_store.dart';
import 'package:um_marketplace/data/member_store.dart';

/// In-memory [AuthService] so widget tests never touch Firebase.
class FakeAuthService implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> get userChanges => _controller.stream;

  void emit(AuthUser? user) => _controller.add(user);

  @override
  Future<void> signInWithGoogle() async {
    emit(_student);
  }

  @override
  Future<void> signOut() async => emit(null);
}

/// In-memory [MemberStore]: ensure creates the member and emits it, like
/// the Firestore implementation does for a missing document. Streams are
/// kept per uid so a listing detail can resolve a seller separately from
/// the signed-in viewer.
class FakeMemberStore implements MemberStore {
  final _controllers = <String, StreamController<Member?>>{};
  final ensuredUids = <String>[];

  StreamController<Member?> _for(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<Member?>.broadcast);

  @override
  Stream<Member?> memberChanges(String uid) => _for(uid).stream;

  void emit(Member? member) => _for(member?.uid ?? 'unknown').add(member);

  @override
  Future<Member?> ensureMemberAccount(AuthUser authUser) async {
    ensuredUids.add(authUser.uid);
    final member = Member(
      uid: authUser.uid,
      email: authUser.email,
      displayName: authUser.displayName,
    );
    emit(member);
    return member;
  }
}

class FakeListingsStore implements ListingStore {
  final _controller = StreamController<List<Listing>>.broadcast();
  final _listingControllers = <String, StreamController<Listing?>>{};
  final drafts = <ListingDraft>[];
  List<Listing> listings = [];

  StreamController<Listing?> _listingFor(String id) =>
      _listingControllers.putIfAbsent(id, StreamController<Listing?>.broadcast);

  @override
  Stream<List<Listing>> activeListingsStream() => _controller.stream;

  @override
  Stream<Listing?> listingChanges(String id) => _listingFor(id).stream;

  void emitListing(String id, Listing? listing) => _listingFor(id).add(listing);

  void emitListings() => _controller.add(List.of(listings));

  @override
  Future<void> createListing(String sellerId, ListingDraft draft) async {
    drafts.add(draft);
  }
}

const _student = AuthUser(
  uid: 'test-uid',
  email: 'l.murillo.546842@umindanao.edu.ph',
  displayName: 'L. Murillo',
);

Widget _app({
  FakeAuthService? auth,
  FakeMemberStore? members,
  FakeListingsStore? listings,
}) {
  return UmMarketplaceApp(
    authService: auth ?? FakeAuthService(),
    memberStore: members ?? FakeMemberStore(),
    listingsStore: listings ?? FakeListingsStore(),
  );
}

void main() {
  testWidgets('shows the Google sign-in gate when signed out',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('UM Marketplace'), findsOneWidget);
    expect(
      find.textContaining('l.murillo.546842@umindanao.edu.ph'),
      findsOneWidget,
    );
  });

  testWidgets('sign-in creates the member account and lands on home',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    listings.emitListings();
    await tester.pumpAndSettle();

    expect(members.ensuredUids, ['test-uid']);
    expect(find.text('L. Murillo'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget);
    expect(find.text('Recent listings'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('a banned member is shown the banned screen (ADR 0003)',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    members.emit(
      const Member(
        uid: 'test-uid',
        email: 'l.murillo.546842@umindanao.edu.ph',
        displayName: 'L. Murillo',
        banned: true,
      ),
    );
    listings.emitListings();
    await tester.pumpAndSettle();

    expect(find.text('This account has been banned'), findsOneWidget);
    expect(find.text('Recent listings'), findsNothing);
  });

  testWidgets('home feed shows listings with formatted prices',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 's',
          title: 'Calculus 201 textbook',
          description: '',
          price: 1250,
          category: 'textbooks',
          condition: 'good',
        ),
        const Listing(
          id: 'b',
          sellerId: 's',
          title: 'Mechanical keyboard',
          description: '',
          price: 249.9,
          category: 'gadgets',
          condition: 'like new',
          location: 'Matina',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    expect(find.text('Calculus 201 textbook'), findsOneWidget);
    expect(find.text('₱1,250'), findsOneWidget);
    expect(find.text('Mechanical keyboard'), findsOneWidget);
    expect(find.text('₱250'), findsOneWidget);
  });

  /// Detail-screen tests use a tall portrait surface so the whole layout
  /// (hero, body, seller strip, safety tips, action bar) is on screen.
  void usePortraitPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('tapping a listing card opens its detail screen',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        Listing(
          id: 'a',
          sellerId: 'seller-uid',
          title: 'Analytical Geometry notes',
          description: 'Complete set, minimal highlights.',
          price: 180,
          category: 'textbooks',
          condition: 'good',
          location: 'Matina',
          photos: [Uint8List.fromList([1]), Uint8List.fromList([2])],
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analytical Geometry notes'));
    await tester.pumpAndSettle();

    expect(find.text('₱180'), findsOneWidget);
    expect(find.text('Analytical Geometry notes'), findsOneWidget);
    expect(find.text('Complete set, minimal highlights.'), findsOneWidget);
    expect(find.text('textbooks'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget); // photo count chip
    expect(find.text('Safety tips'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Make an offer'), findsOneWidget);
  });

  testWidgets('the seller strip resolves the member with trust cues',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'seller-uid',
          title: 'Dorm lamp',
          description: 'USB powered.',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    members.emit(const Member(
      uid: 'seller-uid',
      email: 'j.delacruz.000000@umindanao.edu.ph',
      displayName: 'J. Dela Cruz',
    ));
    await tester.pumpAndSettle();

    expect(find.text('J. Dela Cruz'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget);
    expect(find.text('★ — · no trades yet'), findsOneWidget);
  });

  testWidgets('a missing seller document falls back to a generic name',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'seller-uid',
          title: 'Dorm lamp',
          description: '',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();

    expect(find.text('UM student'), findsOneWidget);
    expect(find.text('Verified UM student'), findsNothing);
  });

  testWidgets('viewing your own listing hides the chat/offer bar',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'test-uid',
          title: 'My old headphones',
          description: '',
          price: 450,
          category: 'gadgets',
          condition: 'good',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My old headphones'));
    await tester.pumpAndSettle();

    expect(find.text('This is your listing'), findsOneWidget);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Make an offer'), findsNothing);
  });

  testWidgets('chat and offer actions are inert with a coming-soon note',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'seller-uid',
          title: 'Dorm lamp',
          description: '',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Make an offer'));
    await tester.pump();
    expect(find.textContaining('Chats are coming soon'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pump();
    expect(find.textContaining('Chats are coming soon'), findsOneWidget);

    // Let the snackbar timers expire before the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a listing without photos shows the placeholder, no count chip',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'seller-uid',
          title: 'Old notes',
          description: '',
          price: 50,
          category: 'review materials',
          condition: 'fair',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Old notes'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('1/2'), findsNothing);
  });

  testWidgets('a sold listing shows the SOLD sticker on the hero photo',
      (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'seller-uid',
          title: 'Sold mug',
          description: '',
          price: 120,
          category: 'dorm essentials',
          condition: 'good',
          status: 'sold',
        ),
      ];
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sold mug'));
    await tester.pumpAndSettle();

    expect(find.text('SOLD'), findsOneWidget);
  });

  testWidgets('sell flow validates, publishes and records the draft',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sell something'));
    await tester.pumpAndSettle();

    // Invalid publish surfaces the first problem.
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish listing'));
    await tester.pump();
    expect(find.textContaining('Give it a short title'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextField).at(0));
    await tester.enterText(find.byType(TextField).at(0), 'Calculus notes');
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.enterText(find.byType(TextField).at(1), '250');
    await tester.ensureVisible(find.text('textbooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('textbooks'));
    await tester.pump();
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();

    expect(find.text('Recent listings'), findsOneWidget); // back on home
    expect(listings.drafts, hasLength(1));
    expect(listings.drafts.single.title, 'Calculus notes');
    expect(listings.drafts.single.price, 250.0);
    expect(listings.drafts.single.category, 'textbooks');
  });

  testWidgets('signing out returns to the gate', (WidgetTester tester) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester
        .pumpWidget(_app(auth: auth, members: members, listings: listings));
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  test('kMaxListingPhotos is 2 to stay inside the Firestore document limit',
      () {
    expect(kMaxListingPhotos, 2);
    expect(kListingCategories, contains('review materials'));
    expect(kListingCategories, hasLength(5));
    expect(kListingConditions, hasLength(4));
  });

  test('Uint8List photos round-trip through Listing.fromDoc', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final listing = Listing.fromDoc('x', {
      'sellerId': 's',
      'title': 'T',
      'price': 50,
      'category': 'gadgets',
      'condition': 'good',
      'photos': [bytes],
    });
    expect(listing.photos.single, bytes);
    expect(listing.status, 'active');
  });
}