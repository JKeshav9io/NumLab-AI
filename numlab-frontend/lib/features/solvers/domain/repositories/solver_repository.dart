import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';

/// Contract for executing numerical solvers and returning either a domain [Failure]
/// or the strongly-typed [SolverResultModel].
// ignore: one_member_abstracts
abstract interface class SolverRepository {
  /// Executes the numerical solver described by [config] with the input [payload].
  ///
  /// If [accessToken] is provided or exists in secure storage, it is included
  /// in the request to attribute solver history; otherwise the solver runs
  /// anonymously via the backend's optional authentication pipeline.
  Future<Either<Failure, SolverResultModel>> solve({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  });
}
