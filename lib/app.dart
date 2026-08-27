import 'package:flutter/material.dart';

import 'auth/auth_service.dart';
import 'auth/sign_in_screen.dart';
import 'home/home_screen.dart';
import 'theme/app_theme.dart';

/// Root of the app: theme + the auth gate (ADR 0001). Whichever screen is
/// shown next (feed, listings, …) hangs off this gate.
class UmMarketplaceApp extends StatelessWidget {
  const UmMarketplaceApp({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UM Marketplace',
      debugShowCheckedModeBanner: false,
      theme: buildUmTheme(),
      home: AuthGate(authService: authService),
    );
  }
}

/// Signed out → [SignInScreen]; signed in → [HomeScreen] (placeholder until
/// the marketplace screens exist).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.userChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(authService: authService);
        }
        return HomeScreen(user: user, onSignOut: authService.signOut);
      },
    );
  }
}