import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/reports/data/datasources/report_remote_data_source.dart';
import 'package:numlab_frontend/features/reports/domain/repositories/report_repository.dart';
import 'package:numlab_frontend/injection_container.dart';

import 'report_test_support.dart';

void main() {
  setUp(() async {
    await sl.reset();
    await initDependencies();
    await sl.unregister<SecureStorageService>();
    sl.registerSingleton<SecureStorageService>(ReportStorage());
  });
  tearDown(() async {
    if (sl.isRegistered<Dio>()) sl<Dio>().close(force: true);
    await sl.reset();
  });

  test('registers datasource and repository as lazy singletons', () {
    expect(sl.isRegistered<ReportRemoteDataSource>(), isTrue);
    expect(sl.isRegistered<ReportRepository>(), isTrue);
    expect(sl<ReportRemoteDataSource>(), same(sl<ReportRemoteDataSource>()));
    expect(sl<ReportRepository>(), same(sl<ReportRepository>()));
  });













  test(
    'registered repository uses the existing configured Dio and auth',
    () async {
      final adapter = ReportAdapter((_) async => pdfResponse());
      sl<Dio>().httpClientAdapter = adapter;
      final result = await sl<ReportRepository>().generateReport(reportRunId);
      expect(result.isRight(), isTrue);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/reports/$reportRunId');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-access',
      );
      expect(adapter.requests.single.responseType, ResponseType.bytes);
    },
  );
}
