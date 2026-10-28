import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/domain/repositories/report_repository.dart';

/// Requests a backend-generated PDF for an owned, persisted solver-run UUID.
class GenerateReportUseCase {
  const GenerateReportUseCase(this._repository);

  final ReportRepository _repository;

  /// Forwards [runId] unchanged and returns the repository result or failure.
  /// Authentication belongs to the data/network layer; UUID validation and
  /// ownership checks remain with the server. No local PDF generation or retry.
  Future<Either<Failure, PdfReport>> call(String runId) {
    return _repository.generateReport(runId);
  }
}
