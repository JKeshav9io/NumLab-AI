import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/error/error_mapper.dart';
import 'package:numlab_frontend/core/error/failures.dart';

void main() {
  RateLimitFailure mapRateLimit({
    Object? body,
    String? header,
    int status = 429,
  }) {
    final options = RequestOptions(path: '/explain');
    final failure = mapExceptionToFailure(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: body,
          headers: Headers.fromMap({
            if (header != null) 'retry-after': [header],
          }),
        ),
      ),
    );
    expect(failure, isA<RateLimitFailure>());
    return failure as RateLimitFailure;
  }

  Map<String, dynamic> envelope(Object? seconds) => {
    'success': false,
    'error': {
      'code': 'RATE_LIMIT_EXCEEDED',
      'message': 'Uncached AI explanation quota exceeded.',
      'details': {'retryAfterSeconds': seconds},
    },
  };

  for (final value in [0, 45, '120', ' 60 ']) {
    test('preserves valid retryAfterSeconds: $value', () {
      final failure = mapRateLimit(body: envelope(value));
      expect(failure.retryAfterSeconds, int.parse(value.toString().trim()));
      expect(failure.code, 'RATE_LIMIT_EXCEEDED');
      expect(failure.message, 'Uncached AI explanation quota exceeded.');
    });
  }

  for (final value in <Object?>[
    null,
    -1,
    1.5,
    true,
    'soon',
    '-3',
    'NaN',
    <Object?>[],
    <String, Object?>{},
  ]) {
    test('ignores invalid cooldown metadata: $value', () {
      final failure = mapRateLimit(body: envelope(value));
      expect(failure.retryAfterSeconds, isNull);
      expect(failure, isA<RateLimitFailure>());
    });
  }

  test('honors the longer supplied body/header cooldown', () {
    expect(
      mapRateLimit(body: envelope(900), header: '60').retryAfterSeconds,
      900,
    );
    expect(
      mapRateLimit(body: envelope(30), header: '60').retryAfterSeconds,
      60,
    );
  });

  test('uses valid Retry-After when body metadata is invalid', () {
    expect(
      mapRateLimit(body: envelope('bad'), header: '75').retryAfterSeconds,
      75,
    );
  });

  for (final body in <Object?>[
    'Too many requests, please try again later.',
    null,
    <String, dynamic>{},
    {
      'error': {'message': 12, 'code': <Object?>[]},
    },
  ]) {
    test('plain or malformed HTTP 429 body remains a rate limit: $body', () {
      final failure = mapRateLimit(body: body, header: '60');
      expect(failure.retryAfterSeconds, 60);
      expect(failure.code, 'RATE_LIMIT_EXCEEDED');
      expect(failure.message, contains('Too many requests'));
    });
  }

  for (final header in ['-2', '1.5', 'later', '']) {
    test('invalid Retry-After does not invent a duration: "$header"', () {
      expect(mapRateLimit(header: header).retryAfterSeconds, isNull);
    });
  }

  test('rate-limit code remains supported without HTTP 429', () {
    expect(
      mapRateLimit(body: envelope(45), status: 400).retryAfterSeconds,
      45,
    );
  });
}
