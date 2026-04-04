import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vaultspend/core/logging/sync_incident_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('SyncIncidentService stores incident details', () async {
    final service = SyncIncidentService();

    await service.add(
      entity: 'expense',
      operation: 'pull',
      stage: '_pullFromRemoteIfAvailable',
      error: 'network timeout',
    );

    final entries = await service.readAll();

    expect(entries.length, 1);
    expect(entries.first.entity, 'expense');
    expect(entries.first.operation, 'pull');
    expect(entries.first.stage, '_pullFromRemoteIfAvailable');
    expect(entries.first.error, contains('network timeout'));
  });

  test('SyncIncidentService keeps only max incident entries', () async {
    final service = SyncIncidentService();

    for (var i = 0; i < 170; i++) {
      await service.add(
        entity: 'subscription',
        operation: 'put_$i',
        stage: 'put',
        error: 'e$i',
      );
    }

    final entries = await service.readAll();

    expect(entries.length, 150);
    expect(entries.first.operation, 'put_169');
  });

  test('SyncIncidentService clear removes all entries', () async {
    final service = SyncIncidentService();

    await service.add(
      entity: 'category',
      operation: 'delete',
      stage: 'delete',
      error: 'fail',
    );

    await service.clear();

    final entries = await service.readAll();
    expect(entries, isEmpty);
  });
}
