import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/reports/data/datasources/report_remote_data_source.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  const ReportRepositoryImpl({required ReportRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final ReportRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, PdfReport>> generateReport(String runId) async {
    try {
      final result = await _remoteDataSource.generateReport(runId);
      return Right(result.toEntity());
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }
}
