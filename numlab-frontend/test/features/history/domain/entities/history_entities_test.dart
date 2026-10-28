import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';

void main() {
  group('Pagination Entity', () {
    test('supports value equality with Equatable', () {
      const page1 = Pagination(
        total: 50,
        limit: 20,
        offset: 0,
        hasMore: true,
      );
      const page2 = Pagination(
        total: 50,
        limit: 20,
        offset: 0,
        hasMore: true,
      );

      expect(page1, equals(page2));
      expect(page1.hashCode, equals(page2.hashCode));
    });

    test('different field values are not equal', () {
      const base = Pagination(
        total: 50,
        limit: 20,
        offset: 0,
        hasMore: true,
      );

      expect(
        base,
        isNot(
          equals(
            const Pagination(
              total: 51,
              limit: 20,
              offset: 0,
              hasMore: true,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const Pagination(
              total: 50,
              limit: 10,
              offset: 0,
              hasMore: true,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const Pagination(
              total: 50,
              limit: 20,
              offset: 10,
              hasMore: true,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            const Pagination(
              total: 50,
              limit: 20,
              offset: 0,
              hasMore: false,
            ),
          ),
        ),
      );
    });

    test('props includes total, limit, offset, and hasMore', () {
      const page = Pagination(
        total: 10,
        limit: 5,
        offset: 2,
        hasMore: true,
      );

      expect(page.props, [10, 5, 2, true]);
    });
  });

  group('HistoryExplanation Entity', () {
    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');
    final expires = DateTime.parse('2026-10-01T10:00:00.000Z');

    test('supports value equality with Equatable', () {
      final exp1 = HistoryExplanation(
        id: 'exp-1',
        solverRunId: 'run-1',
        userId: 'user-1',
        focusMode: 'summary',
        promptHash: 'hash123',
        responseText: 'Bisection converged in 12 iterations.',
        expiresAt: expires,
        createdAt: timestamp,
      );
      final exp2 = HistoryExplanation(
        id: 'exp-1',
        solverRunId: 'run-1',
        userId: 'user-1',
        focusMode: 'summary',
        promptHash: 'hash123',
        responseText: 'Bisection converged in 12 iterations.',
        expiresAt: expires,
        createdAt: timestamp,
      );

      expect(exp1, equals(exp2));
      expect(exp1.hashCode, equals(exp2.hashCode));
    });

    test('supports nullable optional fields', () {
      final exp = HistoryExplanation(
        id: 'exp-minimal',
        responseText: 'Explanation text',
        createdAt: timestamp,
      );

      expect(exp.solverRunId, isNull);
      expect(exp.userId, isNull);
      expect(exp.focusMode, 'steps');
      expect(exp.promptHash, isNull);
      expect(exp.expiresAt, isNull);
      expect(exp.responseText, 'Explanation text');
      expect(exp.createdAt, timestamp);
    });

    test('different field values are not equal', () {
      final base = HistoryExplanation(
        id: 'exp-1',
        responseText: 'Step 1',
        createdAt: timestamp,
      );

      expect(
        base,
        isNot(
          equals(
            HistoryExplanation(
              id: 'exp-2',
              responseText: 'Step 1',
              createdAt: timestamp,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            HistoryExplanation(
              id: 'exp-1',
              responseText: 'Step 2',
              createdAt: timestamp,
            ),
          ),
        ),
      );
    });

    test('props contains all fields in order', () {
      final exp = HistoryExplanation(
        id: 'exp-1',
        solverRunId: 'run-1',
        userId: 'user-1',
        focusMode: 'summary',
        promptHash: 'h1',
        responseText: 'text',
        expiresAt: expires,
        createdAt: timestamp,
      );

      expect(exp.props, [
        'exp-1',
        'run-1',
        'user-1',
        'summary',
        'h1',
        'text',
        expires,
        timestamp,
      ]);
    });
  });

  group('HistoryRun Entity', () {
    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    test('supports value equality with Equatable', () {
      final run1 = HistoryRun(
        id: 'run-1',
        userId: 'user-1',
        method: 'root/bisection',
        inputPayload: const {'equation': 'x^2 - 4'},
        outputPayload: const {
          'finalAnswer': {'root': 2.0},
        },
        createdAt: timestamp,
        aiExplanations: [
          HistoryExplanation(
            id: 'exp-1',
            responseText: 'Explanation text',
            createdAt: timestamp,
          ),
        ],
      );
      final run2 = HistoryRun(
        id: 'run-1',
        userId: 'user-1',
        method: 'root/bisection',
        inputPayload: const {'equation': 'x^2 - 4'},
        outputPayload: const {
          'finalAnswer': {'root': 2.0},
        },
        createdAt: timestamp,
        aiExplanations: [
          HistoryExplanation(
            id: 'exp-1',
            responseText: 'Explanation text',
            createdAt: timestamp,
          ),
        ],
      );

      expect(run1, equals(run2));
      expect(run1.hashCode, equals(run2.hashCode));
    });

    test('handles default optional parameters cleanly', () {
      final run = HistoryRun(
        id: 'run-default',
        method: 'ode/euler',
        createdAt: timestamp,
      );

      expect(run.userId, isNull);
      expect(run.inputPayload, isEmpty);
      expect(run.outputPayload, isEmpty);
      expect(run.aiExplanations, isEmpty);
    });

    test('different IDs or methods are not equal', () {
      final base = HistoryRun(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: timestamp,
      );

      expect(
        base,
        isNot(
          equals(
            HistoryRun(
              id: 'run-2',
              method: 'root/bisection',
              createdAt: timestamp,
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            HistoryRun(
              id: 'run-1',
              method: 'root/newton-raphson',
              createdAt: timestamp,
            ),
          ),
        ),
      );
    });

    test('props contains all fields in order', () {
      final explanation = HistoryExplanation(
        id: 'exp-1',
        responseText: 'Explanation text',
        createdAt: timestamp,
      );
      final run = HistoryRun(
        id: 'run-1',
        userId: 'user-1',
        method: 'root/bisection',
        inputPayload: const {'a': 1},
        outputPayload: const {'b': 2},
        createdAt: timestamp,
        aiExplanations: [explanation],
      );

      expect(run.props, [
        'run-1',
        'user-1',
        'root/bisection',
        const {'a': 1},
        const {'b': 2},
        timestamp,
        [explanation],
      ]);
    });
  });

  group('PaginatedHistory Entity', () {
    final timestamp = DateTime.parse('2026-09-30T10:00:00.000Z');

    test('supports value equality with Equatable', () {
      final run = HistoryRun(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: timestamp,
      );
      const pagination = Pagination(
        total: 1,
        limit: 20,
        offset: 0,
        hasMore: false,
      );

      final page1 = PaginatedHistory(
        runs: [run],
        pagination: pagination,
      );
      final page2 = PaginatedHistory(
        runs: [run],
        pagination: pagination,
      );

      expect(page1, equals(page2));
      expect(page1.hashCode, equals(page2.hashCode));
    });

    test('different runs or pagination are not equal', () {
      final run1 = HistoryRun(
        id: 'run-1',
        method: 'root/bisection',
        createdAt: timestamp,
      );
      final run2 = HistoryRun(
        id: 'run-2',
        method: 'root/secant',
        createdAt: timestamp,
      );
      const pagination = Pagination(
        total: 1,
        limit: 20,
        offset: 0,
        hasMore: false,
      );

      final page1 = PaginatedHistory(
        runs: [run1],
        pagination: pagination,
      );
      final page2 = PaginatedHistory(
        runs: [run2],
        pagination: pagination,
      );

      expect(page1, isNot(equals(page2)));
    });

    test('props contains runs and pagination', () {
      final runs = [
        HistoryRun(
          id: 'run-1',
          method: 'root/bisection',
          createdAt: timestamp,
        ),
      ];
      const pagination = Pagination(
        total: 1,
        limit: 20,
        offset: 0,
        hasMore: false,
      );

      final page = PaginatedHistory(
        runs: runs,
        pagination: pagination,
      );

      expect(page.props, [runs, pagination]);
    });
  });
}
