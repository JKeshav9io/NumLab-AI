import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/features/reports/domain/usecases/generate_report_use_case.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_event.dart';
import 'package:numlab_frontend/features/reports/presentation/bloc/report_state.dart';

/// Action-scoped report requests through the existing domain use case.
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc({required GenerateReportUseCase generateReportUseCase})
    : _generateReportUseCase = generateReportUseCase,
      super(const ReportInitial()) {
    on<ReportRequested>(_onRequested);
  }

  final GenerateReportUseCase _generateReportUseCase;
  int _requestVersion = 0;

  Future<void> _onRequested(
    ReportRequested event,
    Emitter<ReportState> emit,
  ) async {
    final current = state;
    if (current is ReportLoading && current.runId == event.runId) return;

    // A different run replaces the visible request. Its predecessor can finish
    // at the transport layer, but cannot publish success or failure here.
    final version = ++_requestVersion;
    emit(ReportLoading(runId: event.runId));
    final result = await _generateReportUseCase(event.runId);

    if (isClosed || emit.isDone || version != _requestVersion) return;

    result.fold(
      (failure) => emit(ReportFailure(runId: event.runId, failure: failure)),
      (report) => emit(ReportSuccess(runId: event.runId, report: report)),
    );
  }

  @override
  Future<void> close() {
    _requestVersion++;
    return super.close();
  }
}
