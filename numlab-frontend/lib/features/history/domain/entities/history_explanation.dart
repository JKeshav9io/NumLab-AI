import 'package:equatable/equatable.dart';

/// Domain entity representing an attached AI explanation for a solver run.
class HistoryExplanation extends Equatable {
  const HistoryExplanation({
    required this.id,
    required this.responseText,
    required this.createdAt,
    this.solverRunId,
    this.userId,
    this.focusMode = 'steps',
    this.promptHash,
    this.expiresAt,
  });

  /// Unique explanation identifier.
  final String id;

  /// Associated solver run UUID, if linked.
  final String? solverRunId;

  /// Author user UUID, if authenticated.
  final String? userId;

  /// Pedagogical focus mode (e.g., 'summary', 'steps', 'warnings', 'lab-report').
  final String focusMode;

  /// Cache/deduplication prompt hash.
  final String? promptHash;

  /// Formatted explanation markdown text.
  final String responseText;

  /// Timestamp when cache expires, if transient.
  final DateTime? expiresAt;

  /// Generation timestamp.
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    solverRunId,
    userId,
    focusMode,
    promptHash,
    responseText,
    expiresAt,
    createdAt,
  ];
}
