import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/domain/repositories/report_repository.dart';
import 'package:numlab_frontend/features/reports/domain/usecases/usecases.dart';

class FakeReportRepository extends Fake implements ReportRepository {
  final runIds = <String>[];
  late Either<Failure, PdfReport> result;

  @override
  Future<Either<Failure, PdfReport>> generateReport(String runId) async {
    runIds.add(runId);
    return result;
  }
}

void main() {
  const runId = '550E8400-E29B-41D4-A716-446655440000';
  late FakeReportRepository repository;
  late GenerateReportUseCase useCase;

  setUp(() {
    repository = FakeReportRepository();
    useCase = GenerateReportUseCase(repository);
  });

  for (final filename in ['server-report.pdf', null]) {
    test(
      'returns the existing PDF result unchanged (filename: $filename)',
      () async {
        final report = PdfReport(
          bytes: const [0x25, 0x50, 0x44, 0x46, 0xff],
          filename: filename,
        );
        final expected = Right<Failure, PdfReport>(report);
        repository.result = expected;

        final result = await useCase(runId);

        expect(repository.runIds, [runId]);
        expect(result, same(expected));
        result.fold((f) => fail('$f'), (value) {
          expect(value, same(report));
          expect(value.bytes, [0x25, 0x50, 0x44, 0x46, 0xff]);
          expect(value.filename, filename);
        });
      },
    );
  }

  test('delegates each explicit request with its own persisted UUID', () async {
    const otherRunId = '550e8400-e29b-41d4-a716-446655440001';
    repository.result = Right(PdfReport(bytes: const [1, 2, 3]));

    await useCase(runId);
    await useCase(otherRunId);

    expect(repository.runIds, [runId, otherRunId]);
  });

  const failures = <Failure>[
    AuthFailure(message: 'Authentication required'),
    ServerFailure(
      message: 'Solver run not found',
      code: 'NOT_FOUND',
      statusCode: 404,
    ),
    ServerFailure(
      message: 'Failed to generate PDF report',
      code: 'REPORT_GENERATION_ERROR',
      statusCode: 500,
    ),
    NetworkFailure(message: 'Unable to connect to NumLab server'),
    NetworkFailure(message: 'The request timed out', code: 'REQUEST_TIMEOUT'),
    ValidationFailure(
      message: 'Invalid solver run ID parameter',
      fieldErrors: [
        FieldError(field: '', message: '"runId" must be a valid GUID'),
      ],
    ),
    RateLimitFailure(
      message: 'Report generation quota exceeded',
      retryAfterSeconds: 45,
    ),
  ];
  for (final failure in failures) {
    test(
      'propagates ${failure.runtimeType} ${failure.code} unchanged without retry',
      () async {
        final expected = Left<Failure, PdfReport>(failure);
        repository.result = expected;

        final result = await useCase(runId);

        expect(repository.runIds, [runId]);
        expect(result, same(expected));
        result.fold(
          (value) => expect(value, same(failure)),
          (_) => fail('Expected failure'),
        );
      },
    );
  }
}
