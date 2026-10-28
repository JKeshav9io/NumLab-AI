import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/data/datasources/history_remote_data_source.dart';
import 'package:numlab_frontend/features/history/data/models/models.dart';
import 'package:numlab_frontend/features/history/data/repositories/history_repository_impl.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';

class MockHistoryRemoteDataSource extends Fake
    implements HistoryRemoteDataSource {
  Future<PaginatedHistoryModel> Function({int limit, int offset})? onGetHistory;
  Future<HistoryRunModel> Function(String runId)? onGetRunById;

  @override
  Future<PaginatedHistoryModel> getHistory({int limit = 20, int offset = 0}) {
    return onGetHistory!(limit: limit, offset: offset);
  }

  @override
  Future<HistoryRunModel> getRunById(String runId) {
    return onGetRunById!(runId);
  }
}

void main() {
  late MockHistoryRemoteDataSource mockDataSource;
  late HistoryRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockHistoryRemoteDataSource();
    repository = HistoryRepositoryImpl(remoteDataSource: mockDataSource);
  });

  final testHistory = PaginatedHistoryModel(
    runs: [
      HistoryRunModel(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: DateTime.parse('2026-09-30T10:00:00.000Z'),
      ),
    ],
    pagination: const PaginationModel(
      total: 1,
      limit: 20,
      offset: 0,
      hasMore: false,
    ),
  );

  final testRun = HistoryRunModel(
    id: 'run-detail-1',
    method: 'ode/euler',
    createdAt: DateTime.parse('2026-09-30T11:00:00.000Z'),
  );

  group('HistoryRepositoryImpl - getHistory', () {
    test(
      'returns Right(PaginatedHistoryModel) when datasource succeeds',
      () async {
        mockDataSource.onGetHistory = ({int limit = 20, int offset = 0}) async {
          return testHistory;
        };
        final result = await repository.getHistory(limit: 10, offset: 5);

        expect(
          result,
          Right<Failure, PaginatedHistory>(testHistory.toEntity()),
        );
      },
    );

    test('returns Left(AuthFailure) on 401 UNAUTHORIZED from Dio', () async {
      mockDataSource.onGetHistory = ({int limit = 20, int offset = 0}) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/users/me/history'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/v1/users/me/history'),
            statusCode: 401,
            data: <String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'UNAUTHORIZED',
                'message': 'Authentication required',
              },
            },
          ),
          type: DioExceptionType.badResponse,
        );
      };

      final result = await repository.getHistory();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Authentication required');
        },
        (_) => fail('Expected Left(AuthFailure)'),
      );
    });

    test('returns Left(NetworkFailure) on Dio network timeout', () async {
      mockDataSource.onGetHistory = ({int limit = 20, int offset = 0}) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/users/me/history'),
          type: DioExceptionType.connectionTimeout,
        );
      };

      final result = await repository.getHistory();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('Expected Left(NetworkFailure)'),
      );
    });
  });

  group('HistoryRepositoryImpl - getRunById', () {
    test('returns Right(HistoryRunModel) when datasource succeeds', () async {
      mockDataSource.onGetRunById = (runId) async {
        return testRun;
      };

      final result = await repository.getRunById('run-detail-1');

      expect(result, Right<Failure, HistoryRun>(testRun.toEntity()));
    });

    test(
      'returns Left(ServerFailure) with 404 NOT_FOUND on non-existent run',
      () async {
        mockDataSource.onGetRunById = (runId) async {
          throw DioException(
            requestOptions: RequestOptions(
              path: '/api/v1/users/me/history/$runId',
            ),
            response: Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(
                path: '/api/v1/users/me/history/$runId',
              ),
              statusCode: 404,
              data: <String, dynamic>{
                'success': false,
                'error': <String, dynamic>{
                  'code': 'NOT_FOUND',
                  'message': 'Solver run not found',
                },
              },
            ),
            type: DioExceptionType.badResponse,
          );
        };

        final result = await repository.getRunById('nonexistent-uuid');

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect((failure as ServerFailure).statusCode, 404);
            expect(failure.code, 'NOT_FOUND');
          },
          (_) => fail('Expected Left(ServerFailure)'),
        );
      },
    );

    test('returns Left(ServerFailure) on unhandled exception', () async {
      mockDataSource.onGetRunById = (runId) async {
        throw Exception('Unexpected local exception');
      };

      final result = await repository.getRunById('some-id');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Unexpected local exception'));
        },
        (_) => fail('Expected Left(ServerFailure)'),
      );
    });
  });
}
