import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_share_files.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_sharing.dart';
import 'package:share_plus/share_plus.dart';

class TestShareFiles implements ReportShareFiles {
  final reports = <PdfReport>[];
  final names = <String>[];
  @override
  Future<XFile> prepare(PdfReport report, String filename) async {
    reports.add(report);
    names.add(filename);
    return const MemoryReportShareFiles().prepare(report, filename);
  }
}

void main() {
  final report = PdfReport(
    bytes: const [0x25, 0xff, 0, 1],
    filename: 'server.pdf',
  );
  const origin = Rect.fromLTWH(8, 20, 200, 44);
  late TestShareFiles files;
  late List<ShareParams> calls;
  late SharePlusReportSharing service;
  late ShareResult result;
  setUp(() {
    files = TestShareFiles();
    calls = [];
    result = const ShareResult('target', ShareResultStatus.success);
    service = SharePlusReportSharing(
      files: files,
      platform: TargetPlatform.android,
      isWeb: false,
      invoke: (params) async {
        calls.add(params);
        return result;
      },
    );
  });

  test(
    'shares one original PDF with filename, MIME, title and iPad anchor',
    () async {
      expect(
        await service.share(report, origin: origin),
        ReportShareOutcome.targetSelected,
      );
      expect(files.reports.single, same(report));
      expect(files.reports.single.bytes, same(report.bytes));
      final params = calls.single;
      expect(await params.files!.single.readAsBytes(), report.bytes);
      expect(params.files!.single.mimeType, 'application/pdf');
      expect(params.fileNameOverrides, ['server.pdf']);
      expect(params.sharePositionOrigin, origin);
      expect(params.title, 'NumLab PDF report');
      expect(params.subject, 'NumLab PDF report');
      expect(params.uri, isNull);
      expect(params.text, isNull);
      expect(params.downloadFallbackEnabled, isFalse);
      expect(params.mailToFallbackEnabled, isFalse);
    },
  );

  for (final status in ShareResultStatus.values) {
    test('maps $status without claiming completed delivery', () async {
      result = ShareResult('private platform target', status);
      final expected = switch (status) {
        ShareResultStatus.success => ReportShareOutcome.targetSelected,
        ShareResultStatus.dismissed => ReportShareOutcome.cancelled,
        ShareResultStatus.unavailable => ReportShareOutcome.unconfirmed,
      };
      expect(await service.share(report, origin: origin), expected);
    });
  }

  for (final filename in <String?>[
    null,
    '',
    '../unsafe.pdf',
    'CON.pdf',
    'wrong.txt',
    'bad\n.pdf',
  ]) {
    test(
      'uses a local fallback for ${filename == null ? 'missing' : 'invalid'} metadata: $filename',
      () async {
        final value = PdfReport(bytes: report.bytes, filename: filename);
        await service.share(value, origin: origin);
        expect(calls.single.fileNameOverrides, ['numlab-report.pdf']);
        expect(value.filename, filename);
      },
    );
  }

  for (final platform in TargetPlatform.values) {
    test('PDF platform support is explicit: $platform', () async {
      final subject = SharePlusReportSharing(
        files: files,
        platform: platform,
        isWeb: false,
        invoke: (params) async {
          calls.add(params);
          return result;
        },
      );
      final supported =
          platform != TargetPlatform.linux &&
          platform != TargetPlatform.fuchsia;
      expect(
        await subject.share(report, origin: origin),
        supported
            ? ReportShareOutcome.targetSelected
            : ReportShareOutcome.unsupported,
      );
      expect(calls, hasLength(supported ? 1 : 0));
      expect(files.reports, hasLength(supported ? 1 : 0));
    });
  }

  test(
    'web uses file sharing independently of the host and disables downloads',
    () async {
      final subject = SharePlusReportSharing(
        files: const MemoryReportShareFiles(),
        platform: TargetPlatform.linux,
        isWeb: true,
        invoke: (params) async {
          calls.add(params);
          return ShareResult.unavailable;
        },
      );
      expect(
        await subject.share(report, origin: origin),
        ReportShareOutcome.unconfirmed,
      );
      expect(await calls.single.files!.single.readAsBytes(), report.bytes);
      expect(calls.single.downloadFallbackEnabled, isFalse);
    },
  );

  test(
    'singleton guard prevents concurrent sheets across separate action scopes',
    () async {
      final pending = Completer<ShareResult>();
      var count = 0;
      final subject = SharePlusReportSharing(
        files: files,
        platform: TargetPlatform.android,
        invoke: (_) {
          count++;
          return pending.future;
        },
      );
      final first = subject.share(report, origin: origin);
      expect(
        await subject.share(report, origin: origin),
        ReportShareOutcome.busy,
      );
      expect(files.reports, hasLength(1));
      await pumpEventQueue();
      expect(count, 1);
      pending.complete(result);
      expect(await first, ReportShareOutcome.targetSelected);
      expect(
        await subject.share(report, origin: origin),
        ReportShareOutcome.targetSelected,
      );
      expect(count, 2);
    },
  );

  for (final invalidOrigin in [
    Rect.zero,
    const Rect.fromLTWH(double.infinity, 0, 10, 10),
  ]) {
    test(
      'rejects an invalid anchor before staging or sharing: $invalidOrigin',
      () async {
        await expectLater(
          service.share(report, origin: invalidOrigin),
          throwsArgumentError,
        );
        expect(files.reports, isEmpty);
        expect(calls, isEmpty);
      },
    );
  }
  test('empty PDF never reaches a platform operation', () async {
    await expectLater(
      service.share(PdfReport(bytes: const []), origin: origin),
      throwsArgumentError,
    );
    expect(files.reports, isEmpty);
    expect(calls, isEmpty);
  });

  test(
    'platform failures propagate and release the guard for manual retry',
    () async {
      var fails = true;
      final subject = SharePlusReportSharing(
        files: files,
        platform: TargetPlatform.android,
        invoke: (_) async {
          if (fails) {
            throw PlatformException(
              code: 'unavailable',
              message: 'private target',
            );
          }
          return result;
        },
      );
      await expectLater(
        subject.share(report, origin: origin),
        throwsA(isA<PlatformException>()),
      );
      fails = false;
      expect(
        await subject.share(report, origin: origin),
        ReportShareOutcome.targetSelected,
      );
    },
  );
  test(
    'an explicitly unsupported plugin operation maps to unsupported',
    () async {
      final subject = SharePlusReportSharing(
        files: files,
        platform: TargetPlatform.android,
        invoke: (_) async => throw UnsupportedError('file sharing unavailable'),
      );
      expect(
        await subject.share(report, origin: origin),
        ReportShareOutcome.unsupported,
      );
    },
  );
}
