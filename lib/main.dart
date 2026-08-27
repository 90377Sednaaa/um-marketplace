import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'data/listing_store.dart';
import 'data/member_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    UmMarketplaceApp(
      authService: FirebaseAuthService(),
      memberStore: FirestoreMemberStore(),
      listingsStore: FirestoreListingsStore(),
    ),
  );
}