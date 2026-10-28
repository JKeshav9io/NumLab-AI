import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/network/interceptors/binary_error_interceptor.dart';

class CapturingErrorHandler extends ErrorInterceptorHandler {
  DioException? forwarded;

  @override
  void next(DioException err) => forwarded = err;
}

void main() {
  final interceptor = BinaryErrorInterceptor();
  final envelope = <String, dynamic>{
    'success': false,
    'error': <String, dynamic>{'code': 'TOKEN_EXPIRED', 'message': 'Expired'},
  };

  test(
    'decodes only error bytes and retains exception, status, and headers',
    () {
      final options = RequestOptions(
        path: '/reports/run',
        responseType: ResponseType.bytes,
      );
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          data: utf8.encode(jsonEncode(envelope)),
          statusCode: 401,
          headers: Headers.fromMap({
            'retry-after': ['15'],
          }),
        ),
      );
      final handler = CapturingErrorHandler();
      interceptor.onError(err, handler);
      expect(handler.forwarded, same(err));
      expect(err.response!.data, envelope);
      expect(err.response!.statusCode, 401);
      expect(err.response!.headers.value('retry-after'), '15');
      expect(err.requestOptions, same(options));
    },
  );

  test('leaves successful PDF bytes unchanged', () {
    final bytes = [0x25, 0x50, 0x44, 0x46, 0xff];
    final response = Response<dynamic>(
      requestOptions: RequestOptions(
        path: '/reports/run',
        responseType: ResponseType.bytes,
      ),
      data: bytes,
      statusCode: 200,
    );
    interceptor.onResponse(response, ResponseInterceptorHandler());
    expect(response.data, same(bytes));
  });

  for (final body in <Object?>[
    null,
    utf8.encode('<html>gateway error</html>'),
    [0xff, 0xfe],
    utf8.encode('[]'),
    utf8.encode('{"success":false,"error":{"code":5,"message":[]}}'),
    envelope,
  ]) {
    test('preserves malformed or already-decoded error body $body', () {
      final options = RequestOptions(
        path: '/reports/run',
        responseType: ResponseType.bytes,
      );
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          data: body,
          statusCode: 502,
        ),
      );
      final handler = CapturingErrorHandler();
      interceptor.onError(err, handler);
      expect(handler.forwarded, same(err));
      expect(err.response!.data, same(body));
      expect(err.response!.statusCode, 502);
    });
  }

  test('does not change the JSON request error path', () {
    final bytes = utf8.encode(jsonEncode(envelope));
    final options = RequestOptions(path: '/explain');
    final err = DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: options,
        data: bytes,
        statusCode: 401,
      ),
    );
    final handler = CapturingErrorHandler();
    interceptor.onError(err, handler);
    expect(handler.forwarded, same(err));
    expect(err.response!.data, same(bytes));
  });
}
