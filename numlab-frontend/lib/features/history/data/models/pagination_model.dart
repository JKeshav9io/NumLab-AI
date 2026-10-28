import 'package:numlab_frontend/features/history/domain/entities/pagination.dart';

/// Data model representing pagination metadata in NumLab AI history responses.
class PaginationModel extends Pagination {
  const PaginationModel({
    required super.total,
    required super.limit,
    required super.offset,
    required super.hasMore,
  });

  /// Parses [PaginationModel] from JSON map.
  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final offset = (json['offset'] as num?)?.toInt() ?? 0;
    final hasMore = json['hasMore'] as bool? ?? (offset + limit < total);

    return PaginationModel(
      total: total,
      limit: limit,
      offset: offset,
      hasMore: hasMore,
    );
  }

  /// Constructs a [PaginationModel] from a domain [Pagination] entity.
  factory PaginationModel.fromEntity(Pagination entity) {
    return PaginationModel(
      total: entity.total,
      limit: entity.limit,
      offset: entity.offset,
      hasMore: entity.hasMore,
    );
  }

  /// Converts this data model to a domain [Pagination] entity.
  Pagination toEntity() {
    return Pagination(
      total: total,
      limit: limit,
      offset: offset,
      hasMore: hasMore,
    );
  }

  /// Serializes to JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total': total,
      'limit': limit,
      'offset': offset,
      'hasMore': hasMore,
    };
  }
}
