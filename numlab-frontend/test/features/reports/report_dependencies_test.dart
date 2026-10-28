import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/reports/data/datasources/report_remote_data_source.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/domain/repositories/report_repository.dart';
import 'package:numlab_frontend/features/reports/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_delivery_bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/injection_container.dart';

import 'report_test_support.dart';

class FakeDomainReportRepository extends Fake implements ReportRepository {
  final report = PdfReport(bytes: const [1, 2, 3]);
  final runIds = <String>[];

  @override
  Future<Either<Failure, PdfReport>> generateReport(String runId) async {
    runIds.add(runId);
    return Right(report);
  }
}

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





  test('registers one delivery adapter and isolated delivery BLoCs', () async {
    expect(sl<ReportDelivery>(), isA<FilePickerReportDelivery>());
    expect(sl<ReportDelivery>(), same(sl<ReportDelivery>()));
    final first = sl<ReportDeliveryBloc>();
    final second = sl<ReportDeliveryBloc>();
    expect(first, isNot(same(second)));
    expect(first.state, const ReportDeliveryInitial());
    expect(second.state, const ReportDeliveryInitial());
    await first.close();
    await second.close();
  });

  test('registers the report use case as a lazy singleton', () {
    expect(sl.isRegistered<GenerateReportUseCase>(), isTrue);
    expect(sl<GenerateReportUseCase>(), same(sl<GenerateReportUseCase>()));
  });

  test(
    'report BLoC factory creates isolated instances using the existing use case',
    () async {
      final repository = FakeDomainReportRepository();
      await sl.unregister<ReportRepository>();
      sl.registerSingleton<ReportRepository>(repository);
      final adapter = ReportAdapter(
        (_) async => throw StateError('Unexpected HTTP request'),
      );
      sl<Dio>().httpClientAdapter = adapter;
      expect(sl.isRegistered<ReportBloc>(), isTrue);
      final first = sl<ReportBloc>();
      final second = sl<ReportBloc>();
      try {
        expect(first, isNot(same(second)));
        first.add(const ReportRequested(runId: reportRunId));
        await expectLater(
          first.stream,
          emitsInOrder([
            const ReportLoading(runId: reportRunId),
            ReportSuccess(runId: reportRunId, report: repository.report),
          ]),
        );
        expect(second.state, const ReportInitial());
        expect(repository.runIds, [reportRunId]);
        expect(adapter.requests, isEmpty);
      } finally {
        await first.close();
        await second.close();
      }
    },
  );

  test(
    'registered use case delegates to the registered repository without HTTP',
    () async {
      final repository = FakeDomainReportRepository();
      await sl.unregister<ReportRepository>();
      sl.registerSingleton<ReportRepository>(repository);
      final adapter = ReportAdapter(
        (_) async => throw StateError('Unexpected HTTP request'),
      );
      sl<Dio>().httpClientAdapter = adapter;

      final result = await sl<GenerateReportUseCase>()(reportRunId);

      expect(repository.runIds, [reportRunId]);
      expect(result, Right<Failure, PdfReport>(repository.report));
      expect(adapter.requests, isEmpty);
    },
  );

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
