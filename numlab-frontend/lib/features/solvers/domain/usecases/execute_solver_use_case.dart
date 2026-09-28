import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_registry.dart';
import 'package:numlab_frontend/features/solvers/domain/repositories/solver_repository.dart';

/// Primary domain use case for orchestrating numerical solver execution.
///
/// Execution pipeline:
/// 1. Resolves the [SolverMethodConfig] from [SolverMethodRegistry] via solver ID or endpoint.
/// 2. Performs client-side field validation and cross-field rule checking.
/// 3. Returns a [ValidationFailure] with granular [FieldError]s if validation fails.
/// 4. Executes the solver via [SolverRepository] and returns `Either<Failure, SolverResult>`.
class ExecuteSolverUseCase {
  const ExecuteSolverUseCase(this._repository);

  final SolverRepository _repository;

  /// Executes the solver specified by [solverId] with the input [payload].
  Future<Either<Failure, SolverResult>> call({
    required String solverId,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    final config = SolverMethodRegistry.getById(solverId);
    if (config == null) {
      return Left(
        ValidationFailure(
          message: 'Unknown solver method: "$solverId"',
          code: 'UNKNOWN_SOLVER_METHOD',
        ),
      );
    }

    return executeWithConfig(
      config: config,
      payload: payload,
      accessToken: accessToken,
    );
  }

  /// Executes the solver directly using a pre-resolved [SolverMethodConfig].
  Future<Either<Failure, SolverResult>> executeWithConfig({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    final validationErrors = config.validate(payload);
    if (validationErrors.isNotEmpty) {
      final fieldErrors = validationErrors.entries
          .map((entry) => FieldError(field: entry.key, message: entry.value))
          .toList(growable: false);

      return Left(
        ValidationFailure(
          message: 'Validation failed for ${config.name}',
          fieldErrors: fieldErrors,
        ),
      );
    }

    return _repository.solve(
      config: config,
      payload: payload,
      accessToken: accessToken,
    );
  }

  /// Alias for [call] supporting named execution syntax.
  Future<Either<Failure, SolverResult>> execute({
    required String solverId,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) => call(
    solverId: solverId,
    payload: payload,
    accessToken: accessToken,
  );
}
