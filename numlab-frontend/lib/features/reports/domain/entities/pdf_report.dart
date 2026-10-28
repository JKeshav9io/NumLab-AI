import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Minimal repository result: in-memory PDF bytes and optional server filename.
/// No storage location, download URL, or generated report ID is supplied by API.
class PdfReport extends Equatable {
  PdfReport({required List<int> bytes, this.filename})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final String? filename;

  @override
  List<Object?> get props => [bytes, filename];
}
