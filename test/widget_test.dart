import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:um_marketplace/app.dart';
import 'package:um_marketplace/auth/auth_service.dart';
import 'package:um_marketplace/auth/sign_in_screen.dart' show SignInScreen;
import 'package:um_marketplace/chats/chat_thread_screen.dart';
import 'package:um_marketplace/chats/chats_screen.dart';
import 'package:um_marketplace/data/chat_store.dart';
import 'package:um_marketplace/data/listing_store.dart';
import 'package:um_marketplace/data/member_store.dart';
import 'package:um_marketplace/data/messaging_service.dart';
import 'package:um_marketplace/data/notification_store.dart';
import 'package:um_marketplace/data/rating_store.dart';
import 'package:um_marketplace/data/report_store.dart';
import 'package:um_marketplace/home/browse_screen.dart';
import 'package:um_marketplace/home/home_screen.dart';
import 'package:um_marketplace/home/listing_card.dart';
import 'package:um_marketplace/members/member_gate.dart';
import 'package:um_marketplace/moderation/moderation_screen.dart';
import 'package:um_marketplace/notifications/notification_center_screen.dart';
import 'package:um_marketplace/theme/app_theme.dart';
import 'package:um_marketplace/widgets/brutal_app_bar.dart';
import 'package:um_marketplace/widgets/brutal_confirm_dialog.dart';
import 'package:um_marketplace/widgets/brutal_dialog.dart';
import 'package:um_marketplace/widgets/brutal_page_route.dart';
import 'package:um_marketplace/widgets/brutal_shimmer.dart';
import 'package:um_marketplace/widgets/listing_detail_skeleton.dart';
import 'package:um_marketplace/widgets/product_card_skeleton.dart';
import 'package:um_marketplace/widgets/dot_grid.dart';
import 'package:um_marketplace/widgets/um_logo.dart';

typedef _MemberSplash = MemberSplash;

/// Test canvas for recording circle drawing calls.
class _RecordingCanvas extends Fake implements Canvas {
  final List<Offset> circles = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add(c);
  }
}

/// In-memory [AuthService] so widget tests never touch Firebase.
class FakeAuthService implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();
  Object? signInError;
  int signOutCallCount = 0;

  @override
  Stream<AuthUser?> get userChanges => _controller.stream;

  void emit(AuthUser? user) => _controller.add(user);

  @override
  Future<void> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    emit(_student);
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    emit(null);
  }
}

/// In-memory [MemberStore]: ensure creates the member and emits it, like
/// the Firestore implementation does for a missing document. Streams are
/// kept per uid so a listing detail can resolve a seller separately from
/// the signed-in viewer.
class FakeMemberStore implements MemberStore {
  final _controllers = <String, StreamController<Member?>>{};
  final ensuredUids = <String>[];
  final accounts = <String, Member>{};
  final knownMembers = <String, Member>{};
  final bannedUids = <String, bool>{};
  final _searchController = StreamController<List<Member>>.broadcast();
  Object? ensureError;
  Duration? ensureDelay;

  void emitError(String uid, Object error) => _for(uid).addError(error);

  StreamController<Member?> _for(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<Member?>.broadcast);

  @override
  Stream<Member?> memberChanges(String uid) => _for(uid).stream;

  @override
  Future<Member?> fetchMember(String uid) async => accounts[uid];

  void emit(Member? member) => _for(member?.uid ?? 'unknown').add(member);

  @override
  Stream<List<Member>> searchMembers(String displayNamePrefix) {
    final matches = knownMembers.values
        .where(
          (m) => m.displayName.toLowerCase().startsWith(
            displayNamePrefix.toLowerCase(),
          ),
        )
        .take(20)
        .toList();
    return Stream<List<Member>>.value(matches).asBroadcastStream();
  }

  void emitSearch(String prefix) {
    final matches = knownMembers.values
        .where(
          (m) => m.displayName.toLowerCase().startsWith(prefix.toLowerCase()),
        )
        .take(20)
        .toList();
    _searchController.add(matches);
  }

  @override
  Future<void> setBanned(String uid, bool banned) async {
    bannedUids[uid] = banned;
    final known = knownMembers[uid];
    if (known != null) {
      final updated = Member(
        uid: known.uid,
        email: known.email,
        displayName: known.displayName,
        isAdmin: known.isAdmin,
        banned: banned,
        blocked: known.blocked,
      );
      knownMembers[uid] = updated;
      _for(uid).add(updated);
    }
  }

  @override
  Future<Member?> ensureMemberAccount(AuthUser authUser) async {
    if (ensureDelay != null) {
      await Future<void>.delayed(ensureDelay!);
    }
    if (ensureError != null) throw ensureError!;
    ensuredUids.add(authUser.uid);
    final member = Member(
      uid: authUser.uid,
      email: authUser.email,
      displayName: authUser.displayName,
    );
    accounts[authUser.uid] = member;
    emit(member);
    return member;
  }
}

/// In-memory [ChatStore]: deterministic find-or-create is honored, sends
/// append messages + update the chat doc (like the Firestore batch), and
/// streams emit on mutation. Failure flags drive the error-path tests.
class FakeChatStore implements ChatStore {
  final chats = <String, Chat>{};
  final messages = <String, List<ChatMessage>>{};
  final _listController = StreamController<List<Chat>>.broadcast();
  final _messageControllers = <String, StreamController<List<ChatMessage>>>{};
  bool failOpen = false;
  ChatOpenFailure openFailure = ChatOpenFailure.rejected;
  bool failSend = false;
  int _messageSeq = 0;

  StreamController<List<ChatMessage>> _for(String chatId) => _messageControllers
      .putIfAbsent(chatId, StreamController<List<ChatMessage>>.broadcast);

  @override
  Stream<List<Chat>> myChatsStream(String uid) => _listController.stream;

  @override
  Stream<List<ChatMessage>> chatMessagesStream(String chatId) =>
      _for(chatId).stream;

  void emitList() => _listController.add(chats.values.toList());

  void emitMessages(String chatId) =>
      _for(chatId).add(List.of(messages[chatId] ?? const []));

  @override
  Future<Chat> openChatWithBuyer({
    required Listing listing,
    required String buyerUid,
    required String buyerDisplayName,
  }) async {
    if (failOpen) throw ChatOpenException(openFailure);
    final id = chatIdFor(listing.id, buyerUid);
    final existing = chats[id];
    if (existing != null) return existing;
    final chat = Chat(
      id: id,
      listingId: listing.id,
      sellerId: listing.sellerId,
      buyerId: buyerUid,
      participants: {listing.sellerId, buyerUid},
      buyerName: buyerDisplayName,
      sellerName: listing.sellerDisplayName,
    );
    chats[id] = chat;
    emitList();
    return chat;
  }

  @override
  Future<void> sendText(
    Chat chat, {
    required String senderId,
    required String text,
  }) async {
    if (failSend) throw ChatSendException();
    _append(
      chat,
      ChatMessage(
        id: 'm${_messageSeq++}',
        senderId: senderId,
        type: 'text',
        text: text,
        createdAt: DateTime(2026, 8, 28, 12),
      ),
    );
  }

  @override
  Future<void> sendOffer(
    Chat chat, {
    required String senderId,
    required double price,
    String text = '',
  }) async {
    if (failSend) throw ChatSendException();
    _append(
      chat,
      ChatMessage(
        id: 'm${_messageSeq++}',
        senderId: senderId,
        type: 'offer',
        text: text,
        price: price,
        createdAt: DateTime(2026, 8, 28, 12),
      ),
    );
  }

  void _append(Chat chat, ChatMessage message) {
    // Mirrors the Firestore batch: message appended and the chat doc's
    // preview/timestamp updated, then both streams emit.
    final list = messages.putIfAbsent(chat.id, () => []);
    list.add(message);
    chats[chat.id] = Chat(
      id: chat.id,
      listingId: chat.listingId,
      sellerId: chat.sellerId,
      buyerId: chat.buyerId,
      participants: chat.participants,
      lastMessagePreview: chatPreview(message),
      lastMessageAt: message.createdAt,
    );
    emitMessages(chat.id);
    emitList();
  }
}

/// In-memory [MessagingService]: records registration and unregistration
/// so widget tests never touch the FCM plugin.
class FakeMessagingService implements MessagingService {
  final registeredUids = <String>[];
  int unregisterCalls = 0;

  @override
  Future<void> registerForMember(String uid) async {
    registeredUids.add(uid);
  }

  @override
  Future<void> unregister() async {
    unregisterCalls += 1;
  }
}

/// In-memory [NotificationStore]: emits the seeded list on demand;
/// markRead flips the flag and re-emits.
class FakeNotificationStore implements NotificationStore {
  final notifications = <AppNotification>[];
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final readIds = <String>[];

  @override
  Stream<List<AppNotification>> notificationsStream(String ownerId) =>
      _controller.stream;

  void emit() => _controller.add(List.of(notifications));

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    final index = notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      final n = notifications[index];
      notifications[index] = AppNotification(
        id: n.id,
        ownerId: n.ownerId,
        type: n.type,
        title: n.title,
        body: n.body,
        read: true,
        createdAt: n.createdAt,
      );
    }
    emit();
  }
}

/// In-memory [ReportStore]: submissions are recorded raw; open reports
/// stream live and resolve removes.
class FakeReportStore implements ReportStore {
  final reports = <Report>[];
  final _openController = StreamController<List<Report>>.broadcast();
  final submitted = <Map<String, dynamic>>[];

  @override
  Stream<List<Report>> openReportsStream() => _openController.stream;

  void emitOpen() => _openController.add(List.of(reports));

  @override
  Future<void> submitReport({
    required String reporterId,
    required String reason,
    String? reportedUid,
    String? listingId,
    String? chatId,
  }) async {
    submitted.add({
      'reporterId': reporterId,
      'reason': reason,
      'reportedUid': reportedUid,
      'listingId': listingId,
      'chatId': chatId,
    });
    reports.add(
      Report(
        id: 'r${reports.length}',
        reporterId: reporterId,
        status: 'open',
        reason: reason,
        reportedUid: reportedUid,
        listingId: listingId,
        chatId: chatId,
        createdAt: DateTime(2026, 8, 28, 12),
      ),
    );
    emitOpen();
  }

  @override
  Future<void> resolveReport(String reportId) async {
    reports.removeWhere((r) => r.id == reportId);
    emitOpen();
  }
}

/// In-memory [RatingStore]: deterministic doc ids mirror the rule; the
/// rate stream is per ratee; failRate injects rule rejections.
class FakeRatingStore implements RatingStore {
  final ratings = <String, Rating>{};
  final _controllers = <String, StreamController<List<Rating>>>{};
  bool failRate = false;

  StreamController<List<Rating>> _for(String uid) =>
      _controllers.putIfAbsent(uid, StreamController<List<Rating>>.broadcast);

  @override
  Stream<List<Rating>> ratingsFor(String rateeId) => _for(rateeId).stream;

