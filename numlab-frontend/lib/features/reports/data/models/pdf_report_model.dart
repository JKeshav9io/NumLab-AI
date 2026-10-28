import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';

/// Maps the binary report response, without decoding PDF content as text/JSON.
class PdfReportModel extends PdfReport {
  PdfReportModel({required super.bytes, super.filename});

  factory PdfReportModel.fromBytes(
    List<int> bytes, {
    required String? contentType,
    String? contentDisposition,
  }) {
    final mediaType = contentType?.split(';').first.trim().toLowerCase();
    const header = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
    const eof = [0x25, 0x25, 0x45, 0x4f, 0x46]; // %%EOF
    var end = bytes.length;
    // PDFKit ends with a newline; PDF whitespace may follow the EOF marker.
    while (end > 0 && const [0, 9, 10, 12, 13, 32].contains(bytes[end - 1])) {
      end--;
    }
    if (mediaType != 'application/pdf' ||
        end < 14 ||
        !List.generate(5, (i) => bytes[i] == header[i]).every((v) => v) ||
        bytes[5] < 0x30 ||
        bytes[5] > 0x39 ||
        bytes[6] != 0x2e ||
        bytes[7] < 0x30 ||
        bytes[7] > 0x39 ||
        (bytes[8] != 10 && bytes[8] != 13) ||
        !List.generate(
          5,
          (i) => bytes[end - 5 + i] == eof[i],
        ).every((v) => v)) {
      throw const FormatException('Empty or invalid PDF report response.');
    }

    return PdfReportModel(
      bytes: bytes,
      filename: _filename(contentDisposition),
    );
  }

  static String? _filename(String? disposition) {
    if (disposition == null) return null;
    final match = RegExp(
      r'(?:^|;)\s*filename\s*=\s*(?:"([^"]*)"|([^;]*))',
      caseSensitive: false,
    ).firstMatch(disposition);
    final name = (match?.group(1) ?? match?.group(2))?.trim();
    if (name == null ||
        name.isEmpty ||
        RegExp(r'[/\\\x00-\x1f\x7f]').hasMatch(name)) {
      return null;
    }
    return name;
  }

  PdfReport toEntity() => PdfReport(bytes: bytes, filename: filename);
}
