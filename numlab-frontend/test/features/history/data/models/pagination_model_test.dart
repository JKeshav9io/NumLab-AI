import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/history/data/models/pagination_model.dart';

void main() {
  group('PaginationModel', () {
    const validJson = <String, dynamic>{
      'total': 42,
      'limit': 20,
      'offset': 0,
      'hasMore': true,
    };

    test('parses standard backend pagination JSON successfully', () {
      final model = PaginationModel.fromJson(validJson);

      expect(model.total, 42);
      expect(model.limit, 20);
      expect(model.offset, 0);
      expect(model.hasMore, isTrue);
    });

    test('handles missing fields with safe defaults', () {
      final model = PaginationModel.fromJson(const <String, dynamic>{});

      expect(model.total, 0);
      expect(model.limit, 20);
      expect(model.offset, 0);
      expect(model.hasMore, isFalse);
    });

    test('calculates hasMore when omitted based on offset + limit < total', () {
      final modelWithMore = PaginationModel.fromJson(const <String, dynamic>{
        'total': 50,
        'limit': 20,
        'offset': 20,
      });
      expect(modelWithMore.hasMore, isTrue);

      final modelAtEnd = PaginationModel.fromJson(const <String, dynamic>{
        'total': 40,
        'limit': 20,
        'offset': 20,
      });
      expect(modelAtEnd.hasMore, isFalse);
    });

    test('serializes to JSON map matching backend contract', () {
      const model = PaginationModel(
        total: 100,
        limit: 25,
        offset: 50,
        hasMore: true,
      );

      final json = model.toJson();

      expect(json, <String, dynamic>{
        'total': 100,
        'limit': 25,
        'offset': 50,
        'hasMore': true,
      });
    });

    test('supports value equality via Equatable', () {
      const model1 = PaginationModel(
        total: 10,
        limit: 5,
        offset: 0,
        hasMore: true,
      );
      const model2 = PaginationModel(
        total: 10,
        limit: 5,
        offset: 0,
        hasMore: true,
      );
      const model3 = PaginationModel(
        total: 15,
        limit: 5,
        offset: 0,
        hasMore: true,
      );

      expect(model1, equals(model2));
      expect(model1, isNot(equals(model3)));
    });
  });
}
