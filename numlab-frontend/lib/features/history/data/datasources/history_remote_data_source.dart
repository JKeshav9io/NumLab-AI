import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/history/data/models/models.dart';

/// Contract for remote history API network communication.
abstract interface class HistoryRemoteDataSource {
  /// Fetches a paginated list of solver runs for the authenticated user.
  Future<PaginatedHistoryModel> getHistory({
    int limit = 20,
    int offset = 0,
  });

  /// Fetches a single solver run by its unique [runId], including attached AI explanations.
  Future<HistoryRunModel> getRunById(String runId);
}

/// Implementation of [HistoryRemoteDataSource] using [Dio].
class HistoryRemoteDataSourceImpl implements HistoryRemoteDataSource {
  const HistoryRemoteDataSourceImpl({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  @override
  Future<PaginatedHistoryModel> getHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.historyPath,
      queryParameters: <String, dynamic>{
        'limit': limit,
        'offset': offset,
      },
    );

    final body = response.data;
    if (body == null) {
      throw const FormatException(
        'Empty history response envelope from server',
      );
    }

    return PaginatedHistoryModel.fromJson(body);
  }

  @override
  Future<HistoryRunModel> getRunById(String runId) async {
    final encodedRunId = Uri.encodeComponent(runId);
    final response = await _dio.get<Map<String, dynamic>>(
      '${ApiConstants.historyPath}/$encodedRunId',
    );

    final body = response.data;
    if (body == null) {
      throw const FormatException(
        'Empty history run detail response envelope from server',
      );
    }

    final payload =
        body.containsKey('data') && body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : (body.containsKey('data') && body['data'] is Map
              ? Map<String, dynamic>.from(body['data'] as Map)
              : body);

    final runMap = payload['run'];
    if (runMap is Map<String, dynamic>) {
      return HistoryRunModel.fromJson(runMap);
    } else if (runMap is Map) {
      return HistoryRunModel.fromJson(Map<String, dynamic>.from(runMap));
    }

    return HistoryRunModel.fromJson(payload);
  }
}
