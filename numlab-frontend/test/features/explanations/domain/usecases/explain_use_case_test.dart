import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/entities.dart';
import 'package:numlab_frontend/features/explanations/domain/repositories/explanation_repository.dart';
import 'package:numlab_frontend/features/explanations/domain/usecases/explain_use_case.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';

class MockExplanationRepository extends Fake implements ExplanationRepository {
  Future<Either<Failure, AiExplanationResult>> Function({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  })?
  onExplain;

  @override
  Future<Either<Failure, AiExplanationResult>> explain({
    required SolverResult solverResult,
    String? focus,
    bool? includeGraphSummary,
  }) {
    return onExplain!(
      solverResult: solverResult,
      focus: focus,
      includeGraphSummary: includeGraphSummary,
    );
  }
}

void main() {
  late MockExplanationRepository mockRepository;
  late ExplainUseCase useCase;

  const testSolverResult = SolverResult(
    method: 'Bisection Method',
    status: 'converged',
    input: {
      'equation': 'x^2 - 4',
      'lowerBound': 0,
      'upperBound': 3,
    },
    iterations: [
      {'iteration': 1, 'c': 1.5, 'fC': -1.75},
      {'iteration': 2, 'c': 2.25, 'fC': 1.06},
    ],
    finalAnswer: {
      'root': 2.0,
      'converged': true,
    },
    executionTimeMs: 4,
    requestId: 'req-solve-123',
    timestamp: '2026-10-15T22:00:00.000Z',
  );

  const testExplanationResult = AiExplanationResult(
    explanation:
        'The Bisection method converged to root 2.0 within 2 iterations.',
    model: 'gpt-4o-mini',
    method: 'Bisection Method',
    status: 'converged',
    totalTokens: 120,
    requestId: 'req-explain-456',
    timestamp: '2026-10-15T22:00:05.000Z',
  );

  setUp(() {
    mockRepository = MockExplanationRepository();
    useCase = ExplainUseCase(mockRepository);
  });

  group('ExplainUseCase - Successful execution and parameter forwarding', () {
    test(
      'forwards valid parameters to repository and returns Right(AiExplanationResult)',
      () async {
        SolverResult? capturedResult;
        String? capturedFocus;
        bool? capturedIncludeGraphSummary;

        mockRepository.onExplain =
            ({
              required solverResult,
              focus,
              includeGraphSummary,
            }) async {
              capturedResult = solverResult;
              capturedFocus = focus;
              capturedIncludeGraphSummary = includeGraphSummary;
              return const Right(testExplanationResult);
            };

        final result = await useCase(
          solverResult: testSolverResult,
          focus: 'steps',
          includeGraphSummary: true,
        );

        expect(capturedResult, testSolverResult);
        expect(capturedFocus, 'steps');
        expect(capturedIncludeGraphSummary, isTrue);
        expect(
          result,
          const Right<Failure, AiExplanationResult>(testExplanationResult),
        );
      },
    );

    test('forwards null focus and omitted graph summary correctly', () async {
      String? capturedFocus;
      bool? capturedIncludeGraphSummary;

      mockRepository.onExplain =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) async {
            capturedFocus = focus;
            capturedIncludeGraphSummary = includeGraphSummary;
            return const Right(testExplanationResult);
          };

      final result = await useCase(solverResult: testSolverResult);

      expect(capturedFocus, isNull);
      expect(capturedIncludeGraphSummary, isNull);
      expect(result.isRight(), isTrue);
    });

    test('normalizes uppercase and padded focus mode values', () async {
      String? capturedFocus;

      mockRepository.onExplain =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) async {
            capturedFocus = focus;
            return const Right(testExplanationResult);
          };

      final result = await useCase(
        solverResult: testSolverResult,
        focus: '  SUMMARY  ',
      );

      expect(capturedFocus, 'summary');
      expect(result.isRight(), isTrue);
    });

    test(
      'supports all backend focus modes: summary, steps, warnings, lab-report',
      () async {
        for (final mode in ExplainUseCase.supportedFocusModes) {
          String? capturedFocus;
          mockRepository.onExplain =
              ({
                required solverResult,
                focus,
                includeGraphSummary,
              }) async {
                capturedFocus = focus;
                return const Right(testExplanationResult);
              };

          final result = await useCase(
            solverResult: testSolverResult,
            focus: mode,
          );

          expect(capturedFocus, mode);
          expect(result.isRight(), isTrue);
        }
      },
    );
  });

  group('ExplainUseCase - Client-side Input Validation', () {
    test(
      'returns ValidationFailure when solverResult method is empty or whitespace',
      () async {
        const invalidResult = SolverResult(
          method: '   ',
          finalAnswer: {'root': 1.0},
        );

        final result = await useCase(solverResult: invalidResult);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          final valFailure = failure as ValidationFailure;
          expect(
            valFailure.fieldErrors.any((e) => e.field == 'method'),
            isTrue,
          );
        }, (_) => fail('Expected Left(ValidationFailure)'));
      },
    );

    test(
      'returns ValidationFailure when solverResult finalAnswer is empty',
      () async {
        const invalidResult = SolverResult(
          method: 'Bisection Method',
          finalAnswer: {},
        );

        final result = await useCase(solverResult: invalidResult);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          final valFailure = failure as ValidationFailure;
          expect(
            valFailure.fieldErrors.any((e) => e.field == 'finalAnswer'),
            isTrue,
          );
        }, (_) => fail('Expected Left(ValidationFailure)'));
      },
    );

    test('returns ValidationFailure for unsupported focus mode', () async {
      final result = await useCase(
        solverResult: testSolverResult,
        focus: 'unsupported-mode',
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure, isA<ValidationFailure>());
        final valFailure = failure as ValidationFailure;
        expect(valFailure.fieldErrors.any((e) => e.field == 'focus'), isTrue);
        expect(valFailure.message, contains('unsupported-mode'));
      }, (_) => fail('Expected Left(ValidationFailure)'));
    });

    test(
      'returns ValidationFailure when iterations exceed max 200 items',
      () async {
        final excessiveIterations = List.generate(
          201,
          (i) => {'iteration': i + 1, 'x': i * 0.1},
        );
        final invalidResult = SolverResult(
          method: 'Newton-Raphson',
          iterations: excessiveIterations,
          finalAnswer: const {'root': 2.0},
        );

        final result = await useCase(solverResult: invalidResult);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          final valFailure = failure as ValidationFailure;
          expect(
            valFailure.fieldErrors.any((e) => e.field == 'iterations'),
            isTrue,
          );
        }, (_) => fail('Expected Left(ValidationFailure)'));
      },
    );

    test(
      'returns ValidationFailure when warnings exceed max 50 items',
      () async {
        final excessiveWarnings = List.generate(
          51,
          (i) => 'Warning #$i: Matrix conditioning is poor',
        );
        final invalidResult = SolverResult(
          method: 'Gauss-Seidel',
          warnings: excessiveWarnings,
          finalAnswer: const {
            'solution': [1, 2],
          },
        );

        final result = await useCase(solverResult: invalidResult);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          final valFailure = failure as ValidationFailure;
          expect(
            valFailure.fieldErrors.any((e) => e.field == 'warnings'),
            isTrue,
          );
        }, (_) => fail('Expected Left(ValidationFailure)'));
      },
    );

    test(
      'returns ValidationFailure when graphData list exceeds max 500 points',
      () async {
        final excessiveGraph = List.generate(
          501,
          (i) => {'x': i, 'y': i * 2},
        );
        final invalidResult = SolverResult(
          method: 'Euler Method',
          graphData: excessiveGraph,
          finalAnswer: const {'y': 10.0},
        );

        final result = await useCase(solverResult: invalidResult);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          final valFailure = failure as ValidationFailure;
          expect(
            valFailure.fieldErrors.any((e) => e.field == 'graphData'),
            isTrue,
          );
        }, (_) => fail('Expected Left(ValidationFailure)'));
      },
    );

    test(
      'returns ValidationFailure when graphData nested list exceeds max 500 points',
      () async {
        final excessiveGraphMap = {
          'curve': List.generate(501, (i) => {'x': i, 'y': i}),
        };
        final invalidResult = SolverResult(
          method: 'Runge-Kutta 4',
          graphData: excessiveGraphMap,
          finalAnswer: const {'y': 5.0},
        );

        final result = await useCase(solverResult: invalidResult);

        expect(result.isLeft(), isTrue);
        result.fold((failure) {
          expect(failure, isA<ValidationFailure>());
          final valFailure = failure as ValidationFailure;
          expect(
            valFailure.fieldErrors.any((e) => e.field == 'graphData'),
            isTrue,
          );
        }, (_) => fail('Expected Left(ValidationFailure)'));
      },
    );
  });

  group('ExplainUseCase - Repository Failure Propagation', () {
    test('propagates ServerFailure (502 AI_SERVICE_ERROR) unchanged', () async {
      const failure = ServerFailure(
        message: 'AI Provider timeout or error',
        statusCode: 502,
        code: 'AI_SERVICE_ERROR',
      );

      mockRepository.onExplain =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) async {
            return const Left(failure);
          };

      final result = await useCase(solverResult: testSolverResult);

      expect(result, const Left<Failure, AiExplanationResult>(failure));
    });

    test('propagates RateLimitFailure (429) unchanged', () async {
      const failure = RateLimitFailure(
        message:
            'AI explanation rate limit reached. Please wait before retrying.',
        retryAfterSeconds: 60,
      );

      mockRepository.onExplain =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) async {
            return const Left(failure);
          };

      final result = await useCase(solverResult: testSolverResult);

      expect(result, const Left<Failure, AiExplanationResult>(failure));
    });

    test('propagates NetworkFailure unchanged', () async {
      const failure = NetworkFailure(
        message: 'Unable to connect to server',
      );

      mockRepository.onExplain =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) async {
            return const Left(failure);
          };

      final result = await useCase(solverResult: testSolverResult);

      expect(result, const Left<Failure, AiExplanationResult>(failure));
    });

    test('propagates AuthFailure unchanged', () async {
      const failure = AuthFailure(
        message: 'Invalid session token',
      );

      mockRepository.onExplain =
          ({
            required solverResult,
            focus,
            includeGraphSummary,
          }) async {
            return const Left(failure);
          };

      final result = await useCase(solverResult: testSolverResult);

      expect(result, const Left<Failure, AiExplanationResult>(failure));
    });
  });
}
