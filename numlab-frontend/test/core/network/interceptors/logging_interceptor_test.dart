import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:numlab_frontend/core/network/interceptors/logging_interceptor.dart';

void main() {
  group('Priority 6: Logging & Security Hardening', () {
    test('redacts Authorization, Cookie, and sensitive tokens from headers', () {
      final rawHeaders = <String, dynamic>{
        'Authorization': 'Bearer secret_access_jwt_token_12345',
        'Cookie': 'session=abcde12345',
        'X-Auth-Token': 'token_xyz_98765',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final sanitized = DebugLoggingInterceptor.redactHeaders(rawHeaders);

      expect(sanitized['Authorization'], equals('[REDACTED]'));
      expect(sanitized['Cookie'], equals('[REDACTED]'));
      expect(sanitized['X-Auth-Token'], equals('[REDACTED]'));
      expect(sanitized['Content-Type'], equals('application/json'));
      expect(sanitized['Accept'], equals('application/json'));
    });

    test('recursively redacts password and tokens in request & response payloads', () {
      final rawPayload = <String, dynamic>{
        'email': 'user@example.com',
        'password': 'SuperSecretPassword123!',
        'password_confirmation': 'SuperSecretPassword123!',
        'data': {
          'tokens': {
            'accessToken': 'jwt_access_token_payload',
            'refreshToken': 'jwt_refresh_token_payload',
          },
          'user': {
            'id': 'usr_123',
            'email': 'user@example.com',
          },
        },
        'list': [
          {'apiKey': 'api_key_secret', 'publicName': 'MyKey'},
        ],
      };

      final sanitized = DebugLoggingInterceptor.redactData(rawPayload) as Map;

      expect(sanitized['email'], equals('user@example.com'));
      expect(sanitized['password'], equals('[REDACTED]'));
      expect(sanitized['password_confirmation'], equals('[REDACTED]'));

      final dataMap = sanitized['data'] as Map;
      final tokensMap = dataMap['tokens'] as Map;
      expect(tokensMap['accessToken'], equals('[REDACTED]'));
      expect(tokensMap['refreshToken'], equals('[REDACTED]'));

      final userMap = dataMap['user'] as Map;
      expect(userMap['id'], equals('usr_123'));
      expect(userMap['email'], equals('user@example.com'));

      final list = sanitized['list'] as List;
      final firstItem = list.first as Map;
      expect(firstItem['apiKey'], equals('[REDACTED]'));
      expect(firstItem['publicName'], equals('MyKey'));
    });

    test('isExpectedDomainError correctly identifies 4xx solver/validation failures', () {
      final validationError = DioException(
        requestOptions: RequestOptions(path: '/solve/root/bisection'),
        response: Response(
          statusCode: 400,
          requestOptions: RequestOptions(path: '/solve/root/bisection'),
          data: {
            'error': {'code': 'SOLVER_PRECONDITION_FAILED', 'message': 'Opposite signs required'},
          },
        ),
      );

      final singularMatrixError = DioException(
        requestOptions: RequestOptions(path: '/solve/linear/gauss'),
        response: Response(
          statusCode: 400,
          requestOptions: RequestOptions(path: '/solve/linear/gauss'),
          data: {
            'error': {'code': 'SINGULAR_MATRIX', 'message': 'Zero determinant'},
          },
        ),
      );

      final serverError = DioException(
        requestOptions: RequestOptions(path: '/solve/root/bisection'),
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/solve/root/bisection'),
          data: {
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Fatal crash'},
          },
        ),
      );

      expect(DebugLoggingInterceptor.isExpectedDomainError(validationError), isTrue);
      expect(DebugLoggingInterceptor.isExpectedDomainError(singularMatrixError), isTrue);
      expect(DebugLoggingInterceptor.isExpectedDomainError(serverError), isFalse);

      final evalFailedError = DioException(
        requestOptions: RequestOptions(path: '/solve/root/bisection'),
        response: Response(
          statusCode: 400,
          requestOptions: RequestOptions(path: '/solve/root/bisection'),
          data: {
            'error': {
              'code': 'EVAL_FAILED',
              'message': 'Expression evaluation failed',
            },
          },
        ),
      );
      expect(DebugLoggingInterceptor.isExpectedDomainError(evalFailedError), isTrue);
    });

    group('HTTP 400 Concise Logging Verification', () {
      test('400 + structured EVAL_FAILED produces concise code + message without Dio boilerplate', () {
        final err = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: {
              'success': false,
              'error': {
                'code': 'EVAL_FAILED',
                'message': 'Expression evaluation failed',
                'details': {
                  'scope': {'x': 0},
                },
              },
            },
          ),
          message:
              'The status code of 400 has the following meaning: "Bad Request". See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400. In order to resolve this exception...',
        );

        final log = DebugLoggingInterceptor.formatBadRequestLog(err);

        expect(
          log,
          contains('⚠️ [400 EVAL_FAILED] POST /api/v1/solve/root/bisection'),
        );
        expect(log, contains('Expression evaluation failed'));
        expect(log, contains('details: {scope: {x: 0}}'));
        expect(log, isNot(contains('The status code of 400 has the following meaning')));
        expect(log, isNot(contains('https://developer.mozilla.org')));
        expect(log, isNot(contains('In order to resolve this exception')));
      });

      test('400 + SOLVER_PRECONDITION_FAILED produces concise code + message', () {
        final err = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: {
              'success': false,
              'error': {
                'code': 'SOLVER_PRECONDITION_FAILED',
                'message':
                    'Function values at the bounds must have opposite signs.',
              },
            },
          ),
          message:
              'The status code of 400 has the following meaning: "Bad Request".',
        );

        final log = DebugLoggingInterceptor.formatBadRequestLog(err);

        expect(
          log,
          contains('⚠️ [400 SOLVER_PRECONDITION_FAILED] POST /api/v1/solve/root/bisection'),
        );
        expect(
          log,
          contains('Function values at the bounds must have opposite signs.'),
        );
        expect(log, isNot(contains('details:')));
        expect(log, isNot(contains('The status code of 400')));
      });

      test('400 + details preserves useful details while redacting sensitive fields', () {
        final err = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: {
              'success': false,
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Parameter validation failed',
                'details': {
                  'scope': {'x': 10},
                  'password': 'SuperSecretPassword123',
                  'apiKey': 'my_api_key_value',
                  'accessToken': 'jwt_token_here',
                },
              },
            },
          ),
        );

        final log = DebugLoggingInterceptor.formatBadRequestLog(err);

        expect(log, contains('⚠️ [400 VALIDATION_ERROR] POST /api/v1/solve/root/bisection'));
        expect(log, contains('Parameter validation failed'));
        expect(log, contains('scope: {x: 10}'));
        expect(log, contains('password: [REDACTED]'));
        expect(log, contains('apiKey: [REDACTED]'));
        expect(log, contains('accessToken: [REDACTED]'));
        expect(log, isNot(contains('SuperSecretPassword123')));
        expect(log, isNot(contains('my_api_key_value')));
        expect(log, isNot(contains('jwt_token_here')));
      });

      test('400 + malformed/no error envelope falls back safely and gracefully', () {
        // Case A: String response without envelope
        final stringErr = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            statusMessage: 'Bad Request',
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: 'Malformed non-JSON solver error response',
          ),
          message:
              'The status code of 400 has the following meaning: "Bad Request".',
        );

        final stringLog = DebugLoggingInterceptor.formatBadRequestLog(stringErr);
        expect(
          stringLog,
          contains('⚠️ [400 BAD_REQUEST] POST /api/v1/solve/root/bisection'),
        );
        expect(stringLog, contains('Malformed non-JSON solver error response'));
        expect(stringLog, isNot(contains('The status code of 400')));

        // Case B: Null body falls back to statusMessage / 'Bad Request'
        final nullErr = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            statusMessage: 'Bad Request',
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
          ),
          message:
              'The status code of 400 has the following meaning: "Bad Request".',
        );

        final nullLog = DebugLoggingInterceptor.formatBadRequestLog(nullErr);
        expect(
          nullLog,
          contains('⚠️ [400 BAD_REQUEST] POST /api/v1/solve/root/bisection'),
        );
        expect(nullLog, contains('Bad Request'));
        expect(nullLog, isNot(contains('The status code of 400')));

        // Case C: HTML error page is not dumped into terminal
        final htmlErr = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            statusMessage: 'Bad Request',
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: '<!DOCTYPE html><html><body>Error 400</body></html>',
          ),
        );

        final htmlLog = DebugLoggingInterceptor.formatBadRequestLog(htmlErr);
        expect(
          htmlLog,
          contains('⚠️ [400 BAD_REQUEST] POST /api/v1/solve/root/bisection'),
        );
        expect(htmlLog, contains('Bad Request'));
        expect(htmlLog, isNot(contains('<html>')));
      });

      test('DebugLoggingInterceptor.onError logs warning for 400 and error for 500', () {
        final testOutput = _TestLogOutput();
        final logger = Logger(
          filter: _AlwaysFilter(),
          output: testOutput,
          printer: SimplePrinter(colors: false),
        );
        final interceptor = DebugLoggingInterceptor(logger: logger);

        // 1. 400 Solver error
        final dio400Err = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 400,
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: {
              'success': false,
              'error': {
                'code': 'EVAL_FAILED',
                'message': 'Expression evaluation failed',
              },
            },
          ),
          message: 'The status code of 400 has the following meaning: "Bad Request".',
        );

        interceptor.onError(dio400Err, _TestErrorInterceptorHandler());

        expect(testOutput.events.length, equals(1));
        final event400 = testOutput.events.first;
        expect(event400.level, equals(Level.warning));
        expect(event400.lines.join('\n'), contains('⚠️ [400 EVAL_FAILED]'));
        expect(
          event400.lines.join('\n'),
          isNot(contains('The status code of 400 has the following meaning')),
        );

        // 2. 500 Internal Server error retains Level.error and full diagnostics
        final dio500Err = DioException(
          requestOptions: RequestOptions(
            path: '/api/v1/solve/root/bisection',
            method: 'POST',
          ),
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(
              path: '/api/v1/solve/root/bisection',
              method: 'POST',
            ),
            data: {
              'error': {'code': 'INTERNAL_ERROR', 'message': 'Fatal crash'},
            },
          ),
          error: Exception('Internal server explosion'),
          stackTrace: StackTrace.current,
          message: 'Internal server error 500',
        );

        interceptor.onError(dio500Err, _TestErrorInterceptorHandler());

        expect(testOutput.events.length, equals(2));
        final event500 = testOutput.events[1];
        expect(event500.level, equals(Level.error));
        expect(event500.lines.join('\n'), contains('ERROR [500]'));
        expect(event500.lines.join('\n'), contains('INTERNAL_ERROR'));
      });
    });
  });
}

class _TestLogOutput extends LogOutput {
  final List<OutputEvent> events = [];

  @override
  void output(OutputEvent event) {
    events.add(event);
  }
}

class _AlwaysFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

class _TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}

  @override
  void resolve(Response<dynamic> response) {}

  @override
  void reject(
    DioException err, [
    bool callFollowingErrorInterceptor = false,
  ]) {}
}
