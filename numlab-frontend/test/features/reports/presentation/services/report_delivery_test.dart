import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';

class FakeSavePicker extends Fake implements FilePicker {
  String? result = '/user-selected/report.pdf';
  Exception? error;
  int calls = 0;
  String? filename;
  Uint8List? receivedBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    calls++;
    expect(dialogTitle, 'Save PDF report');
    expect(initialDirectory, isNull);
    expect(type, FileType.custom);
    expect(allowedExtensions, ['pdf']);
    filename = fileName;
    receivedBytes = bytes;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  test(
    'delegates exact bytes and server filename to the user-selected save operation',
    () async {
      final picker = FakeSavePicker();
      final report = PdfReport(
        bytes: const [0x25, 0x50, 0xff],
        filename: 'server-report.pdf',
      );
      final service = FilePickerReportDelivery(picker: picker, isWeb: false);
      expect(await service.save(report), ReportDeliveryOutcome.saved);
      expect(picker.calls, 1);
      expect(picker.receivedBytes, same(report.bytes));
      expect(picker.filename, 'server-report.pdf');
      expect(report.filename, 'server-report.pdf');
    },
  );

  for (final filename in <String?>[
    null,
    '',
    '../private.pdf',
    r'C:\private.pdf',
    'bad\nname.pdf',
    'bad:name.pdf',
    'report.txt',
    '.hidden.pdf',
    'CON.pdf',
    'LPT1.pdf',
    '${List.filled(201, 'a').join()}.pdf',
  ]) {
    test(
      'uses a local required-name fallback for unavailable/unsafe metadata: $filename',
      () async {
        final picker = FakeSavePicker();
        final report = PdfReport(bytes: const [1, 2, 3], filename: filename);
        await FilePickerReportDelivery(
          picker: picker,
          isWeb: false,
        ).save(report);
        expect(picker.filename, 'numlab-report.pdf');
        expect(report.filename, filename);
      },
    );
  }

  test(
    'preserves a safe PDF name including spaces and uppercase extension',
    () {
      expect(
        FilePickerReportDelivery.suggestedFilename('Lab Report 1.PDF'),
        'Lab Report 1.PDF',
      );
    },
  );

  for (final result in <String?>[null, '']) {
    test('native cancellation is not reported as saved: $result', () async {
      final picker = FakeSavePicker()..result = result;
      expect(
        await FilePickerReportDelivery(picker: picker, isWeb: false).save(
          PdfReport(bytes: const [1], filename: 'report.pdf'),
        ),
        ReportDeliveryOutcome.cancelled,
      );
    });
  }

  test(
    'web null return means download requested, not cancellation or confirmed save',
    () async {
      final picker = FakeSavePicker()..result = null;
      expect(
        await FilePickerReportDelivery(picker: picker, isWeb: true).save(
          PdfReport(bytes: const [1], filename: 'report.pdf'),
        ),
        ReportDeliveryOutcome.downloadRequested,
      );
      expect(picker.calls, 1);
    },
  );

  test(
    'propagates file errors to the delivery BLoC instead of claiming success',
    () async {
      final error = Exception('private path');
      final picker = FakeSavePicker()..error = error;
      await expectLater(
        FilePickerReportDelivery(picker: picker, isWeb: false).save(
          PdfReport(bytes: const [1]),
        ),
        throwsA(same(error)),
      );
    },
  );
}
