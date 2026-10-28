import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_delivery_bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';

class FakeReportDelivery extends Fake implements ReportDelivery {
  final reports = <PdfReport>[];
  late Future<ReportDeliveryOutcome> Function() handler;

  @override
  Future<ReportDeliveryOutcome> save(PdfReport report) {
    reports.add(report);
    return handler();
  }
}

void main() {
  final report = PdfReport(bytes: const [1, 2, 3], filename: 'private.pdf');
  late FakeReportDelivery delivery;
  late ReportDeliveryBloc bloc;
  late List<ReportDeliveryState> states;
  late StreamSubscription<ReportDeliveryState> subscription;
  setUp(() {
    delivery = FakeReportDelivery();
    bloc = ReportDeliveryBloc(delivery: delivery);
    states = [];
    subscription = bloc.stream.listen(states.add);
  });
  tearDown(() async {
    await bloc.close();
    await subscription.cancel();
  });

  test('starts idle without any file operation', () {
    expect(bloc.state, const ReportDeliveryInitial());
    expect(delivery.reports, isEmpty);
  });
  for (final outcome in ReportDeliveryOutcome.values) {
    test('publishes the actual delivery outcome: $outcome', () async {
      delivery.handler = () async => outcome;
      bloc.add(ReportSaveRequested(report));
      await pumpEventQueue();
      expect(states, [
        ReportSaving(report: report),
        ReportDelivered(report: report, outcome: outcome),
      ]);
      expect(delivery.reports.single, same(report));
    });
  }
  for (final error in <Object>[
    PlatformException(code: 'write_failed', message: 'private path/token'),
    UnsupportedError('private details'),
  ]) {
    test(
      'file error becomes a safe, separate save failure (${error.runtimeType})',
      () async {
        delivery.handler = () async {
          if (error is Error) throw error;
          throw error as Exception;
        };
        bloc.add(ReportSaveRequested(report));
        await pumpEventQueue();
        expect(states, [
          ReportSaving(report: report),
          ReportSaveFailure(report: report),
        ]);
        final failure = bloc.state as ReportSaveFailure;
        expect(failure.failure.code, 'PDF_SAVE_ERROR');
        expect(
          failure.failure.message,
          'Could not save the PDF. Please try again.',
        );
        expect(failure.toString(), isNot(contains('private')));
      },
    );
  }
  test('duplicate save taps are ignored while the dialog is pending', () async {
    final pending = Completer<ReportDeliveryOutcome>();
    delivery.handler = () => pending.future;
    for (var i = 0; i < 4; i++) {
      bloc.add(ReportSaveRequested(report));
    }
    await pumpEventQueue();
    expect(delivery.reports, hasLength(1));
    expect(states, [ReportSaving(report: report)]);
    pending.complete(ReportDeliveryOutcome.saved);
    await pumpEventQueue();
    expect(
      bloc.state,
      ReportDelivered(report: report, outcome: ReportDeliveryOutcome.saved),
    );
  });
  test(
    'manual retry after failure reuses the same PDF without generation',
    () async {
      delivery.handler = () async => throw Exception('private');
      bloc.add(ReportSaveRequested(report));
      await pumpEventQueue();
      delivery.handler = () async => ReportDeliveryOutcome.saved;
      bloc.add(ReportSaveRequested(report));
      await pumpEventQueue();
      expect(delivery.reports, [report, report]);
      expect(
        bloc.state,
        ReportDelivered(report: report, outcome: ReportDeliveryOutcome.saved),
      );
    },
  );
  for (final fails in [false, true]) {
    test('close suppresses a late save completion (failure: $fails)', () async {
      final pending = Completer<ReportDeliveryOutcome>();
      delivery.handler = () => pending.future;
      bloc.add(ReportSaveRequested(report));
      await pumpEventQueue();
      final closing = bloc.close();
      if (fails) {
        pending.completeError(Exception('private'));
      } else {
        pending.complete(ReportDeliveryOutcome.saved);
      }
      await closing;
      expect(states, [ReportSaving(report: report)]);
      expect(bloc.isClosed, isTrue);
    });
  }
  test(
    'events/states compare by value and omit PDF payloads from debug strings',
    () {
      expect(ReportSaveRequested(report), ReportSaveRequested(report));
      expect(ReportSaving(report: report), ReportSaving(report: report));
      expect(
        ReportDelivered(report: report, outcome: ReportDeliveryOutcome.saved),
        isNot(
          ReportDelivered(
            report: report,
            outcome: ReportDeliveryOutcome.cancelled,
          ),
        ),
      );
      for (final value in <Object>[
        ReportSaveRequested(report),
        ReportSaving(report: report),
        ReportSaveFailure(report: report),
        ReportDelivered(report: report, outcome: ReportDeliveryOutcome.saved),
      ]) {
        expect(value.toString(), value.runtimeType.toString());
      }
    },
  );
}
