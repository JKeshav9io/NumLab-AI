import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/core/network/dio_client.dart';
import 'package:numlab_frontend/core/network/interceptors/auth_interceptor.dart';
import 'package:numlab_frontend/features/reports/data/datasources/report_remote_data_source.dart';
import 'package:numlab_frontend/features/reports/data/repositories/report_repository_impl.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';

import '../../report_test_support.dart';

void main() {
  late ReportStorage storage;
  late Dio dio;
  late Dio refreshDio;
  late ReportRepositoryImpl repository;
  late ReportAdapter adapter;
  var revoked = 0;

  setUp(() {
    storage = ReportStorage();
    revoked = 0;
    refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio = DioClient.create(
      secureStorageService: storage,
      baseUrl: 'https://example.test/api/v1',
      refreshDio: refreshDio,
      onSessionRevoked: () => revoked++,
    );
    repository = ReportRepositoryImpl(
      remoteDataSource: ReportRemoteDataSourceImpl(dio: dio),
    );
  });
  tearDown(() {
    dio.close(force: true);
    refreshDio.close(force: true);
  });

  void respond(Future<ResponseBody> Function(RequestOptions) handler) {
    adapter = ReportAdapter(handler);
    dio.httpClientAdapter = adapter;
  }

  Future<Failure> failure() async =>
      (await repository.generateReport(reportRunId)).fold(
        (f) => f,
        (_) => throw StateError('Expected a failure'),
      );

  ResponseBody error(int status, String code, {Object? details}) =>
      ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'error': {
            'code': code,
            'message': 'Backend $code',
            'details': details,
          },
        }),
        status,
        headers: {
          'content-type': ['application/json'],
          'retry-after': ['20'],
        },
      );

  test(
    'returns the pure PDF result with shared auth and unchanged timeouts',
    () async {
      respond((_) async => pdfResponse());
      final result = await repository.generateReport(reportRunId);
      result.fold((f) => fail('$f'), (report) {
        expect(report.runtimeType, PdfReport);
        expect(report.bytes, orderedEquals(pdfBytes));
        expect(report.filename, reportFilename);
      });
      final request = adapter.requests.single;
      expect(request.headers['Authorization'], 'Bearer test-access');
      expect(request.receiveTimeout, ApiConstants.receiveTimeout);
      expect(request.connectTimeout, ApiConstants.connectTimeout);
      expect(request.sendTimeout, ApiConstants.sendTimeout);
      expect(dio.options.headers['Accept'], 'application/json');
    },
  );

  for (final code in ['UNAUTHORIZED', 'INVALID_TOKEN']) {
    test('maps binary 401 $code without automatic refresh', () async {
      storage.accessToken = null;
      respond((_) async => error(401, code));
      expect(
        await failure(),
        AuthFailure(message: 'Backend $code', code: code),
      );
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  }

  for (final entry in {
    404: 'NOT_FOUND',
    500: 'REPORT_GENERATION_ERROR',
  }.entries) {
    test(
      'maps binary ${entry.key} with backend code, message, and status',
      () async {
        respond((_) async => error(entry.key, entry.value));
        expect(
          await failure(),
          ServerFailure(
            message: 'Backend ${entry.value}',
            code: entry.value,
            statusCode: entry.key,
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test('maps binary validation details including runId', () async {
    respond(
      (_) async => error(
        400,
        'VALIDATION_ERROR',
        details: [
          {'field': 'runId', 'message': 'runId must be a valid GUID'},
        ],
      ),
    );
    expect(
      await failure(),
      const ValidationFailure(
        message: 'Backend VALIDATION_ERROR',
        fieldErrors: [
          FieldError(field: 'runId', message: 'runId must be a valid GUID'),
        ],
      ),
    );
  });

  test(
    'preserves the actual report validator string-detail contract',
    () async {
      respond(
        (_) async => error(
          400,
          'VALIDATION_ERROR',
          details: {
            'details': ['"runId" must be a valid GUID'],
          },
        ),
      );
      expect(
        await failure(),
        const ValidationFailure(
          message: 'Backend VALIDATION_ERROR',
          fieldErrors: [
            FieldError(field: '', message: '"runId" must be a valid GUID'),
          ],
        ),
      );
    },
  );

  test(
    'malformed validation fields cannot throw out of the repository',
    () async {
      respond(
        (_) async => error(
          400,
          'VALIDATION_ERROR',
          details: {
            'fields': [
              {'field': 3, 'message': <Object?>[]},
              {'field': 'runId', 'message': 'Expected UUID'},
            ],
          },
        ),
      );
      expect(
        await failure(),
        const ValidationFailure(
          message: 'Backend VALIDATION_ERROR',
          fieldErrors: [FieldError(field: 'runId', message: 'Expected UUID')],
        ),
      );
    },
  );

  test('maps binary rate limits and supplied cooldown metadata', () async {
    respond(
      (_) async =>
          error(429, 'RATE_LIMIT_EXCEEDED', details: {'retryAfterSeconds': 30}),
    );
    expect(
      await failure(),
      const RateLimitFailure(
        message: 'Backend RATE_LIMIT_EXCEEDED',
        retryAfterSeconds: 30,
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('maps plain-text 429 using the existing Retry-After fallback', () async {
    respond(
      (_) async => ResponseBody.fromString(
        'Too many requests',
        429,
        headers: {
          'content-type': ['text/plain'],
          'retry-after': ['20'],
        },
      ),
    );
    expect(
      await failure(),
      const RateLimitFailure(
        message: 'Too many requests. Please wait before trying again.',
        retryAfterSeconds: 20,
      ),
    );
  });

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.transformTimeout,
  ]) {
    test('maps $type without retrying the report', () async {
      respond(
        (options) async =>
            throw DioException(requestOptions: options, type: type),
      );
      final result = await failure();
      expect(result, isA<NetworkFailure>());
      expect(
        result.code,
        type == DioExceptionType.connectionError
            ? 'NETWORK_ERROR'
            : 'REQUEST_TIMEOUT',
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final body in <List<int>>[
    [],
    '<html>bad gateway</html>'.codeUnits,
    pdfBytes.sublist(0, 15),
  ]) {
    test(
      'maps invalid PDF success bytes (${body.length}) to recoverable server failure',
      () async {
        respond(
          (_) async => ResponseBody.fromBytes(
            body,
            200,
            headers: {
              'content-type': ['application/pdf'],
            },
          ),
        );
        expect(
          await failure(),
          isA<ServerFailure>().having(
            (f) => f.message,
            'message',
            contains('invalid PDF'),
          ),
        );
      },
    );
  }

  for (final body in [
    '<html>failed</html>',
    '{broken',
    '[]',
    '{"success":false,"error":{"code":42,"message":{}}}',
  ]) {
    test('keeps status for malformed error response $body', () async {
      respond(
        (_) async => ResponseBody.fromString(
          body,
          502,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      expect(
        await failure(),
        const ServerFailure(
          message: 'Server responded with error status: 502',
          statusCode: 502,
        ),
      );
    });
  }

  test(
    'binary TOKEN_EXPIRED rotates once and replays the PDF options',
    () async {
      final refresh = ReportAdapter((options) async {
        expect(options.path, ApiConstants.refreshPath);
        expect(options.data, {'refreshToken': 'test-refresh'});
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'tokens': {
                'accessToken': 'rotated-access',
                'refreshToken': 'rotated-refresh',
                'expiresIn': 900,
              },
            },
          }),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
      });
      refreshDio.httpClientAdapter = refresh;
      respond(
        (options) async =>
            options.extra[AuthInterceptor.retryCountExtraKey] == 1
            ? pdfResponse()
            : error(401, 'TOKEN_EXPIRED'),
      );
      final result = await repository.generateReport(reportRunId);
      expect(result.isRight(), isTrue);
      expect(refresh.requests, hasLength(1));
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer rotated-access',
      );
      expect(adapter.requests.last.responseType, ResponseType.bytes);
      expect(
        adapter.requests.last.headers['Accept'],
        'application/pdf, application/json',
      );
      expect(adapter.requests.last.receiveTimeout, ApiConstants.receiveTimeout);
      expect(storage.refreshToken, 'rotated-refresh');
      expect(revoked, 0);
    },
  );

  test(
    'refresh failure clears the session and does not replay the report',
    () async {
      final refresh = ReportAdapter((_) async => error(401, 'TOKEN_REVOKED'));
      refreshDio.httpClientAdapter = refresh;
      respond((_) async => error(401, 'TOKEN_EXPIRED'));
      expect(
        await failure(),
        isA<AuthFailure>().having((f) => f.code, 'code', 'TOKEN_EXPIRED'),
      );
      expect(refresh.requests, hasLength(1));
      expect(adapter.requests, hasLength(1));
      expect(storage.cleared, 1);
      expect(revoked, 1);
    },
  );

  test(
    'repeated TOKEN_EXPIRED stops after the existing single replay',
    () async {
      final refresh = ReportAdapter(
        (_) async => ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'tokens': {
                'accessToken': 'rotated',
                'refreshToken': 'new-refresh',
                'expiresIn': 900,
              },
            },
          }),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      refreshDio.httpClientAdapter = refresh;
      respond((_) async => error(401, 'TOKEN_EXPIRED'));
      expect(await failure(), isA<AuthFailure>());
      expect(refresh.requests, hasLength(1));
      expect(adapter.requests, hasLength(2));
    },
  );

  for (final transportFailure in [false, true]) {
    test(
      'failed auth replay returns without hanging (network: $transportFailure)',
      () async {
        final refresh = ReportAdapter(
          (_) async => ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'data': {
                'tokens': {
                  'accessToken': 'rotated',
                  'refreshToken': 'new-refresh',
                  'expiresIn': 900,
                },
              },
            }),
            200,
            headers: {
              'content-type': ['application/json'],
            },
          ),
        );
        refreshDio.httpClientAdapter = refresh;
        respond((options) async {
          if (options.extra[AuthInterceptor.retryCountExtraKey] != 1) {
            return error(401, 'TOKEN_EXPIRED');
          }
          if (transportFailure) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return error(404, 'NOT_FOUND');
        });
        final result = await failure();
        if (transportFailure) {
          expect(
            result,
            isA<NetworkFailure>().having(
              (f) => f.code,
              'code',
              'REQUEST_TIMEOUT',
            ),
          );
        } else {
          expect(
            result,
            const ServerFailure(
              message: 'Backend NOT_FOUND',
              code: 'NOT_FOUND',
              statusCode: 404,
            ),
          );
        }
        expect(adapter.requests, hasLength(2));
        expect(refresh.requests, hasLength(1));
        expect(revoked, 0);
      },
    );
  }
}
