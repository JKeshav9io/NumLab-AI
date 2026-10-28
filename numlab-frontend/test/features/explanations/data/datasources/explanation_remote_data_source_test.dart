import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/explanations/data/datasources/explanation_remote_data_source.dart';

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
  late ExplanationRemoteDataSourceImpl dataSource;

  final samplePayload = <String, dynamic>{
    'solverResult': <String, dynamic>{
      'method': 'Bisection Method',
      'status': 'converged',
      'finalAnswer': <String, dynamic>{'root': 2.0},
    },
    'focus': 'steps',
  };

  final sampleResponse = <String, dynamic>{
    'success': true,
    'data': <String, dynamic>{
      'explanation': 'The algorithm found the root at 2.0.',
      'focus': 'steps',
      'model': 'gpt-4o-mini',
      'cached': false,
      'source': <String, dynamic>{
        'method': 'Bisection Method',
        'status': 'converged',
      },
    },
    'meta': <String, dynamic>{
      'requestId': 'req-987',
      'timestamp': '2026-10-15T22:10:00.000Z',
    },
  };

  setUp(() {
    fakeDio = FakeDio();
    dataSource = ExplanationRemoteDataSourceImpl(dio: fakeDio);
  });

  group('ExplanationRemoteDataSourceImpl', () {
    for (final body in <Map<String, dynamic>>[
      {},
      {
        'success': false,
        'error': {'message': 'private response'},
      },
      {'success': true},
      {'success': true, 'data': null},
      {'success': true, 'data': <Object?>[]},
      {
        'success': true,
        'data': {'explanation': 42},
      },
      {
        'success': true,
        'data': {'explanation': <String, dynamic>{}},
      },
    ]) {
      test(
        'rejects malformed HTTP-200 envelope without exposing content: $body',
        () async {
          fakeDio.onPost =
              (
                path, {
                data,
                options,
                cancelToken,
                onReceiveProgress,
                onSendProgress,
                queryParameters,
              }) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: body,
              );
          await expectLater(
            dataSource.explain(payload: samplePayload),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'safe message',
                'Malformed AI explanation response.',
              ),
            ),
          );
        },
      );
    }

    test(
      'sends POST request to ApiConstants.explainPath with payload and returns parsed model',
      () async {
        String? capturedPath;
        dynamic capturedData;
        Options? capturedOptions;

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
              capturedPath = path;
              capturedData = data;
              capturedOptions = options;
              return Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: path),
                statusCode: 200,
                data: sampleResponse,
              );
            };

        final result = await dataSource.explain(
          payload: samplePayload,
          accessToken: 'test-jwt',
        );

        expect(capturedPath, ApiConstants.explainPath);
        expect(capturedData, samplePayload);
        expect(capturedOptions?.receiveTimeout, const Duration(seconds: 60));
        expect(
          capturedOptions?.headers?[ApiConstants.authHeader],
          'Bearer test-jwt',
        );
        expect(result.explanation, 'The algorithm found the root at 2.0.');
        expect(result.focus, 'steps');
        expect(result.model, 'gpt-4o-mini');
        expect(result.cached, isFalse);
      },
    );

    test('omits Authorization header when accessToken is null', () async {
      Options? capturedOptions;

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
            capturedOptions = options;
            return Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: path),
              statusCode: 200,
              data: sampleResponse,
            );
          };

      await dataSource.explain(payload: samplePayload);

      expect(
        capturedOptions?.headers,
        isNot(contains(ApiConstants.authHeader)),
      );
      expect(capturedOptions?.receiveTimeout, const Duration(seconds: 60));
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
            );
          };

      expect(
        () => dataSource.explain(payload: samplePayload),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'overrides only explanation receive timeout on the shared Dio',
      () async {
        final dio = Dio(
          BaseOptions(
            connectTimeout: ApiConstants.connectTimeout,
            sendTimeout: ApiConstants.sendTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
          ),
        );
        addTearDown(dio.close);
        final requests = <RequestOptions>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: sampleResponse,
                ),
              );
            },
          ),
        );
        await ExplanationRemoteDataSourceImpl(dio: dio).explain(
          payload: samplePayload,
        );
        await dio.get<Map<String, dynamic>>('/users/me');

        expect(requests, hasLength(2));
        expect(requests.first.receiveTimeout, const Duration(seconds: 60));
        expect(requests.last.receiveTimeout, const Duration(seconds: 15));
        for (final request in requests) {
          expect(request.connectTimeout, const Duration(seconds: 15));
          expect(request.sendTimeout, const Duration(seconds: 15));
        }
        expect(dio.options.receiveTimeout, const Duration(seconds: 15));
      },
    );

    test('propagates receive timeout without automatically retrying', () async {
      var calls = 0;
      final timeout = DioException(
        requestOptions: RequestOptions(path: '/explain'),
        type: DioExceptionType.receiveTimeout,
      );
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
            calls++;
            throw timeout;
          };

      await expectLater(
        dataSource.explain(payload: samplePayload),
        throwsA(same(timeout)),
      );
      expect(calls, 1);
    });
  });
}
