import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isar = await openIsar();
  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWith((ref) => isar),
      ],
      child: const VaultSpendApp(),
    ),
  );
}
