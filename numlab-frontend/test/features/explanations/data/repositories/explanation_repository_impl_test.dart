import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/explanations/data/datasources/explanation_remote_data_source.dart';
import 'package:numlab_frontend/features/explanations/data/models/ai_explanation_result_model.dart';
import 'package:numlab_frontend/features/explanations/data/repositories/explanation_repository_impl.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/ai_explanation_result.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

class MockExplanationRemoteDataSource extends Fake
    implements ExplanationRemoteDataSource {
  Future<AiExplanationResultModel> Function({
    required Map<String, dynamic> payload,
    String? accessToken,
  })?
  onExplain;

  @override
  Future<AiExplanationResultModel> explain({
    required Map<String, dynamic> payload,
    String? accessToken,
  }) {
    return onExplain!(
      payload: payload,
      accessToken: accessToken,
    );
  }
}

class MockSecureStorageService extends Fake implements SecureStorageService {
  String? mockAccessToken;

  @override
  Future<String?> getAccessToken() async => mockAccessToken;
}

void main() {
  late MockExplanationRemoteDataSource mockDataSource;
  late MockSecureStorageService mockSecureStorage;
  late ExplanationRepositoryImpl repository;

  const testSolverResult = SolverResult(
    method: 'Bisection Method',
    status: 'converged',
    input: {'equation': 'x^2 - 4'},
    finalAnswer: {'root': 2.0, 'converged': true},
  );

  const testModel = AiExplanationResultModel(
    explanation: 'Detailed explanation text from server.',
    model: 'gpt-4o-mini',
    method: 'Bisection Method',
    status: 'converged',
  );

  setUp(() {
    mockDataSource = MockExplanationRemoteDataSource();
    mockSecureStorage = MockSecureStorageService();
    repository = ExplanationRepositoryImpl(
      remoteDataSource: mockDataSource,
      secureStorageService: mockSecureStorage,
    );
  });

  group('ExplanationRepositoryImpl', () {
    test('preserves quota cooldown from the actual backend envelope', () async {
      mockDataSource.onExplain = ({required payload, accessToken}) async {
        final options = RequestOptions(path: '/explain');
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 429,
            data: {
              'error': {
                'code': 'RATE_LIMIT_EXCEEDED',
                'message': 'Uncached AI explanation quota exceeded.',
                'details': {'retryAfterSeconds': 900},
              },
            },
          ),
        );
      };
      final result = await repository.explain(solverResult: testSolverResult);
      result.fold((failure) {
        expect(failure, isA<RateLimitFailure>());
        expect((failure as RateLimitFailure).retryAfterSeconds, 900);
        expect(failure.message, 'Uncached AI explanation quota exceeded.');
      }, (_) => fail('Expected rate limit'));
    });
    test(
      'returns Right(AiExplanationResult) and forwards payload and token',
      () async {
        mockSecureStorage.mockAccessToken = 'mock-jwt-token';
        Map<String, dynamic>? capturedPayload;
        String? capturedToken;

        mockDataSource.onExplain =
            ({
              required payload,
              accessToken,
            }) async {
              capturedPayload = payload;
              capturedToken = accessToken;
              return testModel;
            };

        final result = await repository.explain(
          solverResult: testSolverResult,
          focus: 'steps',
          includeGraphSummary: true,
        );

        expect(capturedToken, 'mock-jwt-token');
        expect(capturedPayload != null, isTrue);
        expect(capturedPayload!['focus'], 'steps');
        expect(capturedPayload!['includeGraphSummary'], isTrue);

        final solverMap =
            capturedPayload!['solverResult'] as Map<String, dynamic>;
        expect(solverMap['method'], 'Bisection Method');
        expect(solverMap['status'], 'converged');

        expect(
          result,
          Right<Failure, AiExplanationResult>(testModel.toEntity()),
        );
      },
    );

    test(
      'populates fallback status when solverResult status is null',
      () async {
        const nullStatusResult = SolverResult(
          method: 'Trapezoidal Rule',
          finalAnswer: {'integral': 4.5, 'converged': true},
        );

        Map<String, dynamic>? capturedPayload;
        mockDataSource.onExplain =
            ({
              required payload,
              accessToken,
            }) async {
              capturedPayload = payload;
              return testModel;
            };

        final result = await repository.explain(
          solverResult: nullStatusResult,
        );

        expect(result.isRight(), isTrue);
        final solverMap =
            capturedPayload!['solverResult'] as Map<String, dynamic>;
        expect(solverMap['status'], 'converged');
      },
    );

    test('maps DioException badResponse 429 to RateLimitFailure', () async {
      mockDataSource.onExplain =
          ({
            required payload,
            accessToken,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/explain'),
              response: Response(
                requestOptions: RequestOptions(path: '/explain'),
                statusCode: 429,
                data: {
                  'error': {
                    'code': 'RATE_LIMIT_EXCEEDED',
                    'message': 'Rate limit exceeded for AI explanations.',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            );
          };

      final result = await repository.explain(
        solverResult: testSolverResult,
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<RateLimitFailure>());
        expect(failure.message, contains('Rate limit exceeded'));
      }, (_) => fail('Expected Left(RateLimitFailure)'));
    });

    test('maps DioException connectionTimeout to NetworkFailure', () async {
      mockDataSource.onExplain =
          ({
            required payload,
            accessToken,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/explain'),
              type: DioExceptionType.connectionTimeout,
            );
          };

      final result = await repository.explain(
        solverResult: testSolverResult,
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<NetworkFailure>());
      }, (_) => fail('Expected Left(NetworkFailure)'));
    });

    test('maps unexpected Exception to ServerFailure', () async {
      mockDataSource.onExplain =
          ({
            required payload,
            accessToken,
          }) async {
            throw const FormatException('Corrupt server response');
          };

      final result = await repository.explain(
        solverResult: testSolverResult,
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.message, contains('Corrupt server response'));
      }, (_) => fail('Expected Left(ServerFailure)'));
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
    ]) {
      test('distinguishes $type and allows a later manual request', () async {
        var calls = 0;
        mockDataSource.onExplain = ({required payload, accessToken}) async {
          calls++;
          if (calls == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/explain'),
              type: type,
            );
          }
          return testModel;
        };

        final result = await repository.explain(solverResult: testSolverResult);
        result.fold((failure) {
          expect(failure, isA<NetworkFailure>());
          if (type == DioExceptionType.connectionError) {
            expect(failure.code, 'NETWORK_ERROR');
            expect(failure.message, contains('check your connection'));
          } else {
            expect(failure.code, 'REQUEST_TIMEOUT');
            if (type == DioExceptionType.connectionTimeout) {
              expect(
                failure.message,
                'Unable to connect to NumLab server: the connection timed out. Please try again.',
              );
            } else {
              expect(
                failure.message,
                'The request timed out. Please try again.',
              );
            }
          }
        }, (_) => fail('Expected a network failure'));
        expect(calls, 1);

        final retry = await repository.explain(solverResult: testSolverResult);
        expect(
          retry,
          Right<Failure, AiExplanationResult>(testModel.toEntity()),
        );
        expect(calls, 2);
      });
    }

    test('preserves backend AI service failure code and message', () async {
      mockDataSource.onExplain = ({required payload, accessToken}) async {
        final options = RequestOptions(path: '/explain');
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 502,
            data: {
              'error': {
                'code': 'AI_SERVICE_ERROR',
                'message': 'AI provider request timed out',
              },
            },
          ),
        );
      };
      final result = await repository.explain(solverResult: testSolverResult);
      result.fold((failure) {
        expect(failure, isA<ServerFailure>());
        expect(failure.code, 'AI_SERVICE_ERROR');
        expect(failure.message, 'AI provider request timed out');
        expect((failure as ServerFailure).statusCode, 502);
      }, (_) => fail('Expected server failure'));
    });
  });
}
