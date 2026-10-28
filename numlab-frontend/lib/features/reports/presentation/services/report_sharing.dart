import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:numlab_frontend/features/reports/domain/entities/pdf_report.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_delivery.dart';
import 'package:numlab_frontend/features/reports/presentation/services/report_share_files.dart';
import 'package:share_plus/share_plus.dart';

enum ReportShareOutcome {
  targetSelected,
  cancelled,
  unconfirmed,
  unsupported,
  busy,
}

/// Shares an already-generated PDF without access to the report repository.
// ignore: one_member_abstracts
abstract interface class ReportSharing {
  Future<ReportShareOutcome> share(PdfReport report, {required Rect origin});
}

class SharePlusReportSharing implements ReportSharing {
  SharePlusReportSharing({
    ReportShareFiles? files,
    Future<ShareResult> Function(ShareParams)? invoke,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) : _files = files ?? createReportShareFiles(),
       _invoke = invoke ?? SharePlus.instance.share,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb;

  final ReportShareFiles _files;
  final Future<ShareResult> Function(ShareParams) _invoke;
  final TargetPlatform _platform;
  final bool _isWeb;
  bool _pending = false;

  @override
  Future<ReportShareOutcome> share(
    PdfReport report, {
    required Rect origin,
  }) async {
    if (!_isWeb &&
        (_platform == TargetPlatform.linux ||
            _platform == TargetPlatform.fuchsia)) {
      return ReportShareOutcome.unsupported;
    }
    if (_pending) return ReportShareOutcome.busy;
    if (report.bytes.isEmpty || origin.isEmpty || !origin.isFinite) {
      throw ArgumentError('PDF data and a valid share anchor are required.');
    }
    _pending = true;
    try {
      final filename = FilePickerReportDelivery.suggestedFilename(
        report.filename,
      );
      final file = await _files.prepare(report, filename);
      final result = await _invoke(
        ShareParams(
          files: [file],
          fileNameOverrides: [filename],
          title: 'NumLab PDF report',
          subject: 'NumLab PDF report',
          sharePositionOrigin: origin,
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ReportShareOutcome.targetSelected,
        ShareResultStatus.dismissed => ReportShareOutcome.cancelled,
        ShareResultStatus.unavailable => ReportShareOutcome.unconfirmed,
      };
    } on Object catch (error) {
      if (error is UnsupportedError) return ReportShareOutcome.unsupported;
      rethrow;
    } finally {
      _pending = false;
    }
  }
}
