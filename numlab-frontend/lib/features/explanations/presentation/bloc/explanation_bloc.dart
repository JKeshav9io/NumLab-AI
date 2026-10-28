import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:numlab_frontend/features/explanations/domain/usecases/explain_use_case.dart';
import 'package:numlab_frontend/features/explanations/presentation/bloc/explanation_event.dart';
import 'package:numlab_frontend/features/explanations/presentation/bloc/explanation_state.dart';

/// Presentation BLoC managing AI pedagogical explanation requests, state transitions,
/// duplicate request prevention, and error handling.
class ExplanationBloc extends Bloc<ExplanationEvent, ExplanationState> {
  ExplanationBloc({
    required ExplainUseCase explainUseCase,
  }) : _explainUseCase = explainUseCase,
       super(const ExplanationInitial()) {
    on<ExplanationRequested>(_onExplanationRequested);
    on<ExplanationPreloaded>(_onExplanationPreloaded);
    on<ExplanationReset>(_onExplanationReset);
    on<ExplanationWaitElapsed>(_onExplanationWaitElapsed);
  }

  final ExplainUseCase _explainUseCase;
  int _requestVersion = 0;
  Timer? _slowRequestTimer;

  Future<void> _onExplanationRequested(
    ExplanationRequested event,
    Emitter<ExplanationState> emit,
  ) async {
    // 1. Prevent duplicate requests while an explanation request is already running
    if (state is ExplanationLoading) {
      return;
    }

    final previousExplanation = state.currentExplanation;
    final requestVersion = ++_requestVersion;

    emit(ExplanationLoading(previousExplanation: previousExplanation));
    _slowRequestTimer?.cancel();
    _slowRequestTimer = Timer(const Duration(seconds: 5), () {
      if (!isClosed) add(ExplanationWaitElapsed(requestVersion));
    });

    final result = await _explainUseCase(
      solverResult: event.solverResult,
      focus: event.focus,
      includeGraphSummary: event.includeGraphSummary,
    );

    // Reset/preload can supersede this request while the use case is awaiting.
    if (isClosed || emit.isDone || requestVersion != _requestVersion) {
      return;
    }
    _slowRequestTimer?.cancel();

    result.fold(
      (failure) => emit(
        ExplanationFailure(
          failure: failure,
          previousExplanation: previousExplanation,
        ),
      ),
      (explanation) => emit(
        ExplanationSuccess(explanation: explanation),
      ),
    );
  }

  void _onExplanationPreloaded(
    ExplanationPreloaded event,
    Emitter<ExplanationState> emit,
  ) {
    _requestVersion++;
    _slowRequestTimer?.cancel();
    emit(ExplanationSuccess(explanation: event.explanation));
  }

  void _onExplanationReset(
    ExplanationReset event,
    Emitter<ExplanationState> emit,
  ) {
    _requestVersion++;
    _slowRequestTimer?.cancel();
    emit(const ExplanationInitial());
  }

  void _onExplanationWaitElapsed(
    ExplanationWaitElapsed event,
    Emitter<ExplanationState> emit,
  ) {
    final currentState = state;
    if (event.requestVersion != _requestVersion ||
        currentState is! ExplanationLoading) {
      return;
    }
    emit(
      ExplanationLoading(
        previousExplanation: currentState.previousExplanation,
        isSlow: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _requestVersion++;
    _slowRequestTimer?.cancel();
    return super.close();
  }
}
