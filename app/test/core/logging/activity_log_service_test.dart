import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaultspend/core/logging/activity_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('ActivityLogService stores and reads entries', () async {
    final service = ActivityLogService();

    await service.add(action: 'Action A', details: 'First');
    await service.add(action: 'Action B', details: 'Second');

    final entries = await service.readAll();

    expect(entries.length, 2);
    expect(entries.first.action, 'Action B');
    expect(entries.first.details, 'Second');
    expect(entries.last.action, 'Action A');
  });

  test('ActivityLogService clear removes all entries', () async {
    final service = ActivityLogService();

    await service.add(action: 'Action A');
    expect((await service.readAll()).isNotEmpty, isTrue);

    await service.clear();

    final entries = await service.readAll();
    expect(entries, isEmpty);
  });
}
