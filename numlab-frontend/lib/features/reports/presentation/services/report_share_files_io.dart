import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_share_files.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

ReportShareFiles createReportShareFiles() => CachedReportShareFiles();

/// Native share targets need a file. Retain it after handoff so targets can read
/// asynchronously; prune only marked, app-owned staging folders on later shares.
class CachedReportShareFiles implements ReportShareFiles {
  CachedReportShareFiles({
    FileSystem? fileSystem,
    Future<String> Function()? temporaryPath,
    DateTime Function()? now,
  }) : _fs = fileSystem ?? const LocalFileSystem(),
       _temporaryPath = temporaryPath ?? _defaultTemporaryPath,
       _now = now ?? DateTime.now;

  static const directoryName = 'numlab-report-shares';
  static const markerName = '.numlab-share-created';
  static const retention = Duration(days: 1);
  final FileSystem _fs;
  final Future<String> Function() _temporaryPath;
  final DateTime Function() _now;

  static Future<String> _defaultTemporaryPath() async =>
      (await getTemporaryDirectory()).path;

  @override
  Future<XFile> prepare(PdfReport report, String filename) async {
    if (filename != FilePickerReportDelivery.suggestedFilename(filename)) {
      throw ArgumentError('A safe PDF filename is required.');
    }
    final root = _fs.directory(
      _fs.path.join(await _temporaryPath(), directoryName),
    );
    if (await _fs.type(root.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FileSystemException('Invalid report share cache.');
    }
    await root.create(recursive: true);
    await _prune(root);
    final directory = await root.createTemp('pdf-');
    await directory
        .childFile(markerName)
        .writeAsString(_now().toUtc().toIso8601String());
    final file = directory.childFile(filename);
    await file.writeAsBytes(report.bytes, flush: true);
    return XFile(file.path, mimeType: 'application/pdf');
  }

  Future<void> _prune(Directory root) async {
    try {
      await for (final candidate in root.list(followLinks: false)) {
        if (candidate is! Directory ||
            !candidate.basename.startsWith('pdf-') ||
            !_fs.path.isWithin(root.absolute.path, candidate.absolute.path)) {
          continue;
        }
        try {
          final marker = candidate.childFile(markerName);
          if (await _fs.type(marker.path, followLinks: false) !=
              FileSystemEntityType.file) {
            continue;
          }
          final created = DateTime.tryParse(await marker.readAsString());
          if (created != null && _now().difference(created) > retention) {
            await candidate.delete(recursive: true);
          }
        } on FileSystemException catch (_) {
          // A stale file may still be in use. Leave it for a later cache pass.
        }
      }
    } on FileSystemException catch (_) {
      // Cache maintenance must not prevent preparing the current report.
    }
  }
}
