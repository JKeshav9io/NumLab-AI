import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/solvers/data/datasources/solver_remote_data_source.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

class FakeDio extends Fake implements Dio {
  Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  })?
  onPost;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onPost!(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return res as Response<T>;
  }
}

void main() {
  late FakeDio fakeDio;
  late SolverRemoteDataSourceImpl dataSource;

  setUp(() {
    fakeDio = FakeDio();
    dataSource = SolverRemoteDataSourceImpl(dio: fakeDio);
  });

  group('SolverRemoteDataSourceImpl', () {
    test(
      'executes Root-Finding solver (Bisection) using configured endpoint',
      () async {
        final config = SolverMethodRegistry.bisection;
        final payload = {
          'equation': 'x^3 - x - 2',
          'lowerBound': 1.0,
          'upperBound': 2.0,
          'tolerance': 0.0001,
          'maxIterations': 100,
        };

        var calledPath = '';
        Object? calledData;

        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              calledPath = path;
              calledData = data;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'method': 'Bisection Method',
                    'status': 'converged',
                    'input': payload,
                    'iterations': <dynamic>[],
                    'finalAnswer': {
                      'root': 1.5214,
                      'converged': true,
                    },
                  },
                },
              );
            };

        final result = await dataSource.solve(
          config: config,
          payload: payload,
        );

        expect(calledPath, '/solve/root/bisection');
        expect(calledData, equals(payload));
        expect(result.method, 'Bisection Method');
        expect(result.root, 1.5214);
        expect(result.isConverged, isTrue);
      },
    );

    test(
      'executes Linear Systems solver (Jacobi) with matrix payload',
      () async {
        final config = SolverMethodRegistry.jacobi;
        final payload = {
          'matrix': [
            [4.0, 1.0],
            [1.0, 3.0],
          ],
          'constants': [1.0, 2.0],
        };

        var calledPath = '';

        fakeDio.onPost =
            (
              path, {
              data,
              options,
              cancelToken,
              onReceiveProgress,
              onSendProgress,
              queryParameters,
            }) async {
              calledPath = path;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'method': 'Jacobi Method',
                    'status': 'converged',
                    'finalAnswer': {
                      'solution': [0.0909, 0.6364],
                      'converged': true,
                    },
                  },
                },
              );
            };

        final result = await dataSource.solve(
          config: config,
          payload: payload,
        );

        expect(calledPath, '/solve/linear/jacobi');
        expect(result.solutionVector, [0.0909, 0.6364]);
      },
    );

    test('executes Interpolation solver (Lagrange)', () async {
      final config = SolverMethodRegistry.lagrangeInterpolation;
      final payload = {
        'points': [
          {'x': 1.0, 'y': 2.0},
          {'x': 2.0, 'y': 3.0},
        ],
        'targetX': 1.5,
      };

      var calledPath = '';

      fakeDio.onPost =
          (
            path, {
            data,
            options,
            cancelToken,
            onReceiveProgress,
            onSendProgress,
            queryParameters,
          }) async {
            calledPath = path;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'method': 'Lagrange Interpolation',
                  'finalAnswer': {
                    'targetX': 1.5,
                    'predictedY': 2.5,
                  },
                },
              },
            );
          };

      final result = await dataSource.solve(
        config: config,
        payload: payload,
      );

      expect(calledPath, '/solve/interpolation/lagrange');
      expect(result.method, 'Lagrange Interpolation');
      expect(result.finalAnswer['predictedY'], 2.5);
    });

    test('executes Numerical Integration solver (Simpson 1/3)', () async {
      final config = SolverMethodRegistry.simpson13;
      final payload = {
        'equation': 'x^2',
        'lowerBound': 0.0,
        'upperBound': 1.0,
        'subintervals': 4,
      };

      var calledPath = '';

      fakeDio.onPost =
          (
            path, {
            data,
            options,
            cancelToken,
            onReceiveProgress,
            onSendProgress,
            queryParameters,
          }) async {
            calledPath = path;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'method': "Simpson's 1/3 Rule",
                  'finalAnswer': {
                    'value': 0.3333,
                  },
                },
              },
            );
          };

      final result = await dataSource.solve(
        config: config,
        payload: payload,
      );

      expect(calledPath, '/solve/integration/simpson-13');
      expect(result.finalAnswer['value'], 0.3333);
    });

    test('authenticated request sends Authorization Bearer header', () async {
      final config = SolverMethodRegistry.bisection;
      Options? calledOptions;

      fakeDio.onPost =
          (
            path, {
            data,
            options,
            cancelToken,
            onReceiveProgress,
            onSendProgress,
            queryParameters,
          }) async {
            calledOptions = options;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {'method': 'Bisection Method'},
              },
            );
          };

      await dataSource.solve(
        config: config,
        payload: const {'equation': 'x^2'},
        accessToken: 'valid-jwt-token',
      );

      expect(
        calledOptions?.headers?[ApiConstants.authHeader],
        'Bearer valid-jwt-token',
      );
    });

    test('anonymous request omits Authorization header', () async {
      final config = SolverMethodRegistry.bisection;
      Options? calledOptions;

      fakeDio.onPost =
          (
            path, {
            data,
            options,
            cancelToken,
            onReceiveProgress,
            onSendProgress,
            queryParameters,
          }) async {
            calledOptions = options;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: {
                'success': true,
                'data': {'method': 'Bisection Method'},
              },
            );
          };

      await dataSource.solve(
        config: config,
        payload: const {'equation': 'x^2'},
      );

      expect(calledOptions, isNull);
    });

    test('throws FormatException when response body is null', () async {
      fakeDio.onPost =
          (
            path, {
            data,
            options,
            cancelToken,
            onReceiveProgress,
            onSendProgress,
            queryParameters,
          }) async {
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
            );
          };

      expect(
        () => dataSource.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('propagates DioException when network request fails', () async {
      fakeDio.onPost =
          (
            path, {
            data,
            options,
            cancelToken,
            onReceiveProgress,
            onSendProgress,
            queryParameters,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: path),
              type: DioExceptionType.connectionTimeout,
            );
          };

      expect(
        () => dataSource.solve(
          config: SolverMethodRegistry.bisection,
          payload: const {},
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
