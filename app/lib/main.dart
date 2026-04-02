import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/logging/app_logging.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppLogging();
  await initializeFirebase();
  final isar = await openIsar();
  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWith((ref) => isar)],
      child: const VaultSpendApp(),
    ),
  );
}
