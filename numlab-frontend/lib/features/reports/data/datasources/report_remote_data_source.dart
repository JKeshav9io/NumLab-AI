import 'package:dio/dio.dart';
import 'package:numlab_frontend/core/constants/api_constants.dart';
import 'package:numlab_frontend/features/reports/data/models/pdf_report_model.dart';

/// Single-endpoint boundary for the existing report-generation API.
// ignore: one_member_abstracts
abstract interface class ReportRemoteDataSource {
  Future<PdfReportModel> generateReport(String runId);
}

/// Uses the configured client for Bearer injection and single refresh replay.
class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  const ReportRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<PdfReportModel> generateReport(String runId) async {
    final response = await _dio.post<dynamic>(
      '${ApiConstants.reportsPath}/${Uri.encodeComponent(runId)}',
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': 'application/pdf, application/json'},
      ),
    );
    final body = response.data;
    if (body is! List<int>) {
      throw const FormatException('Unexpected PDF report response format.');
    }
    return PdfReportModel.fromBytes(
      body,
      contentType: response.headers.value(Headers.contentTypeHeader),
      contentDisposition: response.headers.value('content-disposition'),
    );
  }
}
