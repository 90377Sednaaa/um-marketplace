import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'auth/sign_in_screen.dart';
import 'data/chat_store.dart';
import 'data/listing_store.dart';
import 'data/member_store.dart';
import 'data/rating_store.dart';
import 'data/report_store.dart';
import 'data/notification_store.dart';
import 'data/messaging_service.dart';
import 'members/member_gate.dart';
import 'theme/app_theme.dart';

/// Root of the app: theme + the auth gate (ADR 0001/0008) + the member
/// account resolution (ADR 0007). Screens hang off this gate.
class UmMarketplaceApp extends StatelessWidget {
  const UmMarketplaceApp({
    super.key,
    required this.authService,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.notificationStore,
    required this.messagingService,
  });

  final AuthService authService;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final NotificationStore notificationStore;
  final MessagingService messagingService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UM Marketplace',
      debugShowCheckedModeBanner: false,
      theme: buildUmTheme(),
      home: AuthGate(
        authService: authService,
        memberStore: memberStore,
        listingsStore: listingsStore,
        chatStore: chatStore,
        ratingStore: ratingStore,
        reportStore: reportStore,
        notificationStore: notificationStore,
        messagingService: messagingService,
      ),
    );
  }
}

/// Signed out → [SignInScreen]; signed in → [MemberGate], which creates
/// the Member Account if needed and shows the shell (or the banned screen).
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.memberStore,
    required this.listingsStore,
    required this.chatStore,
    required this.ratingStore,
    required this.reportStore,
    required this.notificationStore,
    required this.messagingService,
  });

  final AuthService authService;
  final MemberStore memberStore;
  final ListingStore listingsStore;
  final ChatStore chatStore;
  final RatingStore ratingStore;
  final ReportStore reportStore;
  final NotificationStore notificationStore;
  final MessagingService messagingService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.userChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(authService: authService);
        }
        return MemberGate(
          // A new state per user so ensure/create runs once per account.
          key: ValueKey(user.uid),
          authUser: user,
          authService: authService,
          memberStore: memberStore,
          listingsStore: listingsStore,
          chatStore: chatStore,
          ratingStore: ratingStore,
          reportStore: reportStore,
          notificationStore: notificationStore,
          messagingService: messagingService,
        );
      },
    );
  }
}
