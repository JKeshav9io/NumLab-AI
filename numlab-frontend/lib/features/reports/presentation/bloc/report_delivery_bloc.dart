import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_sharing.dart';

sealed class ReportDeliveryEvent extends Equatable {
  const ReportDeliveryEvent();

  @override
  bool get stringify => false;
}

final class ReportSaveRequested extends ReportDeliveryEvent {
  const ReportSaveRequested(this.report);

  final PdfReport report;

  @override
  List<Object?> get props => [report];
}

final class ReportShareRequested extends ReportDeliveryEvent {
  const ReportShareRequested(this.report, {required this.origin});
  final PdfReport report;
  final Rect origin;

  @override
  List<Object?> get props => [report, origin];
}

sealed class ReportDeliveryState extends Equatable {
  const ReportDeliveryState({this.report});

  final PdfReport? report;

  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [report];
}

final class ReportDeliveryInitial extends ReportDeliveryState {
  const ReportDeliveryInitial();
}

final class ReportSaving extends ReportDeliveryState {
  const ReportSaving({required PdfReport report}) : super(report: report);
}

final class ReportDelivered extends ReportDeliveryState {
  const ReportDelivered({required PdfReport report, required this.outcome})
    : super(report: report);

  final ReportDeliveryOutcome outcome;

  @override
  List<Object?> get props => [report, outcome];
}

final class ReportSaveFailure extends ReportDeliveryState {
  const ReportSaveFailure({required PdfReport report}) : super(report: report);

  // A delivery error is separate from backend generation, and never raw IO text.
  Failure get failure => const ServerFailure(
    message: 'Could not save the PDF. Please try again.',
    code: 'PDF_SAVE_ERROR',
  );
}

final class ReportSharingInProgress extends ReportDeliveryState {
  const ReportSharingInProgress({required PdfReport report})
    : super(report: report);
}

final class ReportShareFinished extends ReportDeliveryState {
  const ReportShareFinished({required PdfReport report, required this.outcome})
    : super(report: report);
  final ReportShareOutcome outcome;

  @override
  List<Object?> get props => [report, outcome];
}

final class ReportShareFailure extends ReportDeliveryState {
  const ReportShareFailure({required PdfReport report}) : super(report: report);
  Failure get failure => const ServerFailure(
    message: 'Could not open sharing. Try again, or use Save PDF.',
    code: 'PDF_SHARE_ERROR',
  );
}

/// Local save/share state, separate from ReportBloc's generation operation.
class ReportDeliveryBloc
    extends Bloc<ReportDeliveryEvent, ReportDeliveryState> {
  ReportDeliveryBloc({required ReportDelivery delivery, ReportSharing? sharing})
    : _delivery = delivery,
      _sharing = sharing,
      super(const ReportDeliveryInitial()) {
    on<ReportSaveRequested>(_onSave);
    on<ReportShareRequested>(_onShare);
  }

  final ReportDelivery _delivery;
  final ReportSharing? _sharing;
  bool get supportsSharing => _sharing != null;
  bool get _busy => state is ReportSaving || state is ReportSharingInProgress;

  Future<void> _onSave(
    ReportSaveRequested event,
    Emitter<ReportDeliveryState> emit,
  ) async {
    if (_busy) return;
    emit(ReportSaving(report: event.report));
    try {
      final outcome = await _delivery.save(event.report);
      if (isClosed || emit.isDone) return;
      emit(ReportDelivered(report: event.report, outcome: outcome));
    } on Object catch (_) {
      if (isClosed || emit.isDone) return;
      emit(ReportSaveFailure(report: event.report));
    }
  }

  Future<void> _onShare(
    ReportShareRequested event,
    Emitter<ReportDeliveryState> emit,
  ) async {
    if (_busy) return;
    emit(ReportSharingInProgress(report: event.report));
    try {
      final outcome =
          await _sharing?.share(event.report, origin: event.origin) ??
          ReportShareOutcome.unsupported;
      if (isClosed || emit.isDone) return;
      emit(ReportShareFinished(report: event.report, outcome: outcome));
    } on Object catch (_) {
      if (isClosed || emit.isDone) return;
      emit(ReportShareFailure(report: event.report));
    }
  }
}
