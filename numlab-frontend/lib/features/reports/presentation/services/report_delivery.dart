import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';

enum ReportDeliveryOutcome { saved, cancelled, downloadRequested }

/// Platform delivery only; never generates or fetches a report.
// ignore: one_member_abstracts
abstract interface class ReportDelivery {
  Future<ReportDeliveryOutcome> save(PdfReport report);
}

/// Uses the OS save dialog, or requests a browser-managed download on web.
class FilePickerReportDelivery implements ReportDelivery {
  const FilePickerReportDelivery({FilePicker? picker, bool isWeb = kIsWeb})
    : _picker = picker,
      _isWeb = isWeb;

  final FilePicker? _picker;
  final bool _isWeb;

  /// A local suggestion required by the save API, not server filename metadata.
  static String suggestedFilename(String? filename) {
    final name = filename?.trim();
    if (name == null ||
        name.isEmpty ||
        name.length > 200 ||
        !name.toLowerCase().endsWith('.pdf') ||
        RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]').hasMatch(name) ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
          caseSensitive: false,
        ).hasMatch(name.split('.').first) ||
        name.startsWith('.')) {
      return 'numlab-report.pdf';
    }
    return name;
  }

  @override
  Future<ReportDeliveryOutcome> save(PdfReport report) async {
    final path = await (_picker ?? FilePicker.platform).saveFile(
      dialogTitle: 'Save PDF report',
      fileName: suggestedFilename(report.filename),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: report.bytes,
    );
    // Web always returns null and cannot confirm persistence/cancellation.
    if (_isWeb) return ReportDeliveryOutcome.downloadRequested;
    return path == null || path.isEmpty
        ? ReportDeliveryOutcome.cancelled
        : ReportDeliveryOutcome.saved;
  }
}
