import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';

const reportRunId = '550e8400-e29b-41d4-a716-446655440000';
const reportFilename = 'numlab-report-root-bisection-550e8400-2026-10-27.pdf';

// A transport fixture including non-UTF8 bytes; never decode PDF content.
final pdfBytes = Uint8List.fromList([
  ...'%PDF-1.3\n%'.codeUnits,
  0xe2,
  0xe3,
  0xcf,
  0xd3,
  ...'\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n'
      .codeUnits,
]);

ResponseBody pdfResponse() => ResponseBody.fromBytes(
  pdfBytes,
  200,
  headers: {
    'content-type': ['application/pdf'],
    'content-disposition': ['attachment; filename="$reportFilename"'],
  },
);

class ReportAdapter implements HttpClientAdapter {
  ReportAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class ReportStorage extends Fake implements SecureStorageService {
  String? accessToken = 'test-access';
  String? refreshToken = 'test-refresh';
  int cleared = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    cleared++;
    accessToken = null;
    refreshToken = null;
  }
}
