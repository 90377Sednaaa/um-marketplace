import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'auth/sign_in_screen.dart';
import 'data/listing_store.dart';
import 'data/member_store.dart';
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
  });

  final AuthService authService;
  final MemberStore memberStore;
  final ListingStore listingsStore;

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
      ),
    );
  }
}

/// Signed out → [SignInScreen]; signed in → [MemberGate], which creates
/// the Member Account if needed and shows home (or the banned screen).
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.memberStore,
    required this.listingsStore,
  });

  final AuthService authService;
  final MemberStore memberStore;
  final ListingStore listingsStore;

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
        );
      },
    );
  }
}