import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/history/data/datasources/history_remote_data_source.dart';

class FakeDio extends Fake implements Dio {
  Future<Response<dynamic>> Function(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  })?
  onGet;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final res = await onGet!(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return res as Response<T>;
  }
}

void main() {
  late FakeDio fakeDio;
  late HistoryRemoteDataSourceImpl dataSource;

  setUp(() {
    fakeDio = FakeDio();
    dataSource = HistoryRemoteDataSourceImpl(dio: fakeDio);
  });

  group('HistoryRemoteDataSource - getHistory', () {
    final listResponseData = <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'runs': <dynamic>[
          <String, dynamic>{
            'id': 'run-1',
            'method': 'root/bisection',
            'createdAt': '2026-09-30T10:00:00.000Z',
            'outputPayload': <String, dynamic>{'status': 'converged'},
          },
        ],
        'pagination': <String, dynamic>{
          'total': 1,
          'limit': 20,
          'offset': 0,
          'hasMore': false,
        },
      },
    };

    test(
      'calls GET on ApiConstants.historyPath with default parameters',
      () async {
        String? recordedPath;
        Map<String, dynamic>? recordedQueryParams;

        fakeDio.onGet =
            (
              path, {
              data,
              queryParameters,
              options,
              cancelToken,
              onReceiveProgress,
            }) async {
              recordedPath = path;
              recordedQueryParams = queryParameters;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                data: listResponseData,
                statusCode: 200,
              );
            };

        final result = await dataSource.getHistory();

        expect(recordedPath, ApiConstants.historyPath);
        expect(recordedQueryParams, <String, dynamic>{
          'limit': 20,
          'offset': 0,
        });
        expect(result.runs.length, 1);
        expect(result.runs.first.id, 'run-1');
        expect(result.pagination.total, 1);
      },
    );

    test('transmits custom limit and offset query parameters', () async {
      Map<String, dynamic>? recordedQueryParams;

      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            recordedQueryParams = queryParameters;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              data: listResponseData,
              statusCode: 200,
            );
          };

      await dataSource.getHistory(limit: 50, offset: 100);

      expect(recordedQueryParams, <String, dynamic>{
        'limit': 50,
        'offset': 100,
      });
    });

    test('throws FormatException when response body is null', () async {
      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
            );
          };

      expect(
        () => dataSource.getHistory(),
        throwsA(isA<FormatException>()),
      );
    });

    test('propagates DioException on 401 Unauthorized', () async {
      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: path),
              response: Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 401,
                data: <String, dynamic>{
                  'success': false,
                  'error': <String, dynamic>{
                    'code': 'UNAUTHORIZED',
                    'message': 'Token missing or invalid',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            );
          };

      expect(
        () => dataSource.getHistory(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('HistoryRemoteDataSource - getRunById', () {
    final detailResponseData = <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'run': <String, dynamic>{
          'id': 'run-detail-123',
          'userId': 'user-1',
          'method': 'ode/rk4',
          'createdAt': '2026-09-30T12:00:00.000Z',
          'inputPayload': <String, dynamic>{'h': 0.1},
          'outputPayload': <String, dynamic>{'status': 'converged'},
          'aiExplanations': <dynamic>[
            <String, dynamic>{
              'id': 'ai-1',
              'responseText': 'RK4 steps',
              'createdAt': '2026-09-30T12:01:00.000Z',
            },
          ],
        },
      },
    };

    test('calls GET on history detail route with URI-encoded runId', () async {
      String? recordedPath;

      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            recordedPath = path;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              data: detailResponseData,
              statusCode: 200,
            );
          };

      final result = await dataSource.getRunById('run-detail-123');

      expect(recordedPath, '${ApiConstants.historyPath}/run-detail-123');
      expect(result.id, 'run-detail-123');
      expect(result.method, 'ode/rk4');
      expect(result.aiExplanations.length, 1);
      expect(result.aiExplanations.first.id, 'ai-1');
    });

    test('parses response when run is at root or directly returned', () async {
      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              data: <String, dynamic>{
                'run': <String, dynamic>{
                  'id': 'run-direct',
                  'method': 'root/newton',
                  'createdAt': '2026-09-30T12:00:00.000Z',
                },
              },
              statusCode: 200,
            );
          };

      final result = await dataSource.getRunById('run-direct');
      expect(result.id, 'run-direct');
      expect(result.method, 'root/newton');
    });

    test('throws FormatException when detail body is null', () async {
      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
            );
          };

      expect(
        () => dataSource.getRunById('run-null'),
        throwsA(isA<FormatException>()),
      );
    });

    test('propagates DioException on 404 Not Found', () async {
      fakeDio.onGet =
          (
            path, {
            data,
            queryParameters,
            options,
            cancelToken,
            onReceiveProgress,
          }) async {
            throw DioException(
              requestOptions: RequestOptions(path: path),
              response: Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 404,
                data: <String, dynamic>{
                  'success': false,
                  'error': <String, dynamic>{
                    'code': 'NOT_FOUND',
                    'message': 'Solver run not found',
                  },
                },
              ),
              type: DioExceptionType.badResponse,
            );
          };

      expect(
        () => dataSource.getRunById('missing-run'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });
}
