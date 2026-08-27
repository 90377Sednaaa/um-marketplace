import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:um_marketplace/app.dart';
import 'package:um_marketplace/auth/auth_service.dart';

/// In-memory [AuthService] so widget tests never touch Firebase.
class FakeAuthService implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> get userChanges => _controller.stream;

  void emit(AuthUser? user) => _controller.add(user);

  @override
  Future<void> signInWithGoogle() async {
    emit(const AuthUser(
      email: 'l.murillo.546842@umindanao.edu.ph',
      displayName: 'L. Murillo',
    ));
  }

  @override
  Future<void> signOut() async => emit(null);
}

const _student = AuthUser(
  email: 'l.murillo.546842@umindanao.edu.ph',
  displayName: 'L. Murillo',
);

void main() {
  testWidgets('shows the Google sign-in gate when signed out',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(UmMarketplaceApp(authService: auth));
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('UM Marketplace'), findsOneWidget);
    expect(
      find.textContaining('l.murillo.546842@umindanao.edu.ph'),
      findsOneWidget,
    );
  });

  testWidgets('signed-in member lands on the home placeholder',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(UmMarketplaceApp(authService: auth));
    auth.emit(_student);
    await tester.pumpAndSettle();

    expect(find.text('L. Murillo'), findsOneWidget);
    expect(find.text('l.murillo.546842@umindanao.edu.ph'), findsOneWidget);
    expect(find.text('Verified UM student'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('signing out returns to the gate', (WidgetTester tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(UmMarketplaceApp(authService: auth));
    auth.emit(_student);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('sign-in updates the gate without user interaction',
      (WidgetTester tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(UmMarketplaceApp(authService: auth));
    await tester.pump();

    await auth.signInWithGoogle();
    await tester.pumpAndSettle();

    expect(find.text('L. Murillo'), findsOneWidget);
  });
}