import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_share_files_io.dart'
    if (dart.library.js_interop) 'package:numlab_frontend/features/reports/presentation/services/report_share_files_web.dart'
    as platform;
import 'package:share_plus/share_plus.dart';

/// File staging boundary, faked independently of the platform sharing plugin.
// ignore: one_member_abstracts
abstract interface class ReportShareFiles {
  Future<XFile> prepare(PdfReport report, String filename);
}

ReportShareFiles createReportShareFiles() => platform.createReportShareFiles();

/// Web Share accepts bytes without staging a native file.
class MemoryReportShareFiles implements ReportShareFiles {
  const MemoryReportShareFiles();

  @override
  Future<XFile> prepare(PdfReport report, String filename) async =>
      XFile.fromData(
        report.bytes,
        mimeType: 'application/pdf',
        name: filename,
      );
}
