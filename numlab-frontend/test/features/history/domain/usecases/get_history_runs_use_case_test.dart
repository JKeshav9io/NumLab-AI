import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/repositories/history_repository.dart';
import 'package:numlab_frontend/features/history/domain/usecases/get_history_runs_use_case.dart';

class MockHistoryRepository extends Fake implements HistoryRepository {
  Future<Either<Failure, PaginatedHistory>> Function({
    int limit,
    int offset,
  })?
  onGetHistory;

  @override
  Future<Either<Failure, PaginatedHistory>> getHistory({
    int limit = 20,
    int offset = 0,
  }) {
    return onGetHistory!(limit: limit, offset: offset);
  }
}

void main() {
  late MockHistoryRepository mockRepository;
  late GetHistoryRunsUseCase useCase;

  final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');
  final testPaginatedHistory = PaginatedHistory(
    runs: [
      HistoryRun(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: timestamp,
      ),
    ],
    pagination: const Pagination(
      total: 1,
      limit: 20,
      offset: 0,
      hasMore: false,
    ),
  );

  setUp(() {
    mockRepository = MockHistoryRepository();
    useCase = GetHistoryRunsUseCase(mockRepository);
  });

  group('GetHistoryRunsUseCase', () {
    test('forwards default limit (20) and offset (0) to repository', () async {
      int? capturedLimit;
      int? capturedOffset;

      mockRepository.onGetHistory = ({int limit = 20, int offset = 0}) async {
        capturedLimit = limit;
        capturedOffset = offset;
        return Right(testPaginatedHistory);
      };

      final result = await useCase();

      expect(capturedLimit, 20);
      expect(capturedOffset, 0);
      expect(result, Right<Failure, PaginatedHistory>(testPaginatedHistory));
    });

    test('forwards custom limit and offset parameters correctly', () async {
      int? capturedLimit;
      int? capturedOffset;

      mockRepository.onGetHistory = ({int limit = 20, int offset = 0}) async {
        capturedLimit = limit;
        capturedOffset = offset;
        return Right(testPaginatedHistory);
      };

      final result = await useCase(limit: 15, offset: 45);

      expect(capturedLimit, 15);
      expect(capturedOffset, 45);
      expect(result, Right<Failure, PaginatedHistory>(testPaginatedHistory));
    });

    test('propagates Left(AuthFailure) unchanged from repository', () async {
      const failure = AuthFailure(
        message: 'Session token expired',
        code: 'TOKEN_EXPIRED',
      );

      mockRepository.onGetHistory = ({int limit = 20, int offset = 0}) async {
        return const Left(failure);
      };

      final result = await useCase();

      expect(result, const Left<Failure, PaginatedHistory>(failure));
    });

    test('propagates Left(NetworkFailure) unchanged from repository', () async {
      const failure = NetworkFailure(
        message: 'No internet connection',
        code: 'CUSTOM_TIMEOUT',
      );

      mockRepository.onGetHistory = ({int limit = 20, int offset = 0}) async {
        return const Left(failure);
      };

      final result = await useCase();

      expect(result, const Left<Failure, PaginatedHistory>(failure));
    });

    test('propagates Left(ServerFailure) unchanged from repository', () async {
      const failure = ServerFailure(
        message: 'Internal server error',
        statusCode: 500,
        code: 'SERVER_500',
      );

      mockRepository.onGetHistory = ({int limit = 20, int offset = 0}) async {
        return const Left(failure);
      };

      final result = await useCase();

      expect(result, const Left<Failure, PaginatedHistory>(failure));
    });
  });
}
