import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Isar requires native libs; full app tests run on device/integration.
/// This smoke test only verifies the test harness.
void main() {
  testWidgets('smoke: MaterialApp builds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('VaultSpend'),
        ),
      ),
    );
    expect(find.text('VaultSpend'), findsOneWidget);
  });
}
