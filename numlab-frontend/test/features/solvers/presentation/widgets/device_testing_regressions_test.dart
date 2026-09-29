import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/domain/entities/solver_result.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_iterations_view.dart';
import 'package:numlab_frontend/features/solvers/presentation/widgets/result/solver_result_view.dart';

void main() {
  group('Physical Device Testing Regressions', () {
    group('Priority 1: Result View Overflow', () {
      testWidgets(
        'renders metadata footer cleanly on narrow 320px screen without RenderFlex overflow',
        (tester) async {
          // Set narrow physical device viewport (320px width)
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          const result = SolverResult(
            method: 'Bisection Method',
            executionTimeMs: 12,
            finalAnswer: {'root': 1.41421356},
            requestId: 'req_a1b2c3d4-e5f6-7890-abcd-ef1234567890',
            timestamp: '2026-09-29T10:38:00.123456Z',
          );

          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SolverResultView(result: result),
                ),
              ),
            ),
          );

          expect(find.byKey(const Key('solver_result_meta')), findsOneWidget);
          expect(
            find.text('Req: req_a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
            findsOneWidget,
          );
          expect(
            find.text('2026-09-29T10:38:00.123456Z'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('Priority 2: Iteration DataTable Schema Stability', () {
      testWidgets(
        'renders Gauss Elimination steps with heterogeneous keys without DataTable assertion crash',
        (tester) async {
          final gaussIterations = [
            {
              'step': 1,
              'pivotRow': 1,
              'pivotElement': 4.0,
              'multiplier': 0.5,
              'matrix': [
                [4.0, 1.0, 2.0, 9.0],
                [0.0, 1.5, 0.0, 2.5],
                [1.0, 0.0, 3.0, 5.0],
              ],
            },
            {
              'step': 2,
              'pivotRow': 2,
              'pivotElement': 1.5,
              'matrix': [
                [4.0, 1.0, 2.0, 9.0],
                [0.0, 1.5, 0.0, 2.5],
                [0.0, 0.0, 2.5, 2.5],
              ],
            },
            {
              'step': 3,
              'note': 'Back substitution complete',
              'solutionVector': [1.0, 2.0, 1.0],
            },
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SolverIterationsView(iterations: gaussIterations),
                ),
              ),
            ),
          );

          // Expand the iterations ExpansionTile
          await tester.tap(find.byKey(const Key('solver_iterations_expansion_tile')));
          await tester.pumpAndSettle();

          expect(find.byType(DataTable), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'renders Natural Cubic Spline intermediate steps with differing keys',
        (tester) async {
          final splineIterations = [
            {'i': 0, 'h': 1.0, 'alpha': 2.5},
            {'i': 1, 'h': 1.0, 'alpha': 3.0, 'mu': 0.5, 'z': 1.2},
            {'i': 2, 'h': 1.0, 'c': 0.8, 'b': 1.1, 'd': -0.2},
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SolverIterationsView(iterations: splineIterations),
                ),
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('solver_iterations_expansion_tile')));
          await tester.pumpAndSettle();

          expect(find.byType(DataTable), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'renders Stirling & Gauss differentiation difference tables with variable orders',
        (tester) async {
          final diffTableIterations = [
            {'x': 1.0, 'y': 2.0, 'dy1': 0.5, 'dy2': 0.1, 'dy3': 0.02},
            {'x': 1.1, 'y': 2.55, 'dy1': 0.6, 'dy2': 0.12},
            {'x': 1.2, 'y': 3.17, 'dy1': 0.72},
            {'x': 1.3, 'y': 3.89},
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SolverIterationsView(iterations: diffTableIterations),
                ),
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('solver_iterations_expansion_tile')));
          await tester.pumpAndSettle();

          expect(find.byType(DataTable), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('Priority 3: Euler Payload Sanitization & Null Key Omission', () {
      test('omits xn when steps is configured', () {
        final raw = <String, dynamic>{
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
          'xn': null,
          'steps': 10,
          'includeExplanation': true,
          'includeGraphData': true,
        };

        final sanitized = SolverMethodConfig.sanitizePayload(raw);

        expect(sanitized.containsKey('steps'), isTrue);
        expect(sanitized['steps'], equals(10));
        expect(sanitized.containsKey('xn'), isFalse);
        expect(sanitized['x0'], equals(0.0));
        expect(sanitized['y0'], equals(1.0));
        expect(sanitized['h'], equals(0.1));
        expect(sanitized['includeExplanation'], isTrue);
        expect(sanitized['includeGraphData'], isTrue);
      });

      test('omits steps when xn is configured', () {
        final raw = <String, dynamic>{
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
          'xn': 1.0,
          'steps': null,
          'includeExplanation': false,
        };

        final sanitized = SolverMethodConfig.sanitizePayload(raw);

        expect(sanitized.containsKey('xn'), isTrue);
        expect(sanitized['xn'], equals(1.0));
        expect(sanitized.containsKey('steps'), isFalse);
        expect(sanitized['includeExplanation'], isFalse);
      });

      test('removes empty string optional fields and null keys', () {
        final raw = <String, dynamic>{
          'equation': 'cos(x) - x',
          'lowerBound': 0.0,
          'upperBound': 1.0,
          'tolerance': null,
          'maxIterations': '',
          'optionalComment': '   ',
          'matrix': [
            [1, 2],
            [3, 4],
          ],
        };

        final sanitized = SolverMethodConfig.sanitizePayload(raw);

        expect(sanitized.containsKey('tolerance'), isFalse);
        expect(sanitized.containsKey('maxIterations'), isFalse);
        expect(sanitized.containsKey('optionalComment'), isFalse);
        expect(sanitized['equation'], equals('cos(x) - x'));
        expect(sanitized['lowerBound'], equals(0.0));
        expect(sanitized['upperBound'], equals(1.0));
        expect(
          sanitized['matrix'],
          equals([
            [1, 2],
            [3, 4],
          ]),
        );
      });

      test('normalizes standard function names such as Sin -> sin, COS -> cos in equation payloads', () {
        final raw = <String, dynamic>{
          'equation': 'Sin(x) + COS(x) - Exp(x) * Sqrt(x)',
          'x0': 0.0,
        };

        final sanitized = SolverMethodConfig.sanitizePayload(raw);

        expect(
          sanitized['equation'],
          equals('sin(x) + cos(x) - exp(x) * sqrt(x)'),
        );
      });
    });
  });
}
