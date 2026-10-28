import 'package:equatable/equatable.dart';

/// Domain entity representing the result of an AI explanation request.
class AiExplanationResult extends Equatable {
  const AiExplanationResult({
    required this.explanation,
    this.focus = 'steps',
    this.model = '',
    bool? cached,
    this.method,
    this.status,
    this.totalTokens,
    this.requestId,
    this.timestamp,
  }) : cacheStatus = cached;

  /// Markdown explanation text produced by the AI tutor.
  final String explanation;

  /// Pedagogical focus mode (e.g. 'steps', 'summary', 'warnings', 'lab-report').
  final String focus;

  /// Underlying model name (e.g. 'gpt-4o-mini', 'cached').
  final String model;

  /// Explicit cache evidence, or null when the source did not supply it.
  final bool? cacheStatus;

  /// Whether the response was fulfilled from backend cache.
  bool get cached => cacheStatus ?? false;

  /// The numerical method that was explained.
  final String? method;

  /// Convergence status of the solver execution.
  final String? status;

  /// Total tokens used for generation.
  final int? totalTokens;

  /// Correlation ID from response metadata.
  final String? requestId;

  /// Timestamp from response metadata.
  final String? timestamp;

  @override
  List<Object?> get props => [
    explanation,
    focus,
    model,
    cacheStatus,
    method,
    status,
    totalTokens,
    requestId,
    timestamp,
  ];
}
