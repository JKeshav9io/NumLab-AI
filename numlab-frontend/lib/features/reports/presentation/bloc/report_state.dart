import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';

sealed class ReportState extends Equatable {
  const ReportState();

  // Keep identifiers, PDF bytes, filenames, and error content out of logs.
  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [];
}

final class ReportInitial extends ReportState {
  const ReportInitial();
}

final class ReportLoading extends ReportState {
  const ReportLoading({required this.runId});

  final String runId;

  @override
  List<Object?> get props => [runId];
}

final class ReportSuccess extends ReportState {
  const ReportSuccess({required this.runId, required this.report});

  final String runId;

  /// Original immutable domain result; no extra PDF byte copy or fallback name.
  final PdfReport report;

  @override
  List<Object?> get props => [runId, report];
}

final class ReportFailure extends ReportState {
  const ReportFailure({required this.runId, required this.failure});

  final String runId;
  final Failure failure;

  String get message => failure.message;

  @override
  List<Object?> get props => [runId, failure];
}
