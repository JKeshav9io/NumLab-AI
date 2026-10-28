import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';

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

/// Local save/share state, separate from ReportBloc's generation operation.
class ReportDeliveryBloc
    extends Bloc<ReportDeliveryEvent, ReportDeliveryState> {
  ReportDeliveryBloc({required ReportDelivery delivery})
    : _delivery = delivery,
      super(const ReportDeliveryInitial()) {
    on<ReportSaveRequested>(_onSave);
  }

  final ReportDelivery _delivery;
  Future<void> _onSave(
    ReportSaveRequested event,
    Emitter<ReportDeliveryState> emit,
  ) async {
    if (state is ReportSaving) return;
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

}
