import 'package:equatable/equatable.dart';

/// Events for requesting reports; file actions belong to later phases.
sealed class ReportEvent extends Equatable {
  const ReportEvent();

  // Do not expose private run identifiers through debug stringification.
  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [];
}

final class ReportRequested extends ReportEvent {
  const ReportRequested({required this.runId});

  /// Persisted solver-run UUID owned by the authenticated user.
  final String runId;

  @override
  List<Object?> get props => [runId];
}
