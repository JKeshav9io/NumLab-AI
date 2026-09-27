import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/solvers/data/datasources/solver_remote_data_source.dart';
import 'package:numlab_frontend/features/solvers/data/models/solver_result_model.dart';
import 'package:numlab_frontend/features/solvers/data/repositories/solver_repository_impl.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

class MockSolverRemoteDataSource extends Fake
    implements SolverRemoteDataSource {
  Future<SolverResultModel> Function({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  })?
  onSolve;

  @override
  Future<SolverResultModel> solve({
    required SolverMethodConfig config,
    required Map<String, dynamic> payload,
    String? accessToken,
  }) {
    return onSolve!(
      config: config,
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
  late MockSolverRemoteDataSource mockRemoteDataSource;
  late MockSecureStorageService mockSecureStorage;
  late SolverRepositoryImpl repository;

  const sampleResult = SolverResultModel(
    method: 'Bisection Method',
    status: 'converged',
    input: {'equation': 'x^2 - 4'},
    finalAnswer: {'root': 2.0, 'converged': true},
  );

  setUp(() {
    mockRemoteDataSource = MockSolverRemoteDataSource();
    mockSecureStorage = MockSecureStorageService();
    repository = SolverRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      secureStorageService: mockSecureStorage,
    );
  });

  group('SolverRepositoryImpl — Success and Token Handling', () {
    test('returns Right(SolverResultModel) on successful solve', () async {
      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return sampleResult;
          };

      final result = await repository.solve(
        config: SolverMethodRegistry.bisection,
        payload: const {'equation': 'x^2 - 4'},
      );

      expect(result, const Right<Failure, SolverResultModel>(sampleResult));
    });

    test('uses explicitly passed accessToken when provided', () async {
      String? passedToken;
      mockSecureStorage.mockAccessToken = 'storage-token';

      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            passedToken = accessToken;
            return sampleResult;
          };

      await repository.solve(
        config: SolverMethodRegistry.bisection,
        payload: const {'equation': 'x^2 - 4'},
        accessToken: 'explicit-token',
      );

      expect(passedToken, 'explicit-token');
    });

    test(
      'falls back to SecureStorageService when accessToken is omitted',
      () async {
        String? passedToken;
        mockSecureStorage.mockAccessToken = 'jwt-from-storage';

        mockRemoteDataSource.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              passedToken = accessToken;
              return sampleResult;
            };

        await repository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {'equation': 'x^2 - 4'},
        );

        expect(passedToken, 'jwt-from-storage');
      },
    );

    test('executes anonymously when no token in secure storage', () async {
      String? passedToken;
      mockSecureStorage.mockAccessToken = null;

      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            passedToken = accessToken;
            return sampleResult;
          };

      await repository.solve(
        config: SolverMethodRegistry.bisection,
        payload: const {'equation': 'x^2 - 4'},
      );

      expect(passedToken, isNull);
    });

    test('supports different solver categories seamlessly', () async {
      // 1. Linear Algebra (Jacobi)
      const jacobiResult = SolverResultModel(
        method: 'Jacobi Method',
        status: 'converged',
        finalAnswer: {
          'solution': [1.0, 2.0],
          'converged': true,
        },
      );

      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return jacobiResult;
          };

      final linearOutcome = await repository.solve(
        config: SolverMethodRegistry.jacobi,
        payload: const {
          'matrix': [
            [2.0, 1.0],
            [1.0, 2.0],
          ],
          'constants': [3.0, 3.0],
        },
      );

      expect(linearOutcome, isA<Right<Failure, SolverResultModel>>());
      expect(
        linearOutcome.getOrElse((_) => sampleResult).method,
        'Jacobi Method',
      );

      // 2. Interpolation (Lagrange)
      const lagrangeResult = SolverResultModel(
        method: 'Lagrange Interpolation',
        finalAnswer: {'predictedY': 4.5},
      );

      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            return lagrangeResult;
          };

      final interpOutcome = await repository.solve(
        config: SolverMethodRegistry.lagrangeInterpolation,
        payload: const {
          'points': [
            {'x': 1, 'y': 2},
            {'x': 2, 'y': 4},
          ],
          'targetX': 2.25,
        },
      );

      expect(interpOutcome, isA<Right<Failure, SolverResultModel>>());
      expect(
        interpOutcome.getOrElse((_) => sampleResult).method,
        'Lagrange Interpolation',
      );
    });
  });

  group('SolverRepositoryImpl — Failure Mapping', () {
    test(
      'maps 400 Joi validation error to ValidationFailure with fields',
      () async {
        mockRemoteDataSource.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              throw DioException(
                requestOptions: RequestOptions(path: '/solve/root/bisection'),
                response: Response(
                  requestOptions: RequestOptions(path: '/solve/root/bisection'),
                  statusCode: 400,
                  data: {
                    'success': false,
                    'error': {
                      'code': 'VALIDATION_ERROR',
                      'message': 'Validation failed',
                      'details': {
                        'fields': [
                          {
                            'field': 'lowerBound',
                            'message':
                                'lowerBound must be less than upperBound',
                          },
                        ],
                      },
                    },
                  },
                ),
                type: DioExceptionType.badResponse,
              );
            };

        final result = await repository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {'lowerBound': 2.0, 'upperBound': 1.0},
        );

        expect(result, isA<Left<Failure, SolverResultModel>>());
        result.fold(
          (failure) {
            expect(failure, isA<ValidationFailure>());
            final valFailure = failure as ValidationFailure;
            expect(valFailure.code, 'VALIDATION_ERROR');
            expect(valFailure.fieldErrors.length, 1);
            expect(valFailure.fieldErrors[0].field, 'lowerBound');
            expect(
              valFailure.fieldErrors[0].message,
              'lowerBound must be less than upperBound',
            );
          },
          (_) => fail('Should have returned Left'),
        );
      },
    );

    test('maps 429 rate limit exceeded to RateLimitFailure', () async {
      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/solve/root/bisection'),
              response: Response(
                requestOptions: RequestOptions(path: '/solve/root/bisection'),
                statusCode: 429,
                data: {
                  'success': false,
                  'error': {
                    'code': 'RATE_LIMIT_EXCEEDED',
                    'message': 'Too many requests, please try again later.',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            );
          };

      final result = await repository.solve(
        config: SolverMethodRegistry.bisection,
        payload: const {},
      );

      expect(result, isA<Left<Failure, SolverResultModel>>());
      result.fold(
        (failure) {
          expect(failure, isA<RateLimitFailure>());
          expect(failure.code, 'RATE_LIMIT_EXCEEDED');
          expect(
            failure.message,
            'Too many requests, please try again later.',
          );
        },
        (_) => fail('Should have returned Left'),
      );
    });

    test('maps connection timeout to NetworkFailure', () async {
      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/solve/root/bisection'),
              type: DioExceptionType.connectionTimeout,
            );
          };

      final result = await repository.solve(
        config: SolverMethodRegistry.bisection,
        payload: const {},
      );

      expect(result, isA<Left<Failure, SolverResultModel>>());
      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
        },
        (_) => fail('Should have returned Left'),
      );
    });

    test('maps 500 internal server error to ServerFailure', () async {
      mockRemoteDataSource.onSolve =
          ({
            required config,
            required payload,
            accessToken,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: '/solve/root/bisection'),
              response: Response(
                requestOptions: RequestOptions(path: '/solve/root/bisection'),
                statusCode: 500,
                data: {
                  'success': false,
                  'error': {
                    'code': 'INTERNAL_ERROR',
                    'message': 'An unexpected error occurred',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            );
          };

      final result = await repository.solve(
        config: SolverMethodRegistry.bisection,
        payload: const {},
      );

      expect(result, isA<Left<Failure, SolverResultModel>>());
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          final serverFailure = failure as ServerFailure;
          expect(serverFailure.statusCode, 500);
          expect(serverFailure.code, 'INTERNAL_ERROR');
        },
        (_) => fail('Should have returned Left'),
      );
    });

    test(
      'maps unexpected FormatException to ServerFailure without crashing',
      () async {
        mockRemoteDataSource.onSolve =
            ({
              required config,
              required payload,
              accessToken,
            }) async {
              throw const FormatException('Corrupted response payload');
            };

        final result = await repository.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {},
        );

        expect(result, isA<Left<Failure, SolverResultModel>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('Corrupted response payload'));
          },
          (_) => fail('Should have returned Left'),
        );
      },
    );
  });
}
