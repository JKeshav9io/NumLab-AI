import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';

/// Contract for remote numerical solver network communication.
// ignore: one_member_abstracts
abstract interface class SolverRemoteDataSource {
  /// Posts [payload] to the backend endpoint specified by [SolverMethodConfig.endpoint].
  ///
  /// Passes [accessToken] in the Authorization header if provided.
  Future<SolverResultModel> solve({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  });
}

/// Implementation of [SolverRemoteDataSource] using [Dio].
class SolverRemoteDataSourceImpl implements SolverRemoteDataSource {
  const SolverRemoteDataSourceImpl({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  Options? _buildOptions(String? accessToken) {
    if (accessToken != null && accessToken.isNotEmpty) {
      return Options(
        headers: <String, dynamic>{
          ApiConstants.authHeader: '${ApiConstants.bearerPrefix}$accessToken',
        },
      );
    }
    return null;
  }

  @override
  Future<SolverResultModel> solve({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      config.endpoint,
      data: payload,
      options: _buildOptions(accessToken),
    );

    final body = response.data;
    if (body == null) {
      throw const FormatException(
        'Malformed or empty solver response envelope',
      );
    }

    return SolverResultModel.fromJson(body);
  }
}
