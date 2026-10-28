import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/explanations/data/models/ai_explanation_result_model.dart';

/// Contract for remote AI explanation network communication.
// ignore: one_member_abstracts
abstract interface class ExplanationRemoteDataSource {
  /// Sends explanation request payload to POST /api/v1/explain.
  Future<AiExplanationResultModel> explain({
    required Map<String, dynamic> payload,
    String? accessToken,
  });
}

/// Implementation of [ExplanationRemoteDataSource] using [Dio].
class ExplanationRemoteDataSourceImpl implements ExplanationRemoteDataSource {
  const ExplanationRemoteDataSourceImpl({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  Options _buildOptions(String? accessToken) {
    return Options(
      receiveTimeout: ApiConstants.explanationReceiveTimeout,
      headers: {
        if (accessToken != null && accessToken.isNotEmpty)
          ApiConstants.authHeader: '${ApiConstants.bearerPrefix}$accessToken',
      },
    );
  }

  @override
  Future<AiExplanationResultModel> explain({
    required Map<String, dynamic> payload,
    String? accessToken,
  }) async {
    // Validate the envelope ourselves so a gateway's HTML/list response becomes
    // a recoverable response failure instead of a Dio generic-cast error.
    final response = await _dio.post<dynamic>(
      ApiConstants.explainPath,
      data: payload,
      options: _buildOptions(accessToken),
    );

    final body = response.data;
    if (body == null) {
      throw const FormatException(
        'Empty or malformed explanation response envelope from server',
      );
    }

    if (body is! Map<String, dynamic>) {
      throw const FormatException('Malformed AI explanation response.');
    }

    final data = body['data'];
    if (body['success'] != true ||
        data is! Map<String, dynamic> ||
        data['explanation'] is! String) {
      throw const FormatException('Malformed AI explanation response.');
    }

    return AiExplanationResultModel.fromJson(body);
  }
}
