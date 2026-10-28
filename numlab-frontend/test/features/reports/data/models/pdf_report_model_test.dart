import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/reports/data/models/pdf_report_model.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';

import '../../report_test_support.dart';

void main() {
  test('preserves every PDF byte and the actual server filename', () {
    final model = PdfReportModel.fromBytes(
      pdfBytes,
      contentType: 'application/pdf',
      contentDisposition: 'attachment; filename="$reportFilename"',
    );
    expect(model.bytes, orderedEquals(pdfBytes));
    expect(model.filename, reportFilename);
    expect(
      model.toEntity(),
      PdfReport(bytes: pdfBytes, filename: reportFilename),
    );
    expect(model.toEntity().runtimeType, PdfReport);
  });

  test('allows MIME parameters, whitespace, and unquoted filename', () {
    final model = PdfReportModel.fromBytes(
      [...pdfBytes, 0, 9, 12, 13, 32],
      contentType: 'Application/PDF; charset=binary',
      contentDisposition: 'attachment; filename=$reportFilename',
    );
    expect(model.filename, reportFilename);
    expect(model.bytes, orderedEquals([...pdfBytes, 0, 9, 12, 13, 32]));
  });

  final invalidBodies = <String, List<int>>{
    'empty': [],
    'HTML': '<html>failed</html>'.codeUnits,
    'JSON': '{"success":true,"data":{"url":"report.pdf"}}'.codeUnits,
    'magic only': '%PDF-'.codeUnits,
    'invalid version header': '%PDF-garbage\n%%EOF'.codeUnits,
    'truncated PDF': pdfBytes.sublist(0, pdfBytes.length - 6),
    'trailing garbage': [...pdfBytes, ...'garbage'.codeUnits],
  };
  for (final entry in invalidBodies.entries) {
    test('rejects ${entry.key} content', () {
      expect(
        () => PdfReportModel.fromBytes(
          entry.value,
          contentType: 'application/pdf',
        ),
        throwsFormatException,
      );
    });
  }
  for (final mime in [null, '', 'application/json', 'text/html']) {
    test('rejects missing or incorrect MIME type $mime', () {
      expect(
        () => PdfReportModel.fromBytes(pdfBytes, contentType: mime),
        throwsFormatException,
      );
    });
  }

  for (final disposition in [
    null,
    'attachment',
    'attachment; filename=""',
    'attachment; filename="../../private.pdf"',
    r'attachment; filename="C:\private.pdf"',
    'attachment; filename="bad\r\nname.pdf"',
  ]) {
    test('leaves absent/unsafe filename unknown: $disposition', () {
      final model = PdfReportModel.fromBytes(
        pdfBytes,
        contentType: 'application/pdf',
        contentDisposition: disposition,
      );
      expect(model.filename, isNull);
      expect(model.bytes, orderedEquals(pdfBytes));
    });
  }

  test('isolates bytes from caller mutation and prevents result mutation', () {
    final input = pdfBytes.toList();
    final model = PdfReportModel.fromBytes(
      input,
      contentType: 'application/pdf',
    );
    input[0] = 0;
    expect(model.bytes, orderedEquals(pdfBytes));
    expect(() => model.bytes[0] = 0, throwsUnsupportedError);
    expect(() => model.toEntity().bytes[0] = 0, throwsUnsupportedError);
  });
}