  void emitRatingsFor(String uid) =>
      _for(uid).add(ratings.values.where((r) => r.rateeId == uid).toList());

  @override
  Future<Rating?> myRatingFor(String listingId, String raterId) async =>
      ratings['${listingId}_$raterId'];

  @override
  Future<void> rate({
    required String listingId,
    required String chatId,
    required String raterId,
    required String rateeId,
    required int stars,
  }) async {
    if (failRate) throw Exception('rules rejection');
    ratings['${listingId}_$raterId'] = Rating(
      listingId: listingId,
      raterId: raterId,
      rateeId: rateeId,
      stars: stars,
      chatId: chatId,
      createdAt: DateTime(2026, 8, 28, 12),
    );
  }
}

class FakeListingsStore implements ListingStore {
  final _controller = StreamController<List<Listing>>.broadcast();
  final _myListingsController = StreamController<List<Listing>>.broadcast();
  final _listingControllers = <String, StreamController<Listing?>>{};
  final drafts = <ListingDraft>[];
  final soldIds = <String>[];
  final cancelledIds = <String>[];
  final hiddenIds = <String>[];
  final hiddenFor = <String>[];
  List<Listing> listings = [];

  StreamController<Listing?> _listingFor(String id) =>
      _listingControllers.putIfAbsent(id, StreamController<Listing?>.broadcast);

  @override
  Stream<List<Listing>> activeListingsStream({int limit = 20}) =>
      _controller.stream;

  List<Listing>? _lastMyListings;

  @override
  Stream<List<Listing>> myListingsStream(String sellerId) {
    return Stream<List<Listing>>.multi((controller) {
      if (_lastMyListings != null) {
        controller.add(_lastMyListings!);
      }
      final sub = _myListingsController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    }, isBroadcast: true);
  }

  @override
  Stream<Listing?> listingChanges(String id) => _listingFor(id).stream;

  void emitListing(String id, Listing? listing) => _listingFor(id).add(listing);

  void emitListings() => _controller.add(List.of(listings));

  void emitMyListings() {
    _lastMyListings = List.of(listings);
    _myListingsController.add(_lastMyListings!);
  }

  @override
  Future<void> markSold(String listingId) async {
    soldIds.add(listingId);
    final index = listings.indexWhere((l) => l.id == listingId);
    if (index >= 0) {
      final l = listings[index];
      listings[index] = Listing(
        id: l.id,
        sellerId: l.sellerId,
        title: l.title,
        description: l.description,
        price: l.price,
        category: l.category,
        condition: l.condition,
        sellerDisplayName: l.sellerDisplayName,
        location: l.location,
        photos: l.photos,
        status: 'sold',
        createdAt: l.createdAt,
      );
    }
    emitListings();
    emitMyListings();
  }

  @override
  Future<void> cancelListing(String listingId) async {
    cancelledIds.add(listingId);
    final index = listings.indexWhere((l) => l.id == listingId);
    if (index >= 0) {
      final l = listings[index];
      listings[index] = Listing(
        id: l.id,
        sellerId: l.sellerId,
        title: l.title,
        description: l.description,
        price: l.price,
        category: l.category,
        condition: l.condition,
        sellerDisplayName: l.sellerDisplayName,
        location: l.location,
        photos: l.photos,
        status: 'cancelled',
        createdAt: l.createdAt,
      );
    }
    emitListings();
    emitMyListings();
  }

  @override
  Future<void> hideListing(String listingId) async {
    hiddenIds.add(listingId);
    final index = listings.indexWhere((l) => l.id == listingId);
    if (index >= 0) {
      final l = listings[index];
      listings[index] = Listing(
        id: l.id,
        sellerId: l.sellerId,
        title: l.title,
        description: l.description,
        price: l.price,
        category: l.category,
        condition: l.condition,
        sellerDisplayName: l.sellerDisplayName,
        location: l.location,
        photos: l.photos,
        status: 'hidden',
        createdAt: l.createdAt,
      );
    }
    emitListings();
    emitMyListings();
  }

  @override
  Future<int> hideAllListingsOf(String sellerId) async {
    var count = 0;
    for (var i = 0; i < listings.length; i++) {
      final l = listings[i];
      if (l.sellerId == sellerId && l.status == 'active') {
        listings[i] = Listing(
          id: l.id,
          sellerId: l.sellerId,
          title: l.title,
          description: l.description,
          price: l.price,
          category: l.category,
          condition: l.condition,
          sellerDisplayName: l.sellerDisplayName,
          location: l.location,
          photos: l.photos,
          status: 'hidden',
          createdAt: l.createdAt,
        );
        count++;
        hiddenIds.add(l.id);
      }
    }
    hiddenFor.add(sellerId);
    emitListings();
    emitMyListings();
    return count;
  }

  @override
  Future<void> createListing(String sellerId, ListingDraft draft) async {
    drafts.add(draft);
  }

