import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/repositories/history_repository.dart';
import 'package:numlab_frontend/features/history/domain/usecases/get_history_run_by_id_use_case.dart';

class MockHistoryRepository extends Fake implements HistoryRepository {
  Future<Either<Failure, HistoryRun>> Function(String runId)? onGetRunById;

  @override
  Future<Either<Failure, HistoryRun>> getRunById(String runId) {
    return onGetRunById!(runId);
  }
}

void main() {
  late MockHistoryRepository mockRepository;
  late GetHistoryRunByIdUseCase useCase;

  final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');
  final testRun = HistoryRun(
    id: 'run-uuid-42',
    userId: 'user-123',
    method: 'interpolation/lagrange',
    inputPayload: const {
      'points': [
        {'x': 1, 'y': 2},
        {'x': 2, 'y': 5},
      ],
      'targetX': 1.5,
    },
    outputPayload: const {
      'finalAnswer': {'predictedY': 3.5},
      'executionTimeMs': 12,
    },
    createdAt: timestamp,
    aiExplanations: [
      HistoryExplanation(
        id: 'exp-1',
        solverRunId: 'run-uuid-42',
        responseText: 'Lagrange polynomial evaluated smoothly.',
        createdAt: timestamp,
      ),
    ],
  );

  setUp(() {
    mockRepository = MockHistoryRepository();
    useCase = GetHistoryRunByIdUseCase(mockRepository);
  });

  group('GetHistoryRunByIdUseCase', () {
    test(
      'forwards runId to repository and returns Right(HistoryRun)',
      () async {
        String? capturedRunId;

        mockRepository.onGetRunById = (runId) async {
          capturedRunId = runId;
          return Right(testRun);
        };

        final result = await useCase('run-uuid-42');

        expect(capturedRunId, 'run-uuid-42');
        expect(result, Right<Failure, HistoryRun>(testRun));
      },
    );

    test('propagates Left(ServerFailure) 404 NOT_FOUND unchanged', () async {
      const failure = ServerFailure(
        message: 'Solver run not found',
        statusCode: 404,
        code: 'NOT_FOUND',
      );

      mockRepository.onGetRunById = (runId) async {
        return const Left(failure);
      };

      final result = await useCase('non-existent-uuid');

      expect(result, const Left<Failure, HistoryRun>(failure));
    });

    test('propagates Left(AuthFailure) unchanged', () async {
      const failure = AuthFailure(
        message: 'Not authorized',
        code: 'CUSTOM_AUTH_ERROR',
      );

      mockRepository.onGetRunById = (runId) async {
        return const Left(failure);
      };

      final result = await useCase('run-1');

      expect(result, const Left<Failure, HistoryRun>(failure));
    });

    test('propagates Left(NetworkFailure) unchanged', () async {
      const failure = NetworkFailure(
        message: 'Connection timed out',
        code: 'NETWORK_TIMEOUT',
      );

      mockRepository.onGetRunById = (runId) async {
        return const Left(failure);
      };

      final result = await useCase('run-1');

      expect(result, const Left<Failure, HistoryRun>(failure));
    });
  });
}
