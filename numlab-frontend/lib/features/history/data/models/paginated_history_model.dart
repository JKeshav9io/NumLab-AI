import 'package:numlab_frontend/features/history/data/models/history_run_model.dart';
import 'package:numlab_frontend/features/history/data/models/pagination_model.dart';
import 'package:numlab_frontend/features/history/domain/entities/paginated_history.dart';

/// Data model representing a paginated collection of historical solver runs.
class PaginatedHistoryModel extends PaginatedHistory {
  const PaginatedHistoryModel({
    required List<HistoryRunModel> runs,
    required PaginationModel pagination,
  }) : _runs = runs,
       _pagination = pagination,
       super(runs: runs, pagination: pagination);

  /// Parses [PaginatedHistoryModel] from JSON map.
  factory PaginatedHistoryModel.fromJson(Map<String, dynamic> json) {
    final data =
        json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json.containsKey('data') && json['data'] is Map
              ? Map<String, dynamic>.from(json['data'] as Map)
              : json);

    final rawRuns = data['runs'];
    final runs = rawRuns is List
        ? rawRuns
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => HistoryRunModel.fromJson(
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
                ),
              )
              .toList(growable: false)
        : const <HistoryRunModel>[];

    final rawPagination = data['pagination'];
    final pagination = rawPagination is Map<String, dynamic>
        ? PaginationModel.fromJson(rawPagination)
        : (rawPagination is Map
              ? PaginationModel.fromJson(
                  Map<String, dynamic>.from(rawPagination),
                )
              : const PaginationModel(
                  total: 0,
                  limit: 20,
                  offset: 0,
                  hasMore: false,
                ));

    return PaginatedHistoryModel(
      runs: runs,
      pagination: pagination,
    );
  }

  /// Constructs a [PaginatedHistoryModel] from a domain [PaginatedHistory] entity.
  factory PaginatedHistoryModel.fromEntity(PaginatedHistory entity) {
    return PaginatedHistoryModel(
      runs: entity.runs
          .map(
            (e) => e is HistoryRunModel ? e : HistoryRunModel.fromEntity(e),
          )
          .toList(growable: false),
      pagination: entity.pagination is PaginationModel
          ? entity.pagination as PaginationModel
          : PaginationModel.fromEntity(entity.pagination),
    );
  }

  final List<HistoryRunModel> _runs;
  final PaginationModel _pagination;

  @override
  List<HistoryRunModel> get runs => _runs;

  @override
  PaginationModel get pagination => _pagination;

  /// Converts this data model to a domain [PaginatedHistory] entity.
  PaginatedHistory toEntity() {
    return PaginatedHistory(
      runs: runs.map((e) => e.toEntity()).toList(growable: false),
      pagination: pagination.toEntity(),
    );
  }

  /// Serializes to JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'runs': _runs.map((e) => e.toJson()).toList(),
      'pagination': _pagination.toJson(),
    };
  }
}