  @override
  Future<Listing?> fetchListing(String id) async {
    try {
      return listings.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
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
  FakeChatStore? chats,
  FakeRatingStore? ratings,
  FakeReportStore? reports,
  FakeNotificationStore? notifications,
  FakeMessagingService? messaging,
}) {
  return UmMarketplaceApp(
    authService: auth ?? FakeAuthService(),
    memberStore: members ?? FakeMemberStore(),
    listingsStore: listings ?? FakeListingsStore(),
    chatStore: chats ?? FakeChatStore(),
    ratingStore: ratings ?? FakeRatingStore(),
    reportStore: reports ?? FakeReportStore(),
    notificationStore: notifications ?? FakeNotificationStore(),
    messagingService: messaging ?? FakeMessagingService(),
  );
}

void main() {
  /// Detail/thread tests use a tall portrait surface so the whole layout
  /// (hero, body, seller strip, safety tips, action bar) is on screen.
  void usePortraitPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Chat sampleChat({String listingId = 'l1', String buyerId = 'buyer-1'}) =>
      Chat(
        id: chatIdFor(listingId, buyerId),
        listingId: listingId,
        sellerId: 'seller-1',
        buyerId: buyerId,
        participants: {'seller-1', buyerId},
        buyerName: 'B. One',
        sellerName: 'J. Dela Cruz',
        lastMessagePreview: 'Hi',
        lastMessageAt: DateTime(2026, 8, 28, 12),
      );

  Widget threadApp(
    FakeChatStore chats,
    FakeListingsStore listings,
    FakeMemberStore members, {
    Chat? chat,
    String viewerUid = 'buyer-1',
    FakeRatingStore? ratings,
    FakeReportStore? reports,
  }) {
    return MaterialApp(
      theme: buildUmTheme(),
      home: ChatThreadScreen(
        chat: chat ?? sampleChat(),
        viewerUid: viewerUid,
        chatStore: chats,
        memberStore: members,
        listingsStore: listings,
        ratingStore: ratings ?? FakeRatingStore(),
        reportStore: reports ?? FakeReportStore(),
      ),
    );
  }

  testWidgets('shows the Google sign-in gate when signed out', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('UM Marketplace'), findsOneWidget);
    expect(find.text('CAMPUS EXCLUSIVE'), findsOneWidget);
    expect(find.text('Ga'), findsOneWidget);
    final umMark = tester.widget<UmMark>(find.byType(UmMark));
    expect(umMark.size, 80);
    expect(umMark.borderWidth, 3);
    expect(umMark.shadowOffset, const Offset(4, 4));
    expect(
      find.text('The campus marketplace for University of Mindanao students.'),
      findsOneWidget,
    );
    expect(find.text('@umindanao.edu.ph accounts only'), findsOneWidget);
    expect(
      find.text('Exclusively for University of Mindanao Students'),
      findsOneWidget,
    );
    expect(find.text('Peer-to-peer • Meet on campus'), findsOneWidget);
  });

  testWidgets('shows error dialog when sign-in email is rejected', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService()
      ..signInError = const UmEmailRejectedException('outsider@gmail.com');
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Not a student address'), findsOneWidget);
    expect(find.textContaining('outsider@gmail.com'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Not a student address'), findsNothing);
  });

  testWidgets('signing in with invalid account triggers error pop-up dialog', (
    tester,
  ) async {
    final fakeAuth = FakeAuthService()
      ..signInError = const UmEmailRejectedException(
        'invalid.student@gmail.com',
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildUmTheme(),
        home: SignInScreen(authService: fakeAuth),
      ),
    );

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Not a student address'), findsOneWidget);
    expect(find.textContaining('invalid.student@gmail.com'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Not a student address'), findsNothing);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('shows error dialog on generic sign-in failure', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService()..signInError = Exception('network error');
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in failed'), findsOneWidget);
    expect(
      find.text('Could not sign in. Check your connection and try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in failed'), findsNothing);
  });

  testWidgets('SignInScreen fits without overflow on compact viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SignInScreen handles extreme short viewport without crash', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 40);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final auth = FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SignInScreen renders cleanly without overflow under accessibility text scaling',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final auth = FakeAuthService();
      await tester.pumpWidget(_app(auth: auth));
      await tester.pump();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('@umindanao.edu.ph accounts only'), findsOneWidget);
      final textWidget = tester.widget<Text>(
        find.text('@umindanao.edu.ph accounts only'),
      );
      expect(textWidget.textAlign, TextAlign.center);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SignInScreen renders UmMark with proper semantics', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final auth = FakeAuthService();
    await tester.pumpWidget(_app(auth: auth));
    await tester.pump();

    expect(find.byType(UmMark), findsOneWidget);
    final node = tester.getSemantics(find.byType(UmMark));
    expect(node.label, contains('UM Marketplace logo'));

    semantics.dispose();
  });

  testWidgets(
    'SignInScreen renders campus sticker badge and starburst accent',
    (WidgetTester tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(_app(auth: auth));
      await tester.pump();

      expect(find.text('CAMPUS EXCLUSIVE'), findsOneWidget);

      final starburstFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains('starburst.svg'),
      );
      expect(starburstFinder, findsOneWidget);
      final starburst = tester.widget<SvgPicture>(starburstFinder);
      expect(starburst.width, 38);
      expect(starburst.height, 38);
    },
  );

  testWidgets(
    'SignInScreen scrolls cleanly without overflow in landscape orientation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = FakeAuthService();
      await tester.pumpWidget(_app(auth: auth));
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
    },
  );

  testWidgets(
    'SignInScreen renders campus notebook dot grid background with ink dots',
    (WidgetTester tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(_app(auth: auth));
      await tester.pump();

      expect(find.byType(DotGridBackground), findsOneWidget);

      final customPaintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DotGridPainter,
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as DotGridPainter;
      expect(painter.spacing, 22.0);
      expect(painter.dotRadius, greaterThanOrEqualTo(1.5));
      expect(painter.dotRadius, lessThanOrEqualTo(1.7));
      expect(painter.dotColor, kDefaultDotGridColor);
      expect(customPaint.isComplex, isTrue);
      expect(customPaint.willChange, isFalse);
    },
  );

  test('DotGridPainter shouldRepaint reflects property changes accurately', () {
    const p1 = DotGridPainter(spacing: 24, dotRadius: 1.3);
    const p2 = DotGridPainter(spacing: 24, dotRadius: 1.3);
    const pDiffSpacing = DotGridPainter(spacing: 28, dotRadius: 1.3);
    const pDiffRadius = DotGridPainter(spacing: 24, dotRadius: 1.5);
    const pDiffColor = DotGridPainter(
      spacing: 24,
      dotRadius: 1.3,
      dotColor: Color(0xFF000000),
    );

    expect(p1.shouldRepaint(p2), isFalse);
    expect(p1.shouldRepaint(pDiffSpacing), isTrue);
    expect(p1.shouldRepaint(pDiffRadius), isTrue);
    expect(p1.shouldRepaint(pDiffColor), isTrue);

    // Equality and hashCode
    expect(p1, equals(p2));
    expect(p1.hashCode, equals(p2.hashCode));
    expect(p1 == pDiffSpacing, isFalse);
  });

  test('DotGridPainter paints cleanly, centers dots symmetrically, and handles edge cases safely', () {
    const painter = DotGridPainter();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Normal drawing
    expect(() => painter.paint(canvas, const Size(200, 200)), returnsNormally);

    // Boundary edge cases: zero or negative dimensions, spacing <= 0, radius <= 0
    expect(() => painter.paint(canvas, Size.zero), returnsNormally);
    expect(() => painter.paint(canvas, const Size(-10, 100)), returnsNormally);
    expect(() => painter.paint(canvas, const Size(100, -10)), returnsNormally);

    // Infinite and NaN dimensions must return safely without infinite loop or hang
    expect(
      () => painter.paint(canvas, const Size(100, double.infinity)),
      returnsNormally,
    );
    expect(
      () => painter.paint(canvas, const Size(double.infinity, 100)),
      returnsNormally,
    );
    expect(
      () => painter.paint(canvas, const Size(double.nan, 100)),
      returnsNormally,
    );

    const zeroSpacing = DotGridPainter(spacing: 0);
    expect(
      () => zeroSpacing.paint(canvas, const Size(100, 100)),
      returnsNormally,
    );

    const negativeSpacing = DotGridPainter(spacing: -5);
    expect(
      () => negativeSpacing.paint(canvas, const Size(100, 100)),
      returnsNormally,
    );

    const nanSpacing = DotGridPainter(spacing: double.nan);
    expect(
      () => nanSpacing.paint(canvas, const Size(100, 100)),
      returnsNormally,
    );

    const negativeRadius = DotGridPainter(dotRadius: -1);
    expect(
      () => negativeRadius.paint(canvas, const Size(100, 100)),
      returnsNormally,
    );

    final picture = recorder.endRecording();
    picture.dispose();
  });

  test(
    'DotGridPainter draws symmetrically centered grid within canvas bounds',
    () {
      final testCanvas = _RecordingCanvas();
      const painter = DotGridPainter(spacing: 22.0, dotRadius: 1.6);

      // Test on standard 375x812 viewport
      painter.paint(testCanvas, const Size(375, 812));
      expect(testCanvas.circles, isNotEmpty);

      // Symmetrical margins check
      final firstDot = testCanvas.circles.first;
      final lastDot = testCanvas.circles.last;
      final leftMargin = firstDot.dx;
      final rightMargin = 375 - lastDot.dx;
      final topMargin = firstDot.dy;
      final bottomMargin = 812 - lastDot.dy;

      expect(leftMargin, closeTo(rightMargin, 0.001));
      expect(topMargin, closeTo(bottomMargin, 0.001));

      // Strict bounds check: no dot clips outside the canvas
      for (final dot in testCanvas.circles) {
        expect(dot.dx - 1.6, greaterThanOrEqualTo(0));
        expect(dot.dx + 1.6, lessThanOrEqualTo(375));
        expect(dot.dy - 1.6, greaterThanOrEqualTo(0));
        expect(dot.dy + 1.6, lessThanOrEqualTo(812));
      }
    },
  );

  testWidgets('DotGridBackground renders child widget and custom properties', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DotGridBackground(
            spacing: 32.0,
            dotRadius: 1.4,
            dotColor: Color(0x1F000000),
            backgroundColor: Colors.white,
            child: Text('Notebook Canvas Test'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Notebook Canvas Test'), findsOneWidget);

    final customPaintFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is DotGridPainter,
    );
    expect(customPaintFinder, findsOneWidget);

    final customPaint = tester.widget<CustomPaint>(customPaintFinder);
    final painter = customPaint.painter as DotGridPainter;
    expect(painter.spacing, 32.0);
    expect(painter.dotRadius, 1.4);
    expect(painter.dotColor, const Color(0x1F000000));
  });

  testWidgets(
    'DotGridBackground renders safely with null child and in UnconstrainedBox',
    (WidgetTester tester) async {
      // 1. Null child inside bounded parent
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, height: 200, child: DotGridBackground()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DotGridBackground), findsOneWidget);

      // 2. DotGridBackground inside UnconstrainedBox (unbounded constraints must not crash)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnconstrainedBox(
              child: DotGridBackground(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Text('Unconstrained Test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Unconstrained Test'), findsOneWidget);
    },
  );

  testWidgets('sign-in creates the member account and lands on home', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    listings.emitListings();
    await tester.pumpAndSettle();

    expect(members.ensuredUids, ['test-uid']);
    expect(find.text('Recent listings'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
    // Member identity now lives on Profile only (brutal declutter).
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('L. Murillo'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget);
  });

  testWidgets('a banned member is shown the banned screen (ADR 0003)', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
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

  testWidgets('home feed shows listings with formatted prices', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
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
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
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

  testWidgets('bottom nav shows 4 tabs and switches between them', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SELL'), findsOneWidget);
    expect(find.text('CHATS'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
    expect(find.text('Recent listings'), findsOneWidget);

    await tester.tap(find.text('CHATS'));
    await tester.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Recent listings'), findsNothing);

    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();
    expect(find.text('Title — e.g. Calculus 201 textbook'), findsOneWidget);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('My listings'), findsOneWidget);
    expect(find.text('Title — e.g. Calculus 201 textbook'), findsNothing);
  });

  testWidgets('the Sell CTA switches to the Sell tab', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();

    expect(find.text('Title — e.g. Calculus 201 textbook'), findsOneWidget);
  });

  testWidgets('the sell draft survives switching tabs (IndexedStack)', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Half-finished draft');
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();

    expect(find.text('Half-finished draft'), findsOneWidget);
  });

  testWidgets('publishing from the Sell tab lands back on Home', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).at(0));
    await tester.enterText(find.byType(TextField).at(0), 'Tab publish');
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.enterText(find.byType(TextField).at(1), '120');
    await tester.ensureVisible(find.text('textbooks'));
    await tester.tap(find.text('textbooks'));
    await tester.pump();
    await tester.ensureVisible(find.text('Publish listing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish listing'));
    await tester.pumpAndSettle();

    expect(find.text('Recent listings'), findsOneWidget); // back on Home tab
    expect(listings.drafts, hasLength(1));
  });

  testWidgets('thread renders the pinned listing and messages', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Analytical Geometry notes',
      description: '',
      price: 180,
      category: 'textbooks',
      condition: 'good',
    );
    chats.messages['l1_buyer-1'] = [
      const ChatMessage(
        id: 'm1',
        senderId: 'seller-1',
        type: 'text',
        text: 'Hi there!',
      ),
      const ChatMessage(
        id: 'm2',
        senderId: 'buyer-1',
        type: 'text',
        text: 'Still available?',
      ),
    ];
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();
    // The message list subscribes only once the listing arrives — settle
    // first, then emit messages so the broadcast event is not dropped.
    chats.emitMessages('l1_buyer-1');
    await tester.pumpAndSettle();

    expect(find.text('Analytical Geometry notes'), findsOneWidget); // snippet
    expect(find.text('₱180'), findsOneWidget);
    expect(find.text('Hi there!'), findsOneWidget);
    expect(find.text('Still available?'), findsOneWidget);
    expect(find.text('J. Dela Cruz'), findsOneWidget); // header from chat doc
  });

  testWidgets('thread composer sends a text message', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tara, swap meet?');
    await tester.tap(find.byIcon(LucideIcons.send500));
    await tester.pumpAndSettle();

    expect(find.text('Tara, swap meet?'), findsOneWidget);
    expect(chats.messages['l1_buyer-1'], hasLength(1));
    expect(chats.messages['l1_buyer-1']!.single.senderId, 'buyer-1');
    expect(chats.chats['l1_buyer-1']!.lastMessagePreview, 'Tara, swap meet?');
  });

  testWidgets('a sold listing shows the banner and disables the composer', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
      status: 'sold',
    );
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    expect(find.text('This listing is no longer active'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.send500));
    expect(chats.messages['l1_buyer-1'] ?? const [], isEmpty);
  });

  testWidgets('a blocked send surfaces a snackbar and keeps the thread open', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore()..failSend = true;
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello?');
    await tester.tap(find.byIcon(LucideIcons.send500));
    await tester.pumpAndSettle();

    expect(
      find.text("You can't message this member right now"),
      findsOneWidget,
    );

    // Let the snackbar timer expire before the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('buyer sees the offer affordance and sends a priced offer', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.handCoins500));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '40');
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();

    expect(chats.messages['l1_buyer-1'], hasLength(1));
    final offer = chats.messages['l1_buyer-1']!.single;
    expect(offer.type, 'offer');
    expect(offer.price, 40.0);
    expect(find.text('₱40'), findsOneWidget); // rendered offer block
  });

  testWidgets('offer dialog rejects zero and bad input', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.handCoins500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send offer'));
    await tester.pump();
    expect(find.text('Enter a price above zero.'), findsOneWidget);
    expect(chats.messages['l1_buyer-1'] ?? const [], isEmpty);

    await tester.enterText(find.byType(TextField).last, 'potato');
    await tester.tap(find.text('Send offer'));
    await tester.pump();
    expect(find.text('Enter a price above zero.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '25.5');
    await tester.tap(find.text('Send offer'));
    await tester.pump();
    expect(find.text('Use whole pesos only.'), findsOneWidget);
  });

  testWidgets('the seller has no offer affordance', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
    );
    await tester.pumpWidget(
      threadApp(chats, listings, members, viewerUid: 'seller-1'),
    );
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.handCoins500), findsNothing);
  });

  testWidgets('tapping a listing card opens its detail screen', (
    WidgetTester tester,
  ) async {
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
          photos: [
            Uint8List.fromList([1]),
            Uint8List.fromList([2]),
          ],
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
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

  testWidgets('the seller strip shows the document name and trust cues', (
    WidgetTester tester,
  ) async {
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
          sellerDisplayName: 'J. Dela Cruz',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();

    expect(find.text('J. Dela Cruz'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget);
    expect(find.text('★ — · no trades yet'), findsOneWidget);
  });

  testWidgets('an unnamed seller still shows the safe fallback', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();

    expect(find.text('UM student'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget); // platform badge
  });

  testWidgets('viewing your own listing hides the chat/offer bar', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
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

  testWidgets('Chats tab lists conversations with names, previews, and times', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHATS'));
    await tester.pumpAndSettle();

    final chat = sampleChat(buyerId: 'test-uid');
    chats.chats[chat.id] = chat;
    chats.emitList();
    await tester.pumpAndSettle();

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('J. Dela Cruz'), findsOneWidget); // document name
    expect(find.text('Hi'), findsOneWidget); // last-message preview
  });

  testWidgets('empty chats show the empty state', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHATS'));
    await tester.pumpAndSettle();

    chats.emitList(); // empty list
    await tester.pumpAndSettle();
    expect(find.textContaining('No conversations yet'), findsOneWidget);
  });

  testWidgets('tapping a chat row opens the thread', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHATS'));
    await tester.pumpAndSettle();

    final chat = sampleChat(buyerId: 'test-uid');
    chats.chats[chat.id] = chat;
    chats.emitList();
    await tester.pumpAndSettle();

    await tester.tap(find.text('J. Dela Cruz'));
    await tester.pumpAndSettle();
    listings.emitListing(
      'l1',
      const Listing(
        id: 'l1',
        sellerId: 'seller-1',
        title: 'Notes',
        description: '',
        price: 50,
        category: 'textbooks',
        condition: 'good',
      ),
    );
    await tester.pumpAndSettle();
    chats.emitMessages('l1_test-uid'); // empty: no messages yet
    await tester.pumpAndSettle();
    expect(find.text('Say hi — or send an offer.'), findsOneWidget); // thread
  });

  testWidgets('detail Chat opens the thread; offer sends an offer message', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'l1',
          sellerId: 'seller-1',
          title: 'Dorm lamp',
          description: 'USB powered.',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
        ),
      ];
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    // Thread open (chat created via the fake) — feed the listing so the
    // thread's body builds past the skeleton.
    expect(chats.chats.containsKey('l1_test-uid'), isTrue);
    listings.emitListing(
      'l1',
      const Listing(
        id: 'l1',
        sellerId: 'seller-1',
        title: 'Dorm lamp',
        description: 'USB powered.',
        price: 300,
        category: 'dorm essentials',
        condition: 'like new',
      ),
    );
    await tester.pumpAndSettle();
    chats.emitMessages('l1_test-uid'); // empty: no messages yet
    await tester.pumpAndSettle();
    expect(find.text('Say hi — or send an offer.'), findsOneWidget);

    // Back to detail, then make an offer.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make an offer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '250');
    await tester.tap(find.text('Send offer'));
    await tester.pumpAndSettle();
    listings.emitListing(
      'l1',
      const Listing(
        id: 'l1',
        sellerId: 'seller-1',
        title: 'Dorm lamp',
        description: 'USB powered.',
        price: 300,
        category: 'dorm essentials',
        condition: 'like new',
      ),
    );
    await tester.pumpAndSettle();
    // The offer was sent before this thread existed — replay the current
    // messages so the freshly-subscribed list renders them.
    chats.emitMessages('l1_test-uid');
    await tester.pumpAndSettle();

    expect(chats.messages['l1_test-uid'], hasLength(1));
    expect(chats.messages['l1_test-uid']!.single.type, 'offer');
    expect(chats.messages['l1_test-uid']!.single.price, 250.0);
    expect(find.text('OFFER'), findsOneWidget); // landed in the thread
  });

  testWidgets('opening a chat against a blocked pair shows a snackbar', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'l1',
          sellerId: 'seller-1',
          title: 'Dorm lamp',
          description: '',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
        ),
      ];
    final chats = FakeChatStore()..failOpen = true;
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(
      find.text("You can't start a chat with this member right now"),
      findsOneWidget,
    );
    // still on the detail screen
    expect(find.text('Make an offer'), findsOneWidget);

    // Let the snackbar timer expire.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('opening a chat on a sold listing explains the listing is gone', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'l1',
          sellerId: 'seller-1',
          title: 'Dorm lamp',
          description: '',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
          status: 'sold',
        ),
      ];
    final chats = FakeChatStore()
      ..failOpen = true
      ..openFailure = ChatOpenFailure.listingInactive;
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('This listing is no longer available'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('search pill opens Browse; typing filters results live', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
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
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
        const Listing(
          id: 'c',
          sellerId: 's',
          title: 'Dorm lamp',
          description: '',
          price: 60,
          category: 'dorm essentials',
          condition: 'fair',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.search500));
    await tester.pumpAndSettle();
    // Browse subscribed only on push — broadcast streams don't replay, so
    // re-emit the seeded listings after settling.
    listings.emitListings();
    await tester.pumpAndSettle();

    expect(find.text('Calculus 201 textbook'), findsOneWidget);
    expect(find.text('Mechanical keyboard'), findsOneWidget);
    expect(find.text('Dorm lamp'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'keyboard');
    await tester.pumpAndSettle();

    expect(find.text('Mechanical keyboard'), findsOneWidget);
    expect(find.text('Calculus 201 textbook'), findsNothing);
    expect(find.text('Dorm lamp'), findsNothing);
  });

  testWidgets('browse category chips filter the grid', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
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
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.search500));
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    final chips = find.byKey(const Key('browse-category-chips'));
    await tester.tap(
      find.descendant(of: chips, matching: find.text('gadgets')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mechanical keyboard'), findsOneWidget);
    expect(find.text('Calculus 201 textbook'), findsNothing);

    await tester.tap(find.descendant(of: chips, matching: find.text('All')));
    await tester.pumpAndSettle();
    expect(find.text('Calculus 201 textbook'), findsOneWidget);
  });

  testWidgets('the filters sheet applies condition and price range', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
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
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
        const Listing(
          id: 'c',
          sellerId: 's',
          title: 'Dorm lamp',
          description: '',
          price: 60,
          category: 'dorm essentials',
          condition: 'fair',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.search500));
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.byKey(const Key('browse-condition-pills')),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('browse-condition-pills')),
        matching: find.text('like new'),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)).at(0),
      '100',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Mechanical keyboard'), findsOneWidget);
    expect(find.text('Calculus 201 textbook'), findsNothing);
    expect(find.text('Dorm lamp'), findsNothing);
  });

  testWidgets('empty results show the empty state and clear filters recovers', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'b',
          sellerId: 's',
          title: 'Mechanical keyboard',
          description: '',
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.search500));
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz nothing');
    await tester.pumpAndSettle();
    expect(find.text('No listings match your search.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Mechanical keyboard'), findsOneWidget);
  });

  testWidgets(
    'home shows hero search and category tiles, quick searches removed',
    (WidgetTester tester) async {
      usePortraitPhone(tester);
      final auth = FakeAuthService();
      final members = FakeMemberStore();
      final listings = FakeListingsStore()
        ..listings = [
          const Listing(
            id: 'a',
            sellerId: 's',
            title: 'Statistics notes',
            description: '',
            price: 80,
            category: 'review materials',
            condition: 'good',
          ),
          const Listing(
            id: 'b',
            sellerId: 's',
            title: 'Dorm lamp',
            description: '',
            price: 60,
            category: 'dorm essentials',
            condition: 'fair',
          ),
        ];
      await tester.pumpWidget(
        _app(auth: auth, members: members, listings: listings),
      );
      auth.emit(_student);
      await tester.pumpAndSettle();
      listings.emitListings();
      await tester.pumpAndSettle();

      // Quick search chips removed — only hero search + category tiles remain.
      expect(
        find.text('Statistics notes'),
        findsOneWidget,
      ); // only the listing card
      expect(find.text('Electric fan'), findsNothing);
      expect(find.text('Airpods'), findsNothing);
      // Hero search still opens Browse.
      await tester.tap(find.byIcon(LucideIcons.search500).first);
      await tester.pumpAndSettle();
      listings.emitListings();
      await tester.pumpAndSettle();
      expect(find.text('BROWSE'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Category tiles still open Browse pre-filtered.
      await tester.tap(find.text('gadgets').first);
      await tester.pumpAndSettle();
      listings.emitListings();
      await tester.pumpAndSettle();
      expect(find.text('Dorm lamp'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListingCard),
          matching: find.text('Statistics notes'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('profile shows member identity and the rating placeholder', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    listings.emitMyListings(); // empty: nothing listed yet
    await tester.pumpAndSettle();

    expect(find.text('L. Murillo'), findsOneWidget);
    expect(find.text('l.murillo.546842@umindanao.edu.ph'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget);
    expect(find.text('★ — · no trades yet'), findsOneWidget);
    expect(find.text('My listings'), findsOneWidget);
    expect(
      find.textContaining('You haven\'t listed anything yet'),
      findsOneWidget,
    );
  });

  testWidgets('a sold listing offers the rate prompt and records the vote', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    final ratings = FakeRatingStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
      status: 'sold',
    );
    await tester.pumpWidget(
      threadApp(chats, listings, members, ratings: ratings),
    );
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();
    chats.emitMessages('l1_buyer-1');
    await tester.pumpAndSettle();

    expect(find.text('How was the deal?'), findsOneWidget);
    await tester.tap(find.text('Rate deal'));
    await tester.pumpAndSettle();
    expect(find.text('Rate this deal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rate-star-4')));
    await tester.pump();
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();

    final vote = ratings.ratings['l1_buyer-1'];
    expect(vote, isNotNull);
    expect(vote!.stars, 4);
    expect(vote.rateeId, 'seller-1'); // the other party of the chat
    // Prompt flips to the read-only state.
    expect(find.text('You rated this deal ★4'), findsOneWidget);
    expect(find.text('Rate deal'), findsNothing);

    // Snackbar timer must expire before the test ends.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('an already-rated thread shows the read-only state', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    final ratings = FakeRatingStore()
      ..ratings['l1_buyer-1'] = Rating(
        listingId: 'l1',
        raterId: 'buyer-1',
        rateeId: 'seller-1',
        stars: 5,
        chatId: 'l1_buyer-1',
        createdAt: DateTime(2026, 8, 28, 12),
      );
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
      status: 'sold',
    );
    await tester.pumpWidget(
      threadApp(chats, listings, members, ratings: ratings),
    );
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    expect(find.text('You rated this deal ★5'), findsOneWidget);
    expect(find.text('Rate deal'), findsNothing);
  });

  testWidgets('a hidden listing shows no rating prompt', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    const listing = Listing(
      id: 'l1',
      sellerId: 'seller-1',
      title: 'Notes',
      description: '',
      price: 50,
      category: 'textbooks',
      condition: 'good',
      status: 'hidden',
    );
    await tester.pumpWidget(threadApp(chats, listings, members));
    await tester.pumpAndSettle();
    listings.emitListing('l1', listing);
    await tester.pumpAndSettle();

    expect(find.text('How was the deal?'), findsNothing);
    expect(find.text('This listing is no longer active'), findsOneWidget);
  });

  testWidgets('the seller strip shows the live rating average', (
    WidgetTester tester,
  ) async {
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
    final ratings = FakeRatingStore()
      ..ratings['a_r1'] = Rating(
        listingId: 'a',
        raterId: 'r1',
        rateeId: 'seller-uid',
        stars: 5,
        chatId: 'a_r1',
      )
      ..ratings['a_r2'] = Rating(
        listingId: 'a',
        raterId: 'r2',
        rateeId: 'seller-uid',
        stars: 4,
        chatId: 'a_r2',
      );
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, ratings: ratings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    members.emit(
      const Member(
        uid: 'seller-uid',
        email: 'j.delacruz.000000@umindanao.edu.ph',
        displayName: 'J. Dela Cruz',
      ),
    );
    await tester.pumpAndSettle();
    ratings.emitRatingsFor('seller-uid');
    await tester.pumpAndSettle();

    expect(find.text('★ 4.5 · 2 trades'), findsOneWidget);
    expect(find.text('★ — · no trades yet'), findsNothing);
  });

  testWidgets('the profile card shows the live rating average', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final ratings = FakeRatingStore()
      ..ratings['b_r1'] = Rating(
        listingId: 'b',
        raterId: 'r1',
        rateeId: 'test-uid',
        stars: 3,
        chatId: 'b_r1',
      );
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, ratings: ratings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    ratings.emitRatingsFor('test-uid');
    await tester.pumpAndSettle();

    expect(find.text('★ 3.0 · 1 trade'), findsOneWidget);
    expect(find.text('★ — · no trades yet'), findsNothing);
  });

  testWidgets('detail screen submits a listing report', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'l1',
          sellerId: 'seller-1',
          title: 'Dorm lamp',
          description: '',
          price: 300,
          category: 'dorm essentials',
          condition: 'like new',
          sellerDisplayName: 'J. Dela Cruz',
        ),
      ];
    final reports = FakeReportStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, reports: reports),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dorm lamp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.flag500));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Selling stolen notes');
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(reports.submitted, hasLength(1));
    expect(reports.submitted.single['listingId'], 'l1');
    expect(reports.submitted.single['reportedUid'], 'seller-1');
    expect(find.textContaining('Report submitted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('thread header submits a chat report', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final chats = FakeChatStore();
    final listings = FakeListingsStore();
    final members = FakeMemberStore();
    final reports = FakeReportStore();
    await tester.pumpWidget(
      threadApp(chats, listings, members, reports: reports),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.flag500));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Harassment');
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(reports.submitted, hasLength(1));
    expect(reports.submitted.single['chatId'], 'l1_buyer-1');
    expect(reports.submitted.single['reportedUid'], 'seller-1');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  /// Signs in as the Admin (isAdmin via the member doc) and opens the
  /// Moderation screen from the Profile gate.
  Future<void> openModeration(
    WidgetTester tester, {
    required FakeMemberStore members,
    required FakeReportStore reports,
  }) async {
    final auth = FakeAuthService();
    final listings = FakeListingsStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, reports: reports),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    members.emit(
      const Member(
        uid: 'test-uid',
        email: 'l.murillo.546842@umindanao.edu.ph',
        displayName: 'L. Murillo',
        isAdmin: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderation'));
    await tester.pumpAndSettle();
    reports.emitOpen();
    await tester.pumpAndSettle();
  }

  testWidgets('the admin gate opens moderation with live reports', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final members = FakeMemberStore();
    final reports = FakeReportStore()
      ..reports.add(
        Report(
          id: 'r1',
          reporterId: 'buyer-1',
          status: 'open',
          reason: 'Stolen notes',
          listingId: 'l1',
          reportedUid: 'seller-1',
          createdAt: DateTime(2026, 8, 28, 12),
        ),
      );
    await openModeration(tester, members: members, reports: reports);

    expect(find.text('Open reports'), findsOneWidget);
    expect(find.text('Stolen notes'), findsOneWidget);
    expect(find.text('Listing: l1'), findsOneWidget);
    expect(find.text('Hide listing'), findsOneWidget);
    expect(find.text('Ban user'), findsOneWidget);
  });

  testWidgets('hiding a listing resolves the report', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final members = FakeMemberStore();
    final reports = FakeReportStore()
      ..reports.add(
        Report(
          id: 'r1',
          reporterId: 'buyer-1',
          status: 'open',
          reason: 'Stolen notes',
          listingId: 'l1',
          reportedUid: 'seller-1',
          createdAt: DateTime(2026, 8, 28, 12),
        ),
      );
    final listings = FakeListingsStore();
    final auth = FakeAuthService();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, reports: reports),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    members.emit(
      const Member(
        uid: 'test-uid',
        email: 'l.murillo.546842@umindanao.edu.ph',
        displayName: 'L. Murillo',
        isAdmin: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderation'));
    await tester.pumpAndSettle();
    reports.emitOpen();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hide listing'));
    await tester.pumpAndSettle();
    expect(find.text('Hide this listing?'), findsOneWidget);
    await tester.tap(find.text('Hide listing').last);
    await tester.pumpAndSettle();

    expect(listings.hiddenIds, ['l1']);
    expect(reports.reports, isEmpty); // resolved, left the inbox
    expect(find.text('Open reports'), findsOneWidget);
    expect(find.text('Stolen notes'), findsNothing);
  });

  testWidgets('banning a user hides their listings and resolves the report', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final members = FakeMemberStore();
    final reports = FakeReportStore()
      ..reports.add(
        Report(
          id: 'r1',
          reporterId: 'buyer-1',
          status: 'open',
          reason: 'Scams repeatedly',
          listingId: 'l1',
          reportedUid: 'seller-1',
          createdAt: DateTime(2026, 8, 28, 12),
        ),
      );
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'l1',
          sellerId: 'seller-1',
          title: 'Fake notes',
          description: '',
          price: 10,
          category: 'textbooks',
          condition: 'fair',
        ),
      ];
    final auth = FakeAuthService();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, reports: reports),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    members.emit(
      const Member(
        uid: 'test-uid',
        email: 'l.murillo.546842@umindanao.edu.ph',
        displayName: 'L. Murillo',
        isAdmin: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderation'));
    await tester.pumpAndSettle();
    reports.emitOpen();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ban user'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ban this member'), findsOneWidget); // confirm
    await tester.tap(find.text('Ban user').last); // dialog confirm
    await tester.pumpAndSettle();

    expect(members.bannedUids['seller-1'], isTrue);
    expect(listings.hiddenIds, contains('l1'));
    expect(reports.reports, isEmpty);
  });

  testWidgets('member lookup finds and bans a member', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final members = FakeMemberStore()
      ..knownMembers['seller-1'] = const Member(
        uid: 'seller-1',
        email: 'j.delacruz.000000@umindanao.edu.ph',
        displayName: 'J. Dela Cruz',
      );
    final reports = FakeReportStore();
    await openModeration(tester, members: members, reports: reports);

    await tester.tap(find.text('Find a member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'J. Dela');
    await tester.pumpAndSettle();
    expect(find.text('J. Dela Cruz'), findsOneWidget);

    await tester.tap(find.text('Ban user'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ban this member'), findsOneWidget);
    await tester.tap(find.text('Ban user').last); // dialog confirm
    await tester.pumpAndSettle();
    expect(members.bannedUids['seller-1'], isTrue);
  });

  AppNotification note(
    String id, {
    String type = 'message',
    bool read = false,
  }) => AppNotification(
    id: id,
    ownerId: 'test-uid',
    type: type,
    title: 'New $type',
    body: 'Something happened',
    read: read,
    createdAt: DateTime(2026, 8, 28, 12),
  );

  testWidgets('the bell shows the live unread count and opens the center', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final notifications = FakeNotificationStore()
      ..notifications.addAll([
        note('n1'),
        note('n2'),
        note('n3', type: 'sold', read: true),
      ]);
    await tester.pumpWidget(
      _app(
        auth: auth,
        members: members,
        listings: listings,
        notifications: notifications,
      ),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    notifications.emit();
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.bell500), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // unread gold sticker

    await tester.tap(find.byIcon(LucideIcons.bell500));
    await tester.pumpAndSettle();
    // The center subscribes only on push — replay the stream.
    notifications.emit();
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('New message'), findsNWidgets(2));
    expect(find.text('Something happened'), findsNWidgets(3));
    expect(find.text('NEW'), findsNWidgets(2)); // unread stickers only
  });

  testWidgets('tapping an unread row marks it read and clears its sticker', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final notifications = FakeNotificationStore()
      ..notifications.addAll([note('n1'), note('n2')]);
    await tester.pumpWidget(
      _app(
        auth: auth,
        members: members,
        listings: listings,
        notifications: notifications,
      ),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    notifications.emit();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.bell500));
    await tester.pumpAndSettle();
    notifications.emit();
    await tester.pumpAndSettle();

    await tester.tap(find.text('New message').first);
    await tester.pumpAndSettle();

    expect(notifications.readIds, ['n1']);
    expect(find.text('NEW'), findsOneWidget); // only n2 remains unread
  });

  testWidgets('the center shows the empty state', (WidgetTester tester) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final notifications = FakeNotificationStore();
    await tester.pumpWidget(
      _app(
        auth: auth,
        members: members,
        listings: listings,
        notifications: notifications,
      ),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    notifications.emit(); // empty
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.bell500));
    await tester.pumpAndSettle();
    notifications.emit(); // empty
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('sign-in registers the device for FCM', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final messaging = FakeMessagingService();
    await tester.pumpWidget(
      _app(
        auth: auth,
        members: members,
        listings: listings,
        messaging: messaging,
      ),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    expect(messaging.registeredUids, ['test-uid']);
  });

  testWidgets('sign-out unregisters before the auth session ends', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final messaging = FakeMessagingService();
    await tester.pumpWidget(
      _app(
        auth: auth,
        members: members,
        listings: listings,
        messaging: messaging,
      ),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(messaging.unregisterCalls, 1);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('my listings show active and sold rows with pills', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'test-uid',
          title: 'Calculus 201 textbook',
          description: '',
          price: 1250,
          category: 'textbooks',
          condition: 'good',
        ),
        const Listing(
          id: 'b',
          sellerId: 'test-uid',
          title: 'Old desk lamp',
          description: '',
          price: 60,
          category: 'dorm essentials',
          condition: 'fair',
          status: 'sold',
        ),
      ];
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    listings.emitMyListings();
    await tester.pumpAndSettle();

    expect(find.text('My listings'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
    await tester.tap(find.text('My listings'));
    await tester.pumpAndSettle();

    expect(find.text('Calculus 201 textbook'), findsOneWidget);
    expect(find.text('Mark as sold'), findsOneWidget); // active row only
    expect(find.text('Old desk lamp'), findsOneWidget);
    expect(find.text('SOLD'), findsNWidgets(2)); // filter chip + listing badge
  });

  testWidgets('marking a listing sold confirms and flips the row', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'test-uid',
          title: 'Calculus 201 textbook',
          description: '',
          price: 1250,
          category: 'textbooks',
          condition: 'good',
        ),
        const Listing(
          id: 'b',
          sellerId: 'test-uid',
          title: 'Mechanical keyboard',
          description: '',
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
      ];
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    listings.emitMyListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My listings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as sold').first);
    await tester.pumpAndSettle();
    expect(find.text('Mark as sold?'), findsOneWidget); // confirm dialog

    // The dialog's confirm button is the later match.
    await tester.tap(find.text('Mark as sold').last);
    await tester.pumpAndSettle();

    expect(listings.soldIds, ['a']);
    expect(find.text('SOLD'), findsNWidgets(2)); // filter chip + listing badge
    expect(find.text('Mark as sold'), findsOneWidget); // only b remains active
  });

  testWidgets('cancelling a listing confirms and flips the row', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'test-uid',
          title: 'Calculus 201 textbook',
          description: '',
          price: 1250,
          category: 'textbooks',
          condition: 'good',
        ),
        const Listing(
          id: 'b',
          sellerId: 'test-uid',
          title: 'Mechanical keyboard',
          description: '',
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
      ];
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    listings.emitMyListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My listings'));
    await tester.pumpAndSettle();

    // Keep it: the dialog dismisses and nothing changes.
    await tester.tap(find.text('Cancel listing').first);
    await tester.pumpAndSettle();
    expect(find.text('Cancel this listing?'), findsOneWidget); // confirm dialog
    expect(find.text('Keep it'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('CANCELLED'), findsOneWidget); // only the filter chip
    expect(find.text('Mark as sold'), findsNWidgets(2)); // both rows active

    // Cancel listing: the dialog confirms and the row flips.
    await tester.tap(find.text('Cancel listing').first);
    await tester.pumpAndSettle();
    // The dialog's confirm button is the later match.
    await tester.tap(find.text('Cancel listing').last);
    await tester.pumpAndSettle();

    expect(listings.cancelledIds, ['a']);
    expect(
      find.text('CANCELLED'),
      findsNWidgets(2),
    ); // filter chip + listing badge
    expect(find.text('Mark as sold'), findsOneWidget); // only b remains active
    expect(find.text('Cancel listing'), findsOneWidget);
  });

  testWidgets(
    'cancelling a listing button has brutal mechanical press animation and stack shadow',
    (WidgetTester tester) async {
      usePortraitPhone(tester);
      final auth = FakeAuthService();
      final members = FakeMemberStore();
      final listings = FakeListingsStore()
        ..listings = [
          const Listing(
            id: 'a',
            sellerId: 'test-uid',
            title: 'Calculus 201 textbook',
            description: '',
            price: 1250,
            category: 'textbooks',
            condition: 'good',
          ),
        ];
      final chats = FakeChatStore();
      await tester.pumpWidget(
        _app(auth: auth, members: members, listings: listings, chats: chats),
      );
      auth.emit(_student);
      await tester.pumpAndSettle();

      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      listings.emitMyListings();
      await tester.pumpAndSettle();

      await tester.tap(find.text('My listings'));
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Cancel listing').first;
      expect(buttonFinder, findsOneWidget);

      // Verify the button is placed inside a Stack with its brutal shadow backing
      final stackFinder = find.ancestor(
        of: buttonFinder,
        matching: find.byType(Stack),
      );
      expect(stackFinder, findsWidgets);

      // Tap down triggers the mechanical press translation
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Cancel this listing?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('the moderation row is admin-only and opens the screen', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    // Ordinary member: no moderation row (ADR 0003).
    expect(find.text('Moderation'), findsNothing);

    // The Admin's account carries the flag; the row appears and gates.
    members.emit(
      const Member(
        uid: 'test-uid',
        email: 'l.murillo.546842@umindanao.edu.ph',
        displayName: 'L. Murillo',
        isAdmin: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Moderation'), findsOneWidget);

    await tester.tap(find.text('Moderation'));
    await tester.pumpAndSettle();
    expect(find.text('Open reports'), findsOneWidget); // the screen
  });

  testWidgets('a profile listing row opens the listing detail', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'a',
          sellerId: 'test-uid',
          title: 'Calculus 201 textbook',
          description: 'Clean set, minimal highlights.',
          price: 1250,
          category: 'textbooks',
          condition: 'good',
        ),
      ];
    final chats = FakeChatStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings, chats: chats),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    listings.emitMyListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('My listings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculus 201 textbook'));
    await tester.pumpAndSettle();

    expect(find.text('Clean set, minimal highlights.'), findsOneWidget);
  });

  testWidgets(
    'my listings profile row shows empty subtitle and updates with active count badge',
    (WidgetTester tester) async {
      usePortraitPhone(tester);
      final auth = FakeAuthService();
      final members = FakeMemberStore();
      final listings = FakeListingsStore();
      final chats = FakeChatStore();
      await tester.pumpWidget(
        _app(auth: auth, members: members, listings: listings, chats: chats),
      );
      auth.emit(_student);
      await tester.pumpAndSettle();

      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      listings.emitMyListings();
      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('My listings'), findsOneWidget);
      expect(find.text("You haven't listed anything yet."), findsOneWidget);
      expect(find.text('0 active'), findsOneWidget);

      // Now add listings
      listings.listings = [
        const Listing(
          id: 'x',
          sellerId: 'test-uid',
          title: 'Graphing calculator',
          description: '',
          price: 500,
          category: 'gadgets',
          condition: 'good',
        ),
      ];
      listings.emitMyListings();
      await tester.pumpAndSettle();

      expect(find.text('1 active · 1 total'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
    },
  );

  testWidgets(
    'my listings screen status filters switch views and empty state',
    (WidgetTester tester) async {
      usePortraitPhone(tester);
      final auth = FakeAuthService();
      final members = FakeMemberStore();
      final listings = FakeListingsStore()
        ..listings = [
          const Listing(
            id: 'a',
            sellerId: 'test-uid',
            title: 'Active Notebook',
            description: '',
            price: 50,
            category: 'stationery',
            condition: 'like new',
          ),
          const Listing(
            id: 'b',
            sellerId: 'test-uid',
            title: 'Sold Textbook',
            description: '',
            price: 300,
            category: 'textbooks',
            condition: 'good',
            status: 'sold',
          ),
        ];
      final chats = FakeChatStore();
      await tester.pumpWidget(
        _app(auth: auth, members: members, listings: listings, chats: chats),
      );
      auth.emit(_student);
      await tester.pumpAndSettle();

      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();
      listings.emitMyListings();
      await tester.pumpAndSettle();

      await tester.tap(find.text('My listings'));
      await tester.pumpAndSettle();

      // Screen title and filters
      expect(find.text('MY LISTINGS'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(
        find.text('SOLD'),
        findsNWidgets(2),
      ); // filter chip + sold listing badge
      expect(find.text('CANCELLED'), findsOneWidget);

      // ALL tab shows both
      expect(find.text('Active Notebook'), findsOneWidget);
      expect(find.text('Sold Textbook'), findsOneWidget);

      // Filter ACTIVE only
      await tester.tap(find.text('ACTIVE'));
      await tester.pumpAndSettle();
      expect(find.text('Active Notebook'), findsOneWidget);
      expect(find.text('Sold Textbook'), findsNothing);

      // Filter SOLD only (tap filter chip)
      await tester.tap(find.text('SOLD').first);
      await tester.pumpAndSettle();
      expect(find.text('Active Notebook'), findsNothing);
      expect(find.text('Sold Textbook'), findsOneWidget);

      // Filter CANCELLED only (none exist)
      await tester.tap(find.text('CANCELLED'));
      await tester.pumpAndSettle();
      expect(find.text('Active Notebook'), findsNothing);
      expect(find.text('Sold Textbook'), findsNothing);
      expect(find.text('No cancelled listings.'), findsOneWidget);
    },
  );

  testWidgets('category tiles open Browse pre-filtered by category', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'b',
          sellerId: 's',
          title: 'Mechanical keyboard',
          description: '',
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
        const Listing(
          id: 'c',
          sellerId: 's',
          title: 'Dorm lamp',
          description: '',
          price: 60,
          category: 'dorm essentials',
          condition: 'fair',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    // Tiles render before the feed grid, so `.first` is the tile.
    await tester.tap(find.text('gadgets').first);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    expect(find.text('Mechanical keyboard'), findsOneWidget);
    expect(find.text('Dorm lamp'), findsNothing);
  });

  testWidgets('browse cards open the listing detail', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore()
      ..listings = [
        const Listing(
          id: 'b',
          sellerId: 'seller-1',
          title: 'Mechanical keyboard',
          description: 'RGB switches',
          price: 250,
          category: 'gadgets',
          condition: 'like new',
        ),
      ];
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.search500));
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mechanical keyboard'));
    await tester.pumpAndSettle();

    expect(find.text('RGB switches'), findsOneWidget); // detail description
  });

  testWidgets('a listing without photos shows the placeholder, no count chip', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Old notes'));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.imageOff500), findsOneWidget);
    expect(find.text('1/2'), findsNothing);
  });

  testWidgets('a sold listing shows the SOLD sticker on the hero photo', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sold mug'));
    await tester.pumpAndSettle();

    expect(find.text('SOLD'), findsOneWidget);
  });

  testWidgets('sell flow validates, publishes and records the draft', (
    WidgetTester tester,
  ) async {
    usePortraitPhone(tester);
    final auth = FakeAuthService();
    final members = FakeMemberStore();
    final listings = FakeListingsStore();
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('SELL'));
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
    await tester.pumpWidget(
      _app(auth: auth, members: members, listings: listings),
    );
    auth.emit(_student);
    await tester.pump();
    await tester.pumpAndSettle();
    listings.emitListings();
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  test(
    'kMaxListingPhotos is 2 to stay inside the Firestore document limit',
    () {
      expect(kMaxListingPhotos, 2);
      expect(kListingCategories, contains('review materials'));
      expect(kListingCategories, hasLength(5));
      expect(kListingConditions, hasLength(4));
    },
  );

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

  group('UmLogo', () {
    testWidgets('UmMark renders the Ga lettermark at any size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [UmMark(size: 44), UmMark(size: 32), UmMark(size: 72)],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Ga'), findsNWidgets(3));
    });

    testWidgets('UmLogo pairs the mark with the wordmark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UmLogo(dark: true))),
      );
      await tester.pump();
      expect(find.text('Ga'), findsOneWidget);
      expect(find.text('UM MARKETPLACE'), findsOneWidget);
      expect(find.text('STUDENT EXCHANGE'), findsOneWidget);
    });

    testWidgets('logo SVG assets parse and render', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [UmMarkSvg(size: 40), UmLogoSvg(height: 64)],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(UmMarkSvg), findsOneWidget);
      expect(find.byType(UmLogoSvg), findsOneWidget);
    });
  });

  group('BrutalDialog pop-in animation', () {
    testWidgets(
      'showBrutalErrorDialog renders with pop-in scale and fade transition',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showBrutalErrorDialog(
                    context,
                    title: 'Error Title',
                    message: 'Error body message.',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump(); // Start of animation
        expect(find.byType(ScaleTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);
        expect(
          find.ancestor(
            of: find.byType(Dialog),
            matching: find.byType(ScaleTransition),
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Error Title'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('Error Title'), findsOneWidget);
        expect(find.text('Error body message.'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.text('Error Title'), findsNothing);
      },
    );

    testWidgets(
      'showBrutalSuccessDialog renders with pop-in scale and fade transition',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showBrutalSuccessDialog(
                    context,
                    title: 'Success Title',
                    message: 'Success body message.',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump(); // Start of animation
        expect(find.byType(ScaleTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);
        expect(
          find.ancestor(
            of: find.byType(Dialog),
            matching: find.byType(ScaleTransition),
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Success Title'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('Success Title'), findsOneWidget);
        expect(find.text('Success body message.'), findsOneWidget);

        await tester.tap(find.text('Nice'));
        await tester.pumpAndSettle();
        expect(find.text('Success Title'), findsNothing);
      },
    );

    testWidgets(
      'showBrutalConfirmDialog renders with pop-in scale and fade transition and returns user choice',
      (WidgetTester tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showBrutalConfirmDialog(
                      context,
                      title: 'Cancel this listing?',
                      body: 'This cannot be undone.',
                      confirmLabel: 'Cancel listing',
                      cancelLabel: 'Keep it',
                      isDestructive: true,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pump(); // Start of animation
        expect(find.byType(ScaleTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);
        expect(
          find.ancestor(
            of: find.byType(Dialog),
            matching: find.byType(ScaleTransition),
          ),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        expect(find.text('Cancel this listing?'), findsOneWidget);
        expect(find.text('This cannot be undone.'), findsOneWidget);
        expect(find.text('Keep it'), findsOneWidget);
        expect(find.text('Cancel listing'), findsOneWidget);

        // Tap cancel button (Keep it)
        await tester.tap(find.text('Keep it'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
        expect(find.text('Cancel this listing?'), findsNothing);

        // Open again and confirm
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel listing'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      },
    );
  });

  group('MemberGate and MemberSplash guard & escape hatch', () {
    testWidgets(
      'MemberGate rejects non-student AuthUser, displays pop-in error dialog, and signs out',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();
        final fakeMember = FakeMemberStore();

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: MemberGate(
              authUser: const AuthUser(
                uid: 'bad-uid',
                email: 'outsider@gmail.com',
                displayName: 'Outsider',
              ),
              authService: fakeAuth,
              memberStore: fakeMember,
              listingsStore: FakeListingsStore(),
              chatStore: FakeChatStore(),
              ratingStore: FakeRatingStore(),
              reportStore: FakeReportStore(),
              notificationStore: FakeNotificationStore(),
              messagingService: FakeMessagingService(),
            ),
          ),
        );

        // MemberGate initState schedules the dialog and sign-out post-frame
        await tester.pump();
        expect(fakeAuth.signOutCallCount, 1);
        expect(fakeMember.ensuredUids, isEmpty);
        expect(find.text('Not a student address'), findsOneWidget);
        expect(find.textContaining('outsider@gmail.com'), findsOneWidget);
        expect(
          find.textContaining('is not a valid UM student address'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Please use a valid UM student gmail to proceed'),
          findsOneWidget,
        );

        // Verify pop-in spring animation components
        expect(find.byType(ScaleTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);

        // Dismiss the error dialog cleanly
        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Not a student address'), findsNothing);
      },
    );

    testWidgets(
      '_MemberSplash displays "Cancel & Sign Out" and triggers sign-out',
      (WidgetTester tester) async {
        var signedOut = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: _MemberSplash(
              onSignOut: () async => signedOut = true,
              fallbackDelay: const Duration(seconds: 4),
            ),
          ),
        );

        // Initially within 4s, the escape hatch is not visible
        expect(find.text('Cancel & Sign Out'), findsNothing);
        expect(find.text('LOADING MARKET'), findsOneWidget);

        // Fast forward 4 seconds
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Cancel & Sign Out'), findsOneWidget);

        // Tapping triggers onSignOut
        await tester.tap(find.text('Cancel & Sign Out'));
        await tester.pump();
        expect(signedOut, isTrue);
      },
    );

    testWidgets(
      '_MemberSplash immediately renders escape button with zero delay',
      (WidgetTester tester) async {
        var signedOut = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: _MemberSplash(
              onSignOut: () async => signedOut = true,
              fallbackDelay: Duration.zero,
            ),
          ),
        );

        expect(find.text('Cancel & Sign Out'), findsOneWidget);
        await tester.tap(find.text('Cancel & Sign Out'));
        await tester.pump();
        expect(signedOut, isTrue);
      },
    );

    testWidgets(
      'MemberGate handles ensureMemberAccount failure gracefully and signs out with error dialog',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();
        final fakeMember = FakeMemberStore()
          ..ensureError = Exception('Firestore permission denied');

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: MemberGate(
              authUser: const AuthUser(
                uid: 'student-uid',
                email: 'l.murillo.546842@umindanao.edu.ph',
                displayName: 'L. Murillo',
              ),
              authService: fakeAuth,
              memberStore: fakeMember,
              listingsStore: FakeListingsStore(),
              chatStore: FakeChatStore(),
              ratingStore: FakeRatingStore(),
              reportStore: FakeReportStore(),
              notificationStore: FakeNotificationStore(),
              messagingService: FakeMessagingService(),
            ),
          ),
        );

        // Allow async ensureMemberAccount to throw and catch
        await tester.pump();
        await tester.pump();

        expect(fakeAuth.signOutCallCount, 1);
        expect(find.text('Account error'), findsOneWidget);
        expect(
          find.text('Could not access member account. Please sign in again.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Account error'), findsNothing);
      },
    );

    testWidgets(
      'MemberGate handles ensureMemberAccount timeout gracefully and signs out',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();
        final fakeMember = FakeMemberStore()
          ..ensureDelay = const Duration(seconds: 10);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: MemberGate(
              authUser: const AuthUser(
                uid: 'student-timeout',
                email: 'l.murillo.546842@umindanao.edu.ph',
                displayName: 'L. Murillo',
              ),
              authService: fakeAuth,
              memberStore: fakeMember,
              listingsStore: FakeListingsStore(),
              chatStore: FakeChatStore(),
              ratingStore: FakeRatingStore(),
              reportStore: FakeReportStore(),
              notificationStore: FakeNotificationStore(),
              messagingService: FakeMessagingService(),
            ),
          ),
        );

        // Advance 8 seconds to trigger .timeout()
        await tester.pump(const Duration(seconds: 8));
        await tester.pump();

        expect(fakeAuth.signOutCallCount, 1);
        expect(find.text('Account error'), findsOneWidget);
        expect(
          find.text('Could not access member account. Please sign in again.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Account error'), findsNothing);
      },
    );

    testWidgets(
      'MemberGate handles snapshot stream error gracefully and signs out',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();
        final fakeMember = FakeMemberStore();

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: MemberGate(
              authUser: const AuthUser(
                uid: 'stream-err-uid',
                email: 'l.murillo.546842@umindanao.edu.ph',
                displayName: 'L. Murillo',
              ),
              authService: fakeAuth,
              memberStore: fakeMember,
              listingsStore: FakeListingsStore(),
              chatStore: FakeChatStore(),
              ratingStore: FakeRatingStore(),
              reportStore: FakeReportStore(),
              notificationStore: FakeNotificationStore(),
              messagingService: FakeMessagingService(),
            ),
          ),
        );

        fakeMember.emitError(
          'stream-err-uid',
          Exception('Firestore stream disconnected'),
        );
        await tester.pump();
        await tester.pump();

        expect(fakeAuth.signOutCallCount, 1);
        expect(find.text('Account error'), findsOneWidget);
        expect(
          find.text('Could not access member account. Please sign in again.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Account error'), findsNothing);
      },
    );
  });

  group('BrutalShimmer and BrutalSkeletonBox', () {
    testWidgets(
      'BrutalSkeletonBox renders with specified dimensions, border, and color',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrutalSkeletonBox(
                width: 120,
                height: 40,
                borderRadius: BorderRadius.circular(10),
                hasBorder: true,
                borderColor: UmColors.ink,
                borderWidth: 3.0,
                color: UmColors.gold,
                child: const Text('Loading...'),
              ),
            ),
          ),
        );

        final boxFinder = find.byType(BrutalSkeletonBox);
        expect(boxFinder, findsOneWidget);
        expect(find.text('Loading...'), findsOneWidget);

        final container = tester.widget<Container>(
          find.descendant(of: boxFinder, matching: find.byType(Container)),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(
          container.constraints?.tighten(width: 120, height: 40).minWidth,
          120,
        );
        expect(decoration.color, UmColors.gold);
        expect(decoration.borderRadius, BorderRadius.circular(10));
        expect(decoration.border, isNotNull);
        final border = decoration.border as Border;
        expect(border.top.color, UmColors.ink);
        expect(border.top.width, 3.0);
      },
    );

    testWidgets(
      'BrutalShimmer advances animation with tester.pump without error',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: BrutalShimmer(
                child: BrutalSkeletonBox(width: 100, height: 20),
              ),
            ),
          ),
        );

        expect(find.byType(BrutalShimmer), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(BrutalShimmer), findsOneWidget);
      },
    );
  });

  group('ProductCardSkeleton and Feed Integration', () {
    testWidgets(
      'ProductCardSkeleton renders image, title, category/condition, and price placeholders with BrutalShimmer',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 300,
                child: ProductCardSkeleton(),
              ),
            ),
          ),
        );

        expect(find.byType(ProductCardSkeleton), findsOneWidget);
        expect(find.byType(BrutalShimmer), findsOneWidget);
        expect(find.byType(AspectRatio), findsOneWidget);

        // AspectRatio check (4 / 3)
        final aspectRatioWidget = tester.widget<AspectRatio>(
          find.byType(AspectRatio),
        );
        expect(aspectRatioWidget.aspectRatio, 4 / 3);

        // Outer container decoration check
        final cardContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ProductCardSkeleton),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = cardContainer.decoration as BoxDecoration;
        expect(decoration.color, UmColors.surface);
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect(decoration.border, isNotNull);
        final border = decoration.border as Border;
        expect(border.top.color, UmColors.ink);
        expect(border.top.width, 2.0);
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.first.offset, UmShadows.card);

        // BrutalSkeletonBox instances: title, 2 pills, and price
        final skeletonBoxes = find.byType(BrutalSkeletonBox);
        expect(skeletonBoxes, findsNWidgets(4));

        // Shimmer animation ticks without error
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ProductCardSkeleton), findsOneWidget);
      },
    );

    testWidgets(
      'HomeScreen renders ProductCardSkeleton grid when listings stream has not emitted data yet',
      (WidgetTester tester) async {
        final fakeMemberStore = FakeMemberStore();
        final fakeListingsStore = FakeListingsStore();
        final fakeChatStore = FakeChatStore();
        final fakeRatingStore = FakeRatingStore();
        final fakeReportStore = FakeReportStore();

        const testMember = Member(
          uid: 'student-1',
          email: 's.one.123456@umindanao.edu.ph',
          displayName: 'Student One',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: HomeScreen(
              member: testMember,
              memberStore: fakeMemberStore,
              listingsStore: fakeListingsStore,
              chatStore: fakeChatStore,
              ratingStore: fakeRatingStore,
              reportStore: fakeReportStore,
            ),
          ),
        );

        // When listingsStore has not emitted any data (snapshot.data is null),
        // 4 ProductCardSkeleton widgets should be rendered in the feed skeleton grid.
        expect(find.byType(ProductCardSkeleton), findsNWidgets(4));

        // When listings are emitted, skeletons are replaced by listing cards
        fakeListingsStore.listings = [
          Listing(
            id: 'listing-1',
            sellerId: 'student-2',
            title: 'Engineering Mechanics',
            description: 'Good condition',
            price: 450.0,
            category: 'textbooks',
            condition: 'Good',
            createdAt: DateTime(2026, 8, 28),
          ),
        ];
        fakeListingsStore.emitListings();
        await tester.pump();

        expect(find.byType(ProductCardSkeleton), findsNothing);
        expect(find.byType(ListingCard), findsOneWidget);
        expect(find.text('Engineering Mechanics'), findsOneWidget);
      },
    );

    testWidgets(
      'BrowseScreen renders ProductCardSkeleton grid when listings stream has not emitted data yet',
      (WidgetTester tester) async {
        usePortraitPhone(tester);
        final fakeMemberStore = FakeMemberStore();
        final fakeListingsStore = FakeListingsStore();
        final fakeChatStore = FakeChatStore();
        final fakeRatingStore = FakeRatingStore();
        final fakeReportStore = FakeReportStore();

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: BrowseScreen(
              viewerUid: 'student-1',
              memberStore: fakeMemberStore,
              listingsStore: fakeListingsStore,
              chatStore: fakeChatStore,
              ratingStore: fakeRatingStore,
              reportStore: fakeReportStore,
            ),
          ),
        );

        // Browse screen initial loading state renders 4 ProductCardSkeletons
        expect(find.byType(ProductCardSkeleton), findsNWidgets(4));

        // Once listings are emitted, skeletons are replaced
        fakeListingsStore.listings = [
          Listing(
            id: 'listing-2',
            sellerId: 'student-3',
            title: 'Scientific Calculator',
            description: 'Like new',
            price: 800.0,
            category: 'gadgets',
            condition: 'Like New',
            createdAt: DateTime(2026, 8, 28),
          ),
        ];
        fakeListingsStore.emitListings();
        await tester.pump();

        expect(find.byType(ProductCardSkeleton), findsNothing);
        expect(find.byType(ListingCard), findsOneWidget);
        expect(find.text('Scientific Calculator'), findsOneWidget);
      },
    );
  });

  group('ListingDetailSkeleton', () {
    testWidgets(
      'ListingDetailSkeleton renders BrutalAppBar, hero frame, price block, seller strip, and BrutalShimmer',
      (WidgetTester tester) async {
        usePortraitPhone(tester);
        await tester.pumpWidget(
          const MaterialApp(home: ListingDetailSkeleton()),
        );

        expect(find.byType(ListingDetailSkeleton), findsOneWidget);
        expect(find.byType(BrutalAppBar), findsOneWidget);
        expect(find.text('LISTING'), findsOneWidget);
        expect(find.byType(BrutalShimmer), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);

        // AspectRatio check (4 / 3 hero photo placeholder)
        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);
        final aspectRatio = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(aspectRatio.aspectRatio, 4 / 3);

        // Hero photo container decoration check
        final heroContainer = tester.widget<Container>(
          find
              .descendant(
                of: aspectRatioFinder,
                matching: find.byType(Container),
              )
              .first,
        );
        final heroDecoration = heroContainer.decoration as BoxDecoration;
        expect(heroDecoration.color, UmColors.muted);
        expect(heroDecoration.borderRadius, BorderRadius.circular(8));
        expect(heroDecoration.border, isNotNull);
        final heroBorder = heroDecoration.border as Border;
        expect(heroBorder.top.color, UmColors.ink);
        expect(heroBorder.top.width, 2.0);
        expect(heroDecoration.boxShadow, isNotNull);
        expect(heroDecoration.boxShadow!.first.offset, UmShadows.card);

        // BrutalSkeletonBox components check:
        // - price pill (height: 32, Color(0xFFDCFCE7))
        // - condition pill (height: 20)
        // - title line 1 (height: 20)
        // - title line 2 (height: 16)
        // - category chip (height: 24)
        // - location chip (height: 24)
        // - avatar box (44x44, hasBorder: true)
        // - seller name (height: 14)
        // - seller verified badge (height: 12)
        // - description line 1 (height: 14)
        // - description line 2 (height: 14)
        final skeletonBoxes = find.byType(BrutalSkeletonBox);
        expect(skeletonBoxes, findsNWidgets(11));

        // Shimmer animation progression
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ListingDetailSkeleton), findsOneWidget);
      },
    );
  });

  group('Chats and ChatThread Skeletons', () {
    testWidgets(
      'ChatsScreen renders high-fidelity chat row skeletons when chats stream is loading',
      (WidgetTester tester) async {
        final fakeChatStore = FakeChatStore();
        // Stream pending — snapshot.data is null.

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: ChatsScreen(
              viewerUid: 'buyer-1',
              chatStore: fakeChatStore,
              memberStore: FakeMemberStore(),
              listingsStore: FakeListingsStore(),
              ratingStore: FakeRatingStore(),
              reportStore: FakeReportStore(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Conversations'), findsOneWidget);
        expect(find.byType(BrutalShimmer), findsWidgets);

        // Once chats are emitted, skeletons are replaced by real rows.
        fakeChatStore.chats['chat-1'] = sampleChat();
        fakeChatStore.emitList();
        await tester.pump();

        expect(find.byType(BrutalShimmer), findsNothing);
        expect(find.text('J. Dela Cruz'), findsOneWidget);
      },
    );

    testWidgets(
      'ChatThreadScreen renders thread skeleton while listing and messages are loading',
      (WidgetTester tester) async {
        usePortraitPhone(tester);
        final fakeChatStore = FakeChatStore();
        final fakeListingsStore = FakeListingsStore();
        // Neither the listing nor the messages have emitted yet.

        await tester.pumpWidget(
          threadApp(fakeChatStore, fakeListingsStore, FakeMemberStore()),
        );
        await tester.pump();

        expect(find.byType(BrutalShimmer), findsWidgets);

        // Emitting the listing swaps the full-thread skeleton for the real
        // pinned card; messages are still pending, so the bubble skeleton
        // shows inside the real body.
        fakeListingsStore.emitListing(
          'l1',
          Listing(
            id: 'l1',
            sellerId: 'seller-1',
            title: 'Desk lamp',
            description: 'LED study lamp',
            price: 150.0,
            category: 'gadgets',
            condition: 'Good',
            createdAt: DateTime(2026, 8, 28),
          ),
        );
        await tester.pump();
        expect(find.text('Desk lamp'), findsOneWidget);
        expect(find.byType(BrutalShimmer), findsOneWidget);

        // Once the (empty) messages arrive, the bubble skeleton is replaced
        // by the empty-state prompt.
        fakeChatStore.emitMessages(chatIdFor('l1', 'buyer-1'));
        await tester.pump();

        expect(find.byType(BrutalShimmer), findsNothing);
      },
    );
  });

  group('Profile, Notifications, and Moderation Skeletons', () {
    testWidgets(
      'NotificationCenterScreen renders notification row skeletons when stream is loading',
      (WidgetTester tester) async {
        final fakeNotifs = FakeNotificationStore();
        // Stream pending — snapshot.data is null.

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: NotificationCenterScreen(
              ownerId: 'test-owner',
              notificationStore: fakeNotifs,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('NOTIFICATIONS'), findsOneWidget);
        expect(find.byType(BrutalShimmer), findsWidgets);

        // Once the (empty) notifications arrive, the skeleton is replaced
        // by the empty state.
        fakeNotifs.emit();
        await tester.pump();

        expect(find.byType(BrutalShimmer), findsNothing);
        expect(find.textContaining('Nothing here yet'), findsOneWidget);
      },
    );

    testWidgets(
      'ModerationScreen renders report card skeletons when reports stream is loading',
      (WidgetTester tester) async {
        final fakeReports = FakeReportStore();
        // Stream pending — snapshot.data is null.

        await tester.pumpWidget(
          MaterialApp(
            theme: buildUmTheme(),
            home: ModerationScreen(
              memberStore: FakeMemberStore(),
              listingsStore: FakeListingsStore(),
              reportStore: fakeReports,
              chatStore: FakeChatStore(),
              ratingStore: FakeRatingStore(),
              viewerId: 'admin-id',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Open reports'), findsOneWidget);
        expect(find.byType(BrutalShimmer), findsWidgets);

        // Once the (empty) reports arrive, the skeleton is replaced by the
        // clear-inbox state.
        fakeReports.emitOpen();
        await tester.pump();

        expect(find.byType(BrutalShimmer), findsNothing);
        expect(find.textContaining('inbox is clear'), findsOneWidget);
      },
    );
  });

  group('BrutalPageRoute and BrutalPageTransitionsBuilder transitions', () {
    test(
      'BrutalPageRoute duration parameters match DESIGN.md motion tokens',
      () {
        final route = BrutalPageRoute<void>(builder: (_) => const SizedBox());
        expect(route.transitionDuration, const Duration(milliseconds: 180));
        expect(
          route.reverseTransitionDuration,
          const Duration(milliseconds: 150),
        );
      },
    );

    testWidgets(
      'BrutalPageRoute animates with RepaintBoundary and finishes cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      BrutalPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Destination Screen')),
                      ),
                    );
                  },
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Go'));
        await tester.pump(); // Start navigation

        // Mid-animation: RepaintBoundary and transitions should be present
        await tester.pump(const Duration(milliseconds: 90));
        expect(find.byType(RepaintBoundary), findsWidgets);
        expect(find.byType(SlideTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);

        // Settle animation
        await tester.pumpAndSettle();
        expect(find.text('Destination Screen'), findsOneWidget);
      },
    );

    testWidgets('Reduced motion bypasses slide and fade transitions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      BrutalPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Accessible Screen')),
                      ),
                    );
                  },
                  child: const Text('Go Accessible'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go Accessible'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Accessible Screen'), findsOneWidget);
    });
  });
}
