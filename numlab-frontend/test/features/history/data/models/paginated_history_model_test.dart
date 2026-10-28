import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/history/data/models/history_run_model.dart';
import 'package:numlab_frontend/features/history/data/models/paginated_history_model.dart';
import 'package:numlab_frontend/features/history/data/models/pagination_model.dart';

void main() {
  group('PaginatedHistoryModel', () {
    final validJson = <String, dynamic>{
      'runs': <dynamic>[
        <String, dynamic>{
          'id': 'run-1',
          'method': 'root/bisection',
          'createdAt': '2026-09-30T10:00:00.000Z',
          'outputPayload': <String, dynamic>{'status': 'converged'},
        },
        <String, dynamic>{
          'id': 'run-2',
          'method': 'root/newton',
          'createdAt': '2026-09-30T11:00:00.000Z',
          'outputPayload': <String, dynamic>{'status': 'converged'},
        },
      ],
      'pagination': <String, dynamic>{
        'total': 2,
        'limit': 20,
        'offset': 0,
        'hasMore': false,
      },
    };

    test('parses inner data dictionary successfully', () {
      final model = PaginatedHistoryModel.fromJson(validJson);

      expect(model.runs.length, 2);
      expect(model.runs[0].id, 'run-1');
      expect(model.runs[1].id, 'run-2');
      expect(model.pagination.total, 2);
      expect(model.pagination.hasMore, isFalse);
    });

    test('parses top-level response envelope containing { data: { ... } }', () {
      final envelope = <String, dynamic>{
        'success': true,
        'data': validJson,
        'meta': <String, dynamic>{'requestId': 'req-123'},
      };

      final model = PaginatedHistoryModel.fromJson(envelope);

      expect(model.runs.length, 2);
      expect(model.pagination.total, 2);
    });

    test('handles empty runs list gracefully', () {
      final emptyJson = <String, dynamic>{
        'runs': <dynamic>[],
        'pagination': <String, dynamic>{
          'total': 0,
          'limit': 20,
          'offset': 0,
          'hasMore': false,
        },
      };

      final model = PaginatedHistoryModel.fromJson(emptyJson);

      expect(model.runs, isEmpty);
      expect(model.pagination.total, 0);
      expect(model.pagination.hasMore, isFalse);
    });

    test('handles missing runs and pagination with safe defaults', () {
      final model = PaginatedHistoryModel.fromJson(const <String, dynamic>{});

      expect(model.runs, isEmpty);
      expect(model.pagination.total, 0);
      expect(model.pagination.limit, 20);
      expect(model.pagination.offset, 0);
      expect(model.pagination.hasMore, isFalse);
    });

    test('serializes to JSON map', () {
      final model = PaginatedHistoryModel(
        runs: [
          HistoryRunModel(
            id: 'run-test',
            method: 'ode/rk4',
            createdAt: DateTime.parse('2026-09-30T15:00:00.000Z'),
          ),
        ],
        pagination: const PaginationModel(
          total: 1,
          limit: 20,
          offset: 0,
          hasMore: false,
        ),
      );

      final json = model.toJson();

      expect((json['runs'] as List<dynamic>).length, 1);
      expect((json['pagination'] as Map<String, dynamic>)['total'], 1);
    });

    test('supports value equality via Equatable', () {
      const pagination = PaginationModel(
        total: 1,
        limit: 20,
        offset: 0,
        hasMore: false,
      );
      const model1 = PaginatedHistoryModel(
        runs: [],
        pagination: pagination,
      );
      const model2 = PaginatedHistoryModel(
        runs: [],
        pagination: pagination,
      );

      expect(model1, equals(model2));
    });
  });
}
