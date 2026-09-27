import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/solvers/domain/models/models.dart';

void main() {
  group('SolverMethodRegistry Completeness and Structure', () {
    test('contains exactly 27 solver configurations', () {
      expect(SolverMethodRegistry.all.length, 27);
    });

    test('all 27 solver IDs are unique and non-empty', () {
      final ids = SolverMethodRegistry.all.map((s) => s.id).toList();
      final uniqueIds = ids.toSet();

      expect(ids.every((id) => id.isNotEmpty), isTrue);
      expect(uniqueIds.length, 27);
    });

    test('all 27 endpoints are unique and follow /solve/... convention', () {
      final endpoints = SolverMethodRegistry.all
          .map((s) => s.endpoint)
          .toList();
      final uniqueEndpoints = endpoints.toSet();

      expect(endpoints.every((ep) => ep.startsWith('/solve/')), isTrue);
      expect(uniqueEndpoints.length, 27);
    });

    test(
      'solvers are partitioned into categories matching backend modular structure',
      () {
        final roots = SolverMethodRegistry.getByCategory(
          SolverCategory.rootFinding,
        );
        final linears = SolverMethodRegistry.getByCategory(
          SolverCategory.linearAlgebra,
        );
        final interpolations = SolverMethodRegistry.getByCategory(
          SolverCategory.interpolation,
        );
        final odes = SolverMethodRegistry.getByCategory(SolverCategory.ode);
        final integrations = SolverMethodRegistry.getByCategory(
          SolverCategory.integration,
        );
        final diffs = SolverMethodRegistry.getByCategory(
          SolverCategory.differentiation,
        );

        expect(
          roots.length,
          4,
          reason:
              '4 Root-Finding methods: Bisection, Newton, Secant, Regula Falsi',
        );
        expect(
          linears.length,
          3,
          reason: '3 Linear Algebra methods: Gauss Elim, Jacobi, Gauss-Seidel',
        );
        expect(
          interpolations.length,
          7,
          reason:
              '7 Interpolation methods: Lagrange, Newton DD, Forward, Backward, Central, Spline, Quadratic',
        );
        expect(
          odes.length,
          4,
          reason: '4 ODE methods: Euler, Heun, RK4, Milne',
        );
        expect(
          integrations.length,
          4,
          reason:
              '4 Integration methods: Trapezoidal, Simpson 1/3, Simpson 3/8, Gauss-Legendre',
        );
        expect(
          diffs.length,
          5,
          reason:
              '5 Differentiation methods: Forward, Backward, Central, Lagrange, Function Finite Diff',
        );

        expect(
          roots.length +
              linears.length +
              interpolations.length +
              odes.length +
              integrations.length +
              diffs.length,
          27,
        );
      },
    );

    test(
      'lookup methods: getById and getByEndpoint resolve all 27 solvers',
      () {
        for (final solver in SolverMethodRegistry.all) {
          final byId = SolverMethodRegistry.getById(solver.id);
          final byEndpoint = SolverMethodRegistry.getByEndpoint(
            solver.endpoint,
          );

          expect(byId, isNotNull, reason: 'Should resolve ${solver.id} by ID');
          expect(byId?.id, solver.id);
          expect(
            byEndpoint,
            isNotNull,
            reason:
                'Should resolve ${solver.id} by endpoint ${solver.endpoint}',
          );
          expect(byEndpoint?.id, solver.id);
        }
      },
    );

    test('getById returns null for unknown solver ID', () {
      expect(SolverMethodRegistry.getById('non_existent_solver'), isNull);
    });

    test('getByEndpoint returns null for unknown endpoint', () {
      expect(SolverMethodRegistry.getByEndpoint('/solve/unknown'), isNull);
    });
  });

  group('Representative Config: Bisection Method', () {
    final bisection = SolverMethodRegistry.bisection;

    test('metadata matches backend contract', () {
      expect(bisection.id, 'bisection');
      expect(bisection.category, SolverCategory.rootFinding);
      expect(bisection.endpoint, '/solve/root/bisection');
      expect(bisection.supportsGraph, isTrue);
      expect(bisection.supportsExplanation, isTrue);

      final equationField = bisection.getField('equation');
      expect(equationField?.validation.isRequired, isTrue);
      expect(equationField?.validation.maxLength, 500);

      final tolField = bisection.getField('tolerance');
      expect(tolField?.defaultValue, 0.0001);
      expect(tolField?.validation.isPositive, isTrue);
      expect(tolField?.validation.maxValue, 1.0);

      final iterField = bisection.getField('maxIterations');
      expect(iterField?.defaultValue, 100);
      expect(iterField?.validation.minValue, 1);
      expect(iterField?.validation.maxValue, 1000);
    });

    test('validates valid bisection payload successfully', () {
      final payload = {
        'equation': 'x^3 - x - 2',
        'lowerBound': 1.0,
        'upperBound': 2.0,
        'tolerance': 0.0001,
        'maxIterations': 100,
        'includeExplanation': true,
        'includeGraphData': true,
      };

      final errors = bisection.validate(payload);
      expect(errors, isEmpty);
    });

    test('rejects payload when lowerBound >= upperBound (bounds.ordered)', () {
      final payload = {
        'equation': 'x^3 - x - 2',
        'lowerBound': 2.0,
        'upperBound': 1.0,
      };

      final errors = bisection.validate(payload);
      expect(errors.containsKey('bounds.ordered'), isTrue);
      expect(
        errors['bounds.ordered'],
        'lowerBound must be less than upperBound',
      );
    });

    test('rejects payload when equation is empty or tolerance <= 0', () {
      final payload = {
        'equation': '',
        'lowerBound': 1.0,
        'upperBound': 2.0,
        'tolerance': -0.01,
      };

      final errors = bisection.validate(payload);
      expect(errors.containsKey('equation'), isTrue);
      expect(errors.containsKey('tolerance'), isTrue);
      expect(errors['tolerance'], 'Tolerance must be positive');
    });

    test('rejects payload when maxIterations exceeds 1000', () {
      final payload = {
        'equation': 'x^2 - 4',
        'lowerBound': 1.0,
        'upperBound': 3.0,
        'maxIterations': 5000,
      };

      final errors = bisection.validate(payload);
      expect(errors.containsKey('maxIterations'), isTrue);
      expect(errors['maxIterations'], 'Max Iterations must not exceed 1000');
    });
  });

  group('Representative Config: Jacobi Method', () {
    final jacobi = SolverMethodRegistry.jacobi;

    test('metadata matches backend contract', () {
      expect(jacobi.id, 'jacobi');
      expect(jacobi.category, SolverCategory.linearAlgebra);
      expect(jacobi.endpoint, '/solve/linear/jacobi');
      expect(jacobi.supportsGraph, isFalse);
      expect(jacobi.supportsExplanation, isTrue);

      final maxIter = jacobi.getField('maxIterations');
      expect(
        maxIter?.validation.maxValue,
        10000,
        reason: 'Backend allows up to 10000 iterations for linear systems',
      );
    });

    test('validates valid 2x2 diagonally dominant linear system', () {
      final payload = {
        'matrix': [
          [4.0, 1.0],
          [1.0, 3.0],
        ],
        'constants': [1.0, 2.0],
        'initialGuess': [0.0, 0.0],
        'tolerance': 0.0001,
        'maxIterations': 100,
      };

      final errors = jacobi.validate(payload);
      expect(errors, isEmpty);
    });

    test('rejects non-square matrix dimensions (linear.dimensions)', () {
      final payload = {
        'matrix': [
          [4.0, 1.0, 0.0],
          [1.0, 3.0], // row length 2, but size is 2 or 3
        ],
        'constants': [1.0, 2.0],
      };

      final errors = jacobi.validate(payload);
      expect(errors.containsKey('linear.dimensions'), isTrue);
    });

    test('rejects constants vector length mismatch (linear.dimensions)', () {
      final payload = {
        'matrix': [
          [4.0, 1.0],
          [1.0, 3.0],
        ],
        'constants': [1.0], // length 1 instead of 2
      };

      final errors = jacobi.validate(payload);
      expect(errors.containsKey('linear.dimensions'), isTrue);
      expect(
        errors['linear.dimensions'],
        'constants must contain exactly 2 values',
      );
    });

    test('rejects initialGuess vector length mismatch (linear.dimensions)', () {
      final payload = {
        'matrix': [
          [4.0, 1.0],
          [1.0, 3.0],
        ],
        'constants': [1.0, 2.0],
        'initialGuess': [0.0, 0.0, 0.0], // length 3 instead of 2
      };

      final errors = jacobi.validate(payload);
      expect(errors.containsKey('linear.dimensions'), isTrue);
      expect(
        errors['linear.dimensions'],
        'initialGuess must contain exactly 2 values',
      );
    });
  });

  group('Representative Config: Lagrange Interpolation', () {
    final lagrange = SolverMethodRegistry.lagrangeInterpolation;

    test('metadata matches backend contract', () {
      expect(lagrange.id, 'lagrange');
      expect(lagrange.category, SolverCategory.interpolation);
      expect(lagrange.endpoint, '/solve/interpolation/lagrange');
      expect(lagrange.supportsGraph, isTrue);

      final pointsField = lagrange.getField('points');
      expect(pointsField?.validation.minItems, 2);
      expect(pointsField?.validation.maxItems, 100);
    });

    test('validates valid interpolation points payload', () {
      final payload = {
        'points': [
          {'x': 1.0, 'y': 2.0},
          {'x': 2.0, 'y': 3.0},
          {'x': 3.0, 'y': 5.0},
        ],
        'targetX': 2.5,
      };

      final errors = lagrange.validate(payload);
      expect(errors, isEmpty);
    });

    test('rejects payload with duplicate x coordinates (points.uniqueX)', () {
      final payload = {
        'points': [
          {'x': 1.0, 'y': 2.0},
          {'x': 1.0, 'y': 4.0}, // Duplicate x = 1.0
        ],
        'targetX': 1.5,
      };

      final errors = lagrange.validate(payload);
      expect(errors.containsKey('points.uniqueX'), isTrue);
      expect(errors['points.uniqueX'], 'x values must be unique');
    });

    test('rejects payload with fewer than 2 points', () {
      final payload = {
        'points': [
          {'x': 1.0, 'y': 2.0},
        ],
        'targetX': 1.5,
      };

      final errors = lagrange.validate(payload);
      expect(errors.containsKey('points'), isTrue);
      expect(errors['points'], 'Data Points (x, y) requires at least 2 items');
    });

    test('rejects payload with missing targetX', () {
      final payload = {
        'points': [
          {'x': 1.0, 'y': 2.0},
          {'x': 2.0, 'y': 3.0},
        ],
      };

      final errors = lagrange.validate(payload);
      expect(errors.containsKey('targetX'), isTrue);
      expect(errors['targetX'], 'Target x is required');
    });
  });

  group('Representative Rules for Other Solvers', () {
    test('Secant method rejects identical guesses (guesses.distinct)', () {
      final secant = SolverMethodRegistry.secant;
      final payload = {
        'equation': 'x^2 - 4',
        'firstGuess': 2.0,
        'secondGuess': 2.0,
      };

      final errors = secant.validate(payload);
      expect(errors.containsKey('guesses.distinct'), isTrue);
      expect(
        errors['guesses.distinct'],
        'firstGuess and secondGuess must be different',
      );
    });

    test("Simpson's 1/3 Rule rejects odd subintervals (subintervals.even)", () {
      final simpson13 = SolverMethodRegistry.simpson13;
      final payload = {
        'equation': 'x^2',
        'lowerBound': 0.0,
        'upperBound': 1.0,
        'subintervals': 5, // Odd number
      };

      final errors = simpson13.validate(payload);
      expect(
        errors.containsKey('subintervals.even') ||
            errors.containsKey('subintervals'),
        isTrue,
      );
    });

    test("Simpson's 3/8 Rule rejects subintervals not divisible by 3", () {
      final simpson38 = SolverMethodRegistry.simpson38;
      final payload = {
        'equation': 'x^2',
        'lowerBound': 0.0,
        'upperBound': 1.0,
        'subintervals': 5, // Not divisible by 3
      };

      final errors = simpson38.validate(payload);
      expect(
        errors.containsKey('subintervals.divisibleByThree') ||
            errors.containsKey('subintervals'),
        isTrue,
      );
    });

    test(
      'Gauss-Legendre Quadrature accepts 2, 3, 4, 5 points and rejects other values',
      () {
        final gauss = SolverMethodRegistry.gaussLegendre;
        final pointsField = gauss.getField('points')!;

        expect(pointsField.validate(2), isNull);
        expect(pointsField.validate(5), isNull);
        expect(pointsField.validate(6), isNotNull);
        expect(pointsField.validate(1), isNotNull);
      },
    );

    test(
      'ODE solvers require either xn or steps, rejecting both or neither',
      () {
        final euler = SolverMethodRegistry.euler;

        // Neither xn nor steps
        final neitherErrors = euler.validate({
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
        });
        expect(neitherErrors.containsKey('ode.stepSpecification'), isTrue);
        expect(
          neitherErrors['ode.stepSpecification'],
          'either xn or steps is required',
        );

        // Both xn and steps
        final bothErrors = euler.validate({
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
          'xn': 1.0,
          'steps': 10,
        });
        expect(bothErrors.containsKey('ode.stepSpecification'), isTrue);
        expect(
          bothErrors['ode.stepSpecification'],
          'provide either xn or steps, not both',
        );

        // Valid with steps
        final validStepsErrors = euler.validate({
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
          'steps': 10,
        });
        expect(validStepsErrors, isEmpty);

        // Valid with xn
        final validXnErrors = euler.validate({
          'equation': 'x + y',
          'x0': 0.0,
          'y0': 1.0,
          'h': 0.1,
          'xn': 1.0,
        });
        expect(validXnErrors, isEmpty);
      },
    );

    test(
      'Central Difference Interpolation Bessel variant requires at least 4 points',
      () {
        final cd = SolverMethodRegistry.centralDifferenceInterpolation;

        final bessel3PointsErrors = cd.validate({
          'points': [
            {'x': 1.0, 'y': 2.0},
            {'x': 2.0, 'y': 3.0},
            {'x': 3.0, 'y': 4.0},
          ],
          'targetX': 2.0,
          'variant': 'bessel',
        });
        expect(
          bessel3PointsErrors.containsKey('centralDifference.besselShape'),
          isTrue,
        );

        final stirling3PointsErrors = cd.validate({
          'points': [
            {'x': 1.0, 'y': 2.0},
            {'x': 2.0, 'y': 3.0},
            {'x': 3.0, 'y': 4.0},
          ],
          'targetX': 2.0,
          'variant': 'stirling',
        });
        expect(
          stirling3PointsErrors.containsKey('centralDifference.besselShape'),
          isFalse,
        );
      },
    );

    test(
      'Function Finite Difference requires positive h and valid variant',
      () {
        const ffd = SolverMethodRegistry.functionFiniteDifference;

        final invalidVariant = ffd.validate({
          'equation': 'sin(x)',
          'targetX': 1.0,
          'h': -0.1,
          'variant': 'invalid-variant',
        });

        expect(invalidVariant.containsKey('h'), isTrue);
        expect(invalidVariant.containsKey('variant'), isTrue);

        final valid = ffd.validate({
          'equation': 'sin(x)',
          'targetX': 1.0,
          'h': 0.001,
          'variant': 'central',
        });
        expect(valid, isEmpty);
      },
    );
  });
}
