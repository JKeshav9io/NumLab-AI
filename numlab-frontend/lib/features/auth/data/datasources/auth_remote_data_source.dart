import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/auth/data/models/auth_response_model.dart';
import 'package:numlab_frontend/features/auth/data/models/token_model.dart';
import 'package:numlab_frontend/features/auth/data/models/user_model.dart';

/// Contract for remote authentication API interactions.
abstract interface class AuthRemoteDataSource {
  /// Registers a new user with email and password.
  Future<AuthResponseModel> register({
    required String email,
    required String password,
  });

  /// Authenticates a user with email and password.
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  /// Rotates the refresh token and returns a new token pair.
  Future<TokenModel> refresh({
    required String refreshToken,
  });

  /// Logs out the single session associated with [refreshToken].
  Future<void> logout({
    required String refreshToken,
  });

  /// Logs out all active sessions for the authenticated user.
  Future<void> logoutAll({
    String? accessToken,
  });

  /// Retrieves the current authenticated user profile.
  Future<UserModel> getCurrentUser({
    String? accessToken,
  });
}

/// Implementation of [AuthRemoteDataSource] powered by [Dio].
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  Options? _authOptions(String? token) {
    if (token != null && token.isNotEmpty) {
      return Options(
        headers: <String, dynamic>{
          ApiConstants.authHeader: '${ApiConstants.bearerPrefix}$token',
        },
      );
    }
    return null;
  }

  @override
  Future<AuthResponseModel> register({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.registerPath,
      data: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );

    final body = response.data;
    if (body == null || body['data'] == null) {
      throw const FormatException('Malformed register response envelope');
    }

    final data = body['data'] as Map<String, dynamic>;
    return AuthResponseModel.fromJson(data);
  }

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.loginPath,
      data: <String, dynamic>{
        'email': email,
        'password': password,
      },
    );

    final body = response.data;
    if (body == null || body['data'] == null) {
      throw const FormatException('Malformed login response envelope');
    }

    final data = body['data'] as Map<String, dynamic>;
    return AuthResponseModel.fromJson(data);
  }

  @override
  Future<TokenModel> refresh({
    required String refreshToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.refreshPath,
      data: <String, dynamic>{
        'refreshToken': refreshToken,
      },
    );

    final body = response.data;
    if (body == null || body['data'] == null) {
      throw const FormatException('Malformed refresh response envelope');
    }

    final data = body['data'] as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    if (tokens == null) {
      throw const FormatException('Missing tokens object in refresh response');
    }

    return TokenModel.fromJson(tokens);
  }

  @override
  Future<void> logout({
    required String refreshToken,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.logoutPath,
      data: <String, dynamic>{
        'refreshToken': refreshToken,
      },
    );
  }

  @override
  Future<void> logoutAll({
    String? accessToken,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      ApiConstants.logoutAllPath,
      options: _authOptions(accessToken),
    );
  }

  @override
  Future<UserModel> getCurrentUser({
    String? accessToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConstants.userMePath,
      options: _authOptions(accessToken),
    );

    final body = response.data;
    if (body == null || body['data'] == null) {
      throw const FormatException('Malformed getCurrentUser response envelope');
    }

    return UserModel.fromResponseData(body['data']);
  }
}
