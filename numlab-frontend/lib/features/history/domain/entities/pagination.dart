import 'package:equatable/equatable.dart';

/// Domain entity representing pagination metadata for historical records.
class Pagination extends Equatable {
  const Pagination({
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  /// Total count of available historical records.
  final int total;

  /// Number of records requested/returned in this page.
  final int limit;

  /// Starting index offset.
  final int offset;

  /// Whether there are more records beyond this page.
  final bool hasMore;

  @override
  List<Object?> get props => [total, limit, offset, hasMore];
}
