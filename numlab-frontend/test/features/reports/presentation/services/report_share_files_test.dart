import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_share_files.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_share_files_io.dart';

void main() {
  final report = PdfReport(
    bytes: const [0, 255, 37, 80],
    filename: 'server.pdf',
  );
  late MemoryFileSystem fs;
  late DateTime now;
  late CachedReportShareFiles files;
  setUp(() {
    fs = MemoryFileSystem();
    now = DateTime.utc(2026, 10, 28);
    files = CachedReportShareFiles(
      fileSystem: fs,
      temporaryPath: () async => '/cache',
      now: () => now,
    );
  });
  Directory getRoot() =>
      fs.directory('/cache/${CachedReportShareFiles.directoryName}');
  Future<Directory> staged(String name, String? marker) async {
    final folder = await getRoot().childDirectory(name).create(recursive: true);
    if (marker != null) {
      await folder
          .childFile(CachedReportShareFiles.markerName)
          .writeAsString(marker);
    }
    await folder.childFile('keep.pdf').writeAsBytes(report.bytes);
    return folder;
  }

  test(
    'stages exact bytes in the app cache with PDF MIME and a safe filename',
    () async {
      final value = await files.prepare(report, 'server.pdf');
      expect(fs.path.isWithin(getRoot().absolute.path, value.path), isTrue);
      expect(fs.path.basename(value.path), 'server.pdf');
      expect(await fs.file(value.path).readAsBytes(), report.bytes);
      expect(value.mimeType, 'application/pdf');
      expect(
        await fs
            .file(value.path)
            .parent
            .childFile(CachedReportShareFiles.markerName)
            .readAsString(),
        now.toIso8601String(),
      );
      expect(report.filename, 'server.pdf');
    },
  );
  test(
    'each attempt gets an isolated file; recent targets retain readable files',
    () async {
      final first = await files.prepare(report, 'server.pdf');
      final next = await files.prepare(report, 'server.pdf');
      expect(first.path, isNot(next.path));
      expect(fs.file(first.path).existsSync(), isTrue);
      expect(fs.file(next.path).existsSync(), isTrue);
    },
  );
  test(
    'a later share prunes marked staging directories older than one day only',
    () async {
      final old = await staged('pdf-expired', now.toIso8601String());
      now = now.add(const Duration(hours: 25));
      final current = await files.prepare(report, 'server.pdf');
      expect(old.existsSync(), isFalse);
      expect(fs.file(current.path).existsSync(), isTrue);
    },
  );
  test(
    'files at the retention boundary stay available to share targets',
    () async {
      final old = await files.prepare(report, 'server.pdf');
      now = now.add(CachedReportShareFiles.retention);
      await files.prepare(report, 'server.pdf');
      expect(fs.file(old.path).existsSync(), isTrue);
    },
  );
  for (final marker in <String?>[
    null,
    'not a timestamp',
    '2099-01-01T00:00:00Z',
  ]) {
    test(
      'unmarked, invalid and future cache records are preserved: $marker',
      () async {
        final kept = await staged('pdf-unowned', marker);
        await files.prepare(report, 'server.pdf');
        expect(kept.existsSync(), isTrue);
      },
    );
  }
  test(
    'pruning does not touch other folders, loose files or files outside the cache',
    () async {
      final other = await staged('another-feature', '2000-01-01T00:00:00Z');
      final loose = await getRoot().childFile('unrelated.pdf').writeAsBytes([
        5,
      ]);
      final outside = await fs
          .file('/outside/report.pdf')
          .create(recursive: true);
      await files.prepare(report, 'server.pdf');
      expect(other.existsSync(), isTrue);
      expect(loose.existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
    },
  );
  test('cleanup skips directory links rather than following them', () async {
    final outside = await fs.directory('/outside').create();
    await outside
        .childFile(CachedReportShareFiles.markerName)
        .writeAsString('2000-01-01T00:00:00Z');
    await getRoot().create(recursive: true);
    final link = await getRoot().childLink('pdf-linked').create(outside.path);
    await files.prepare(report, 'server.pdf');
    expect(outside.existsSync(), isTrue);
    expect(link.existsSync(), isTrue);
  });
  test(
    'a linked cache root is rejected without modifying its target',
    () async {
      await fs.directory('/outside').create();
      await fs.directory('/cache').create();
      await fs.link(getRoot().path).create('/outside');
      await expectLater(
        files.prepare(report, 'server.pdf'),
        throwsA(isA<FileSystemException>()),
      );
      expect(fs.directory('/outside').listSync(), isEmpty);
    },
  );
  test(
    'marker links cannot authorize deletion of an unowned directory',
    () async {
      final folder = await staged('pdf-unowned', null);
      final outside = await fs
          .file('/stamp')
          .writeAsString('2000-01-01T00:00:00Z');
      await folder
          .childLink(CachedReportShareFiles.markerName)
          .create(outside.path);
      await files.prepare(report, 'server.pdf');
      expect(folder.existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
    },
  );
  for (final unsafe in ['../outside.pdf', r'..\outside.pdf', 'CON.pdf']) {
    test(
      'rejects unsafe direct filenames before creating files: $unsafe',
      () async {
        await expectLater(files.prepare(report, unsafe), throwsArgumentError);
        expect(fs.directory('/cache').existsSync(), isFalse);
      },
    );
  }
  test(
    'Windows paths are contained in the intended application cache',
    () async {
      final windows = MemoryFileSystem(style: FileSystemStyle.windows);
      final cache = CachedReportShareFiles(
        fileSystem: windows,
        temporaryPath: () async => r'C:\cache',
        now: () => now,
      );
      final value = await cache.prepare(report, 'server.pdf');
      expect(
        windows.path.isWithin(r'C:\cache\numlab-report-shares', value.path),
        isTrue,
      );
      expect(await windows.file(value.path).readAsBytes(), report.bytes);
    },
  );
  test(
    'a temporary-directory failure remains a recoverable share error',
    () async {
      final unavailable = CachedReportShareFiles(
        fileSystem: fs,
        temporaryPath: () async =>
            throw const FileSystemException('private directory'),
      );
      await expectLater(
        unavailable.prepare(report, 'server.pdf'),
        throwsA(isA<FileSystemException>()),
      );
      expect(fs.directory('/cache').existsSync(), isFalse);
    },
  );
  test(
    'web representation keeps PDF bytes in memory without native staging',
    () async {
      final value = await const MemoryReportShareFiles().prepare(
        report,
        'server.pdf',
      );
      expect(await value.readAsBytes(), report.bytes);
      expect(value.mimeType, 'application/pdf');
      expect(fs.directory('/cache').existsSync(), isFalse);
    },
  );
}
