import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/explanations/data/datasources/explanation_remote_data_source.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/ai_explanation_result.dart';
import 'package:numlab_frontend/features/explanations/domain/repositories/explanation_repository.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

/// Implementation of [ExplanationRepository] bridging domain use case and network datasource.
class ExplanationRepositoryImpl implements ExplanationRepository {
  const ExplanationRepositoryImpl({
    required ExplanationRemoteDataSource remoteDataSource,
    SecureStorageService? secureStorageService,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorageService = secureStorageService;

  final ExplanationRemoteDataSource _remoteDataSource;
  final SecureStorageService? _secureStorageService;

  @override
  Future<Either<Failure, AiExplanationResult>> explain({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  }) async {
    try {
      final token = await _secureStorageService?.getAccessToken();

      // Convert solver result to JSON payload matching backend expectations
      final solverModel = SolverResultModel.fromEntity(solverResult);
      final rawSolverMap = solverModel.toJson();

      // Ensure required status field is populated for backend Joi validation
      final effectiveStatus =
          solverResult.status ??
          (solverResult.isConverged ? 'converged' : 'completed');
      rawSolverMap['status'] = effectiveStatus;

      // Construct request body envelope
      final payload = <String, dynamic>{
        'solverResult': rawSolverMap,
        if (focus != null && focus.isNotEmpty) 'focus': focus,
        'includeGraphSummary': ?includeGraphSummary,
      };

      final result = await _remoteDataSource.explain(
        payload: payload,
        accessToken: token,
      );

      return Right(result.toEntity());
    } on Exception catch (e, stackTrace) {
      return Left(mapExceptionToFailure(e, stackTrace));
    }
  }
}
