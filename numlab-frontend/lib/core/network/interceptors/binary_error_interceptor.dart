import 'dart:convert';

import 'package:dio/dio.dart';

/// Restores JSON error envelopes for byte requests before auth/error mapping.
/// Successful binary responses never pass through this decoder.
class BinaryErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final body = response?.data;
    if (err.type == DioExceptionType.badResponse &&
        err.requestOptions.responseType == ResponseType.bytes &&
        body is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(body));
        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'];
          // Leave malformed envelopes untouched so existing status-based
          // fallbacks handle them, without casts in the auth interceptor.
          if (decoded['success'] == false &&
              error is Map<String, dynamic> &&
              error['code'] is String &&
              error['message'] is String) {
            response!.data = decoded;
          }
        }
      } on FormatException catch (_) {
        // Gateways may return HTML, plain text, or invalid UTF-8. Preserve the
        // original HTTP error, headers, and bytes instead of hiding its status.
      }
    }
    handler.next(err);
  }
}
