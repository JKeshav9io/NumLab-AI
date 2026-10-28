import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/domain/usecases/generate_report_use_case.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/bloc.dart';

class FakeGenerateReportUseCase extends Fake implements GenerateReportUseCase {
  final runIds = <String>[];
  late Future<Either<Failure, PdfReport>> Function(String) handler;

  @override
  Future<Either<Failure, PdfReport>> call(String runId) {
    runIds.add(runId);
    return handler(runId);
  }
}

void main() {
  const runA = '550e8400-e29b-41d4-a716-446655440000';
  const runB = '550e8400-e29b-41d4-a716-446655440001';
  const failure = NetworkFailure(
    message: 'The request timed out',
    code: 'REQUEST_TIMEOUT',
  );
  final reportA = PdfReport(
    bytes: const [0x25, 0x50, 0xff],
    filename: 'server.pdf',
  );
  final reportB = PdfReport(bytes: const [0x25, 0x50, 0xfe]);
  late FakeGenerateReportUseCase useCase;
  late ReportBloc bloc;
  late List<ReportState> states;
  late StreamSubscription<ReportState> subscription;

  setUp(() {
    useCase = FakeGenerateReportUseCase();
    bloc = ReportBloc(generateReportUseCase: useCase);
    states = [];
    subscription = bloc.stream.listen(states.add);
  });
  tearDown(() async {
    await bloc.close();
    await subscription.cancel();
  });

  test('starts idle without invoking the use case', () {
    expect(bloc.state, const ReportInitial());
    expect(useCase.runIds, isEmpty);
    expect(states, isEmpty);
  });

  for (final report in [reportA, reportB]) {
    test(
      'loads immediately and retains the exact result (filename: ${report.filename})',
      () async {
        final pending = Completer<Either<Failure, PdfReport>>();
        useCase.handler = (_) => pending.future;
        bloc.add(const ReportRequested(runId: runA));
        await pumpEventQueue();
        expect(states, [const ReportLoading(runId: runA)]);
        expect(useCase.runIds, [runA]);
        pending.complete(Right(report));
        await pumpEventQueue();
        expect(states, [
          const ReportLoading(runId: runA),
          ReportSuccess(runId: runA, report: report),
        ]);
        final success = bloc.state as ReportSuccess;
        expect(success.report, same(report));
        expect(success.report.bytes, same(report.bytes));
        expect(success.report.filename, report.filename);
        expect(useCase.runIds, [runA]);
      },
    );
  }

  for (final error in const <Failure>[
    AuthFailure(message: 'Authentication required'),
    ServerFailure(
      message: 'Failed to generate PDF report',
      code: 'REPORT_GENERATION_ERROR',
      statusCode: 500,
    ),
    failure,
    ValidationFailure(message: 'Invalid solver run ID'),
    RateLimitFailure(message: 'Report quota exceeded', retryAfterSeconds: 20),
  ]) {
    test(
      'preserves typed ${error.runtimeType} and its message without retry',
      () async {
        useCase.handler = (_) async => Left(error);
        bloc.add(const ReportRequested(runId: runA));
        await pumpEventQueue();
        expect(states, [
          const ReportLoading(runId: runA),
          ReportFailure(runId: runA, failure: error),
        ]);
        final failed = bloc.state as ReportFailure;
        expect(failed.failure, same(error));
        expect(failed.message, error.message);
        expect(useCase.runIds, [runA]);
      },
    );
  }

  test(
    'a manual request after failure starts loading and can succeed',
    () async {
      useCase.handler = (_) async => const Left(failure);
      bloc.add(const ReportRequested(runId: runA));
      await pumpEventQueue();
      useCase.handler = (_) async => Right(reportA);
      bloc.add(const ReportRequested(runId: runA));
      await pumpEventQueue();
      expect(states, [
        const ReportLoading(runId: runA),
        const ReportFailure(runId: runA, failure: failure),
        const ReportLoading(runId: runA),
        ReportSuccess(runId: runA, report: reportA),
      ]);
      expect(useCase.runIds, [runA, runA]);
    },
  );

  test(
    'a request after success releases the old success while loading',
    () async {
      useCase.handler = (_) async => Right(reportA);
      bloc.add(const ReportRequested(runId: runA));
      await pumpEventQueue();
      final pending = Completer<Either<Failure, PdfReport>>();
      useCase.handler = (_) => pending.future;
      bloc.add(const ReportRequested(runId: runA));
      await pumpEventQueue();
      expect(bloc.state, const ReportLoading(runId: runA));
      pending.complete(Right(reportB));
      await pumpEventQueue();
      expect(states, [
        const ReportLoading(runId: runA),
        ReportSuccess(runId: runA, report: reportA),
        const ReportLoading(runId: runA),
        ReportSuccess(runId: runA, report: reportB),
      ]);
      expect(useCase.runIds, [runA, runA]);
    },
  );

  test(
    'rapid duplicate taps during loading invoke the use case once',
    () async {
      final pending = Completer<Either<Failure, PdfReport>>();
      useCase.handler = (_) => pending.future;
      for (var i = 0; i < 5; i++) {
        bloc.add(const ReportRequested(runId: runA));
      }
      await pumpEventQueue();
      expect(states, [const ReportLoading(runId: runA)]);
      expect(useCase.runIds, [runA]);
      pending.complete(Right(reportA));
      await pumpEventQueue();
      expect(states, [
        const ReportLoading(runId: runA),
        ReportSuccess(runId: runA, report: reportA),
      ]);
    },
  );

  for (final oldFails in [false, true]) {
    for (final newFails in [false, true]) {
      for (final oldFirst in [false, true]) {
        test(
          'new run wins: oldFails=$oldFails newFails=$newFails oldFirst=$oldFirst',
          () async {
            final old = Completer<Either<Failure, PdfReport>>();
            final current = Completer<Either<Failure, PdfReport>>();
            useCase.handler = (id) => id == runA ? old.future : current.future;
            bloc.add(const ReportRequested(runId: runA));
            await pumpEventQueue();
            bloc.add(const ReportRequested(runId: runB));
            await pumpEventQueue();
            expect(states, [
              const ReportLoading(runId: runA),
              const ReportLoading(runId: runB),
            ]);
            final oldResult = oldFails
                ? const Left<Failure, PdfReport>(failure)
                : Right<Failure, PdfReport>(reportA);
            final newResult = newFails
                ? const Left<Failure, PdfReport>(failure)
                : Right<Failure, PdfReport>(reportB);
            final terminal = newFails
                ? const ReportFailure(runId: runB, failure: failure)
                : ReportSuccess(runId: runB, report: reportB);
            if (oldFirst) {
              old.complete(oldResult);
              await pumpEventQueue();
              expect(bloc.state, const ReportLoading(runId: runB));
              current.complete(newResult);
            } else {
              current.complete(newResult);
              await pumpEventQueue();
              expect(bloc.state, terminal);
              old.complete(oldResult);
            }
            await pumpEventQueue();
            expect(states, [
              const ReportLoading(runId: runA),
              const ReportLoading(runId: runB),
              terminal,
            ]);
            expect(useCase.runIds, [runA, runB]);
          },
        );
      }
    }
  }

  test(
    'A to B to A ignores the first A even though the run ID matches again',
    () async {
      final requests = List.generate(
        3,
        (_) => Completer<Either<Failure, PdfReport>>(),
      );
      useCase.handler = (_) => requests[useCase.runIds.length - 1].future;
      for (final id in [runA, runB, runA]) {
        bloc.add(ReportRequested(runId: id));
        await pumpEventQueue();
      }
      requests[0].complete(Right(reportA));
      requests[1].complete(const Left(failure));
      await pumpEventQueue();
      expect(bloc.state, const ReportLoading(runId: runA));
      requests[2].complete(Right(reportB));
      await pumpEventQueue();
      expect(states, [
        const ReportLoading(runId: runA),
        const ReportLoading(runId: runB),
        const ReportLoading(runId: runA),
        ReportSuccess(runId: runA, report: reportB),
      ]);
      expect(useCase.runIds, [runA, runB, runA]);
    },
  );

  for (final fails in [false, true]) {
    test('close ignores pending completion (failure: $fails)', () async {
      final pending = Completer<Either<Failure, PdfReport>>();
      useCase.handler = (_) => pending.future;
      bloc.add(const ReportRequested(runId: runA));
      await pumpEventQueue();
      final closing = bloc.close();
      pending.complete(fails ? const Left(failure) : Right(reportA));
      await closing;
      await pumpEventQueue();
      expect(bloc.isClosed, isTrue);
      expect(states, [const ReportLoading(runId: runA)]);
      expect(useCase.runIds, [runA]);
    });
  }

  test('closes cleanly while idle', () async {
    await bloc.close();
    expect(bloc.isClosed, isTrue);
    expect(states, isEmpty);
    expect(useCase.runIds, isEmpty);
  });

  test('request equality includes the run ID', () {
    expect(
      const ReportRequested(runId: runA),
      const ReportRequested(runId: runA),
    );
    expect(
      const ReportRequested(runId: runA),
      isNot(const ReportRequested(runId: runB)),
    );
  });

  test(
    'state equality includes run, result, and failure identity by value',
    () {
      expect(const ReportInitial(), const ReportInitial());
      expect(
        const ReportLoading(runId: runA),
        const ReportLoading(runId: runA),
      );
      expect(
        const ReportLoading(runId: runA),
        isNot(const ReportLoading(runId: runB)),
      );
      expect(
        ReportSuccess(runId: runA, report: reportA),
        ReportSuccess(runId: runA, report: reportA),
      );
      expect(
        ReportSuccess(runId: runA, report: reportA),
        isNot(ReportSuccess(runId: runB, report: reportA)),
      );
      expect(
        ReportSuccess(runId: runA, report: reportA),
        isNot(ReportSuccess(runId: runA, report: reportB)),
      );
      expect(
        const ReportFailure(runId: runA, failure: failure),
        const ReportFailure(runId: runA, failure: failure),
      );
      expect(
        const ReportFailure(runId: runA, failure: failure),
        isNot(const ReportFailure(runId: runB, failure: failure)),
      );
      expect(
        const ReportFailure(runId: runA, failure: failure),
        isNot(
          const ReportFailure(
            runId: runA,
            failure: AuthFailure(message: 'Unauthorized'),
          ),
        ),
      );
    },
  );

  test('debug strings do not expose event or state payloads', () {
    const private = 'private-report-marker';
    final report = PdfReport(bytes: const [99, 98, 97], filename: private);
    final values = <Object>[
      const ReportRequested(runId: private),
      const ReportInitial(),
      const ReportLoading(runId: private),
      ReportSuccess(runId: private, report: report),
      const ReportFailure(
        runId: private,
        failure: ServerFailure(message: private),
      ),
    ];
    for (final value in values) {
      expect(value.toString(), isNot(contains(private)));
      expect(value.toString(), isNot(contains('99')));
      expect(value.toString(), value.runtimeType.toString());
    }
  });
}
