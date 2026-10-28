import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';

/// Data access boundary for reports belonging to an authenticated user's run.
// ignore: one_member_abstracts
abstract interface class ReportRepository {
  Future<Either<Failure, PdfReport>> generateReport(String runId);
}
