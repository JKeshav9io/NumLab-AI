import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_delivery_bloc.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_sharing.dart';

import 'report_delivery_bloc_test.dart';

class TestReportSharing implements ReportSharing {
  final reports = <PdfReport>[];
  final origins = <Rect>[];
  late Future<ReportShareOutcome> Function() handler;
  @override
  Future<ReportShareOutcome> share(PdfReport report, {required Rect origin}) {
    reports.add(report);
    origins.add(origin);
    return handler();
  }
}

void main() {
  final report = PdfReport(bytes: const [1, 255, 0], filename: 'private.pdf');
  const origin = Rect.fromLTWH(10, 20, 100, 40);
  late FakeReportDelivery delivery;
  late TestReportSharing sharing;
  late ReportDeliveryBloc bloc;
  late StreamSubscription<ReportDeliveryState> subscription;
  late List<ReportDeliveryState> states;
  setUp(() {
    delivery = FakeReportDelivery()
      ..handler = () async => ReportDeliveryOutcome.saved;
    sharing = TestReportSharing()
      ..handler = () async => ReportShareOutcome.targetSelected;
    bloc = ReportDeliveryBloc(delivery: delivery, sharing: sharing);
    states = [];
    subscription = bloc.stream.listen(states.add);
  });
  tearDown(() async {
    await bloc.close();
    await subscription.cancel();
  });

  test('reuses the idle delivery BLoC without initiating any operation', () {
    expect(bloc.state, const ReportDeliveryInitial());
    expect(bloc.supportsSharing, isTrue);
    expect(sharing.reports, isEmpty);
    expect(delivery.reports, isEmpty);
  });
  for (final outcome in ReportShareOutcome.values) {
    test('emits in-progress and the exact share outcome: $outcome', () async {
      sharing.handler = () async => outcome;
      bloc.add(ReportShareRequested(report, origin: origin));
      await pumpEventQueue();
      expect(states, [
        ReportSharingInProgress(report: report),
        ReportShareFinished(report: report, outcome: outcome),
      ]);
      expect(sharing.reports.single, same(report));
      expect(sharing.origins, [origin]);
      expect(delivery.reports, isEmpty);
    });
  }
  for (final error in <Object>[
    PlatformException(code: 'failed', message: 'private target'),
    StateError('private bytes'),
  ]) {
    test('share failure is safe and distinct: ${error.runtimeType}', () async {
      sharing.handler = () async {
        if (error is Error) throw error;
        throw error as Exception;
      };
      bloc.add(ReportShareRequested(report, origin: origin));
      await pumpEventQueue();
      expect(states, [
        ReportSharingInProgress(report: report),
        ReportShareFailure(report: report),
      ]);
      final failed = bloc.state as ReportShareFailure;
      expect(failed.failure.code, 'PDF_SHARE_ERROR');
      expect(
        failed.failure.message,
        'Could not open sharing. Try again, or use Save PDF.',
      );
      expect(failed.toString(), isNot(contains('private')));
    });
  }
  test(
    'duplicate share requests and save are ignored while sharing is pending',
    () async {
      final pending = Completer<ReportShareOutcome>();
      sharing.handler = () => pending.future;
      bloc
        ..add(ReportShareRequested(report, origin: origin))
        ..add(ReportShareRequested(report, origin: origin))
        ..add(ReportSaveRequested(report));
      await pumpEventQueue();
      expect(sharing.reports, hasLength(1));
      expect(delivery.reports, isEmpty);
      expect(states, [ReportSharingInProgress(report: report)]);
      pending.complete(ReportShareOutcome.cancelled);
      await pumpEventQueue();
    },
  );
  test('a pending save prevents a competing share operation', () async {
    final pending = Completer<ReportDeliveryOutcome>();
    delivery.handler = () => pending.future;
    bloc
      ..add(ReportSaveRequested(report))
      ..add(ReportShareRequested(report, origin: origin));
    await pumpEventQueue();
    expect(sharing.reports, isEmpty);
    expect(delivery.reports, hasLength(1));
    pending.complete(ReportDeliveryOutcome.saved);
    await pumpEventQueue();
    expect(
      bloc.state,
      ReportDelivered(report: report, outcome: ReportDeliveryOutcome.saved),
    );
  });
  test('manual retry after share failure reuses the existing report', () async {
    sharing.handler = () async => throw Exception('private');
    bloc.add(ReportShareRequested(report, origin: origin));
    await pumpEventQueue();
    sharing.handler = () async => ReportShareOutcome.targetSelected;
    bloc.add(ReportShareRequested(report, origin: origin));
    await pumpEventQueue();
    expect(sharing.reports, [report, report]);
    expect(
      bloc.state,
      ReportShareFinished(
        report: report,
        outcome: ReportShareOutcome.targetSelected,
      ),
    );
  });
  test('saving remains available after cancellation', () async {
    sharing.handler = () async => ReportShareOutcome.cancelled;
    bloc.add(ReportShareRequested(report, origin: origin));
    await pumpEventQueue();
    bloc.add(ReportSaveRequested(report));
    await pumpEventQueue();
    expect(delivery.reports.single, same(report));
    expect(
      bloc.state,
      ReportDelivered(report: report, outcome: ReportDeliveryOutcome.saved),
    );
  });
  for (final fails in [false, true]) {
    test('closing suppresses late share completion: fails=$fails', () async {
      final pending = Completer<ReportShareOutcome>();
      sharing.handler = () => pending.future;
      bloc.add(ReportShareRequested(report, origin: origin));
      await pumpEventQueue();
      final closing = bloc.close();
      if (fails) {
        pending.completeError(Exception('private target'));
      } else {
        pending.complete(ReportShareOutcome.targetSelected);
      }
      await closing;
      expect(states, [ReportSharingInProgress(report: report)]);
      expect(bloc.isClosed, isTrue);
    });
  }
  test('share events/states use equality without exposing PDF content', () {
    expect(
      ReportShareRequested(report, origin: origin),
      ReportShareRequested(report, origin: origin),
    );
    expect(
      ReportShareRequested(report, origin: origin),
      isNot(ReportShareRequested(report, origin: Rect.zero)),
    );
    expect(
      ReportShareFinished(
        report: report,
        outcome: ReportShareOutcome.cancelled,
      ),
      isNot(
        ReportShareFinished(
          report: report,
          outcome: ReportShareOutcome.unconfirmed,
        ),
      ),
    );
    for (final value in <Object>[
      ReportShareRequested(report, origin: origin),
      ReportSharingInProgress(report: report),
      ReportShareFinished(
        report: report,
        outcome: ReportShareOutcome.targetSelected,
      ),
      ReportShareFailure(report: report),
    ]) {
      expect(value.toString(), value.runtimeType.toString());
    }
  });
  test(
    'a delivery-only instance handles unavailable sharing without a plugin call',
    () async {
      final subject = ReportDeliveryBloc(delivery: delivery);
      expect(subject.supportsSharing, isFalse);
      subject.add(ReportShareRequested(report, origin: origin));
      await pumpEventQueue();
      expect(
        subject.state,
        ReportShareFinished(
          report: report,
          outcome: ReportShareOutcome.unsupported,
        ),
      );
      await subject.close();
    },
  );
}
