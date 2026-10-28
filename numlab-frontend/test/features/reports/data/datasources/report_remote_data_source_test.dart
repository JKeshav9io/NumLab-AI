import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/reports/data/datasources/report_remote_data_source.dart';

import '../../report_test_support.dart';

void main() {
  late Dio dio;
  late ReportRemoteDataSourceImpl source;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    source = ReportRemoteDataSourceImpl(dio: dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    'POSTs only the run ID path, requests bytes, and preserves binary data',
    () async {
      final adapter = ReportAdapter((_) async => pdfResponse());
      dio.httpClientAdapter = adapter;

      final result = await source.generateReport(reportRunId);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(
        request.uri.toString(),
        'https://example.test/api/v1/reports/$reportRunId',
      );
      expect(request.path, '${ApiConstants.reportsPath}/$reportRunId');
      expect(request.queryParameters, isEmpty);
      expect(request.data, isNull);
      expect(request.headers['Accept'], 'application/pdf, application/json');
      expect(request.responseType, ResponseType.bytes);
      expect(result.bytes, orderedEquals(pdfBytes));
      expect(result.filename, reportFilename);
    },
  );

  test(
    'encodes the path parameter instead of allowing query/path injection',
    () async {
      final adapter = ReportAdapter((_) async => pdfResponse());
      dio.httpClientAdapter = adapter;
      await source.generateReport('bad/id?limit=0#fragment');
      expect(
        adapter.requests.single.path,
        '/reports/bad%2Fid%3Flimit%3D0%23fragment',
      );
      expect(adapter.requests.single.queryParameters, isEmpty);
    },
  );

  for (final body in <List<int>>[[], '<html>upstream error</html>'.codeUnits]) {
    test('rejects empty or non-PDF HTTP-200 bytes: ${body.length}', () async {
      dio.httpClientAdapter = ReportAdapter(
        (_) async => ResponseBody.fromBytes(
          body,
          200,
          headers: {
            'content-type': ['application/pdf'],
          },
        ),
      );
      await expectLater(
        source.generateReport(reportRunId),
        throwsFormatException,
      );
    });
  }

  test(
    'rejects a success JSON envelope instead of inventing a download URL',
    () async {
      dio.httpClientAdapter = ReportAdapter(
        (_) async => ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {'url': 'report.pdf'},
          }),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      await expectLater(
        source.generateReport(reportRunId),
        throwsFormatException,
      );
    },
  );

  for (final status in [400, 401, 404, 429, 500]) {
    test('preserves HTTP $status exceptions and headers', () async {
      dio.httpClientAdapter = ReportAdapter(
        (_) async => ResponseBody.fromString(
          '{"success":false,"error":{"code":"TEST_ERROR","message":"Failure"}}',
          status,
          headers: {
            'content-type': ['application/json'],
            'retry-after': ['12'],
          },
        ),
      );
      await expectLater(
        source.generateReport(reportRunId),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', status)
              .having(
                (e) => e.response?.headers.value('retry-after'),
                'header',
                '12',
              ),
        ),
      );
    });
  }

  test('rejects unexpected intercepted object responses gracefully', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {'unexpected': true},
            ),
          );
        },
      ),
    );
    await expectLater(
      source.generateReport(reportRunId),
      throwsFormatException,
    );
  });
}
