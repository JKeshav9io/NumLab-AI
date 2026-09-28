import 'package:numlab_frontend/features/solvers/domain/models/solver_category.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_cross_field_rule.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_field_validation.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_input_field_config.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_input_field_type.dart';
import 'package:numlab_frontend/features/solvers/domain/models/solver_method_config.dart';

/// Central registry defining configurations, schemas, and validation rules
/// for all 27 numerical solvers implemented in NumLab AI.
abstract final class SolverMethodRegistry {
  // ===========================================================================
  // COMMON REUSABLE FIELD DESCRIPTORS
  // ===========================================================================

  static const SolverInputFieldConfig _equationField = SolverInputFieldConfig(
    name: 'equation',
    label: 'Equation f(x)',
    type: SolverInputFieldType.equation,
    placeholder: 'e.g. x^3 - x - 2',
    helperText: 'Nonlinear mathematical expression in terms of x',
    validation: SolverFieldValidation(
      maxLength: 500,
    ),
  );

  static const SolverInputFieldConfig _odeEquationField =
      SolverInputFieldConfig(
        name: 'equation',
        label: 'Equation f(x, y)',
        type: SolverInputFieldType.equation,
        placeholder: 'e.g. x + y',
        helperText:
            'First-order ODE right-hand side f(x, y) for dy/dx = f(x, y)',
        validation: SolverFieldValidation(
          maxLength: 500,
        ),
      );

  static const SolverInputFieldConfig _lowerBoundField = SolverInputFieldConfig(
    name: 'lowerBound',
    label: 'Lower Bound (a)',
    type: SolverInputFieldType.number,
    placeholder: 'e.g. 1.0',
    helperText: 'Starting boundary of the interval',
  );

  static const SolverInputFieldConfig _upperBoundField = SolverInputFieldConfig(
    name: 'upperBound',
    label: 'Upper Bound (b)',
    type: SolverInputFieldType.number,
    placeholder: 'e.g. 2.0',
    helperText: 'Ending boundary of the interval',
  );

  static const SolverInputFieldConfig _rootToleranceField =
      SolverInputFieldConfig(
        name: 'tolerance',
        label: 'Tolerance',
        type: SolverInputFieldType.number,
        defaultValue: 0.0001,
        placeholder: '0.0001',
        helperText: 'Convergence threshold (0 < tolerance <= 1)',
        validation: SolverFieldValidation(
          isRequired: false,
          isPositive: true,
          maxValue: 1.0,
        ),
      );

  static const SolverInputFieldConfig _rootMaxIterationsField =
      SolverInputFieldConfig(
        name: 'maxIterations',
        label: 'Max Iterations',
        type: SolverInputFieldType.integer,
        defaultValue: 100,
        placeholder: '100',
        helperText: 'Maximum allowed iterations (1 to 1000)',
        validation: SolverFieldValidation(
          isRequired: false,
          minValue: 1,
          maxValue: 1000,
        ),
      );

  static const SolverInputFieldConfig _linearToleranceField =
      SolverInputFieldConfig(
        name: 'tolerance',
        label: 'Tolerance',
        type: SolverInputFieldType.number,
        defaultValue: 0.0001,
        placeholder: '0.0001',
        helperText: 'Iterative convergence threshold (0 < tolerance <= 1)',
        validation: SolverFieldValidation(
          isRequired: false,
          isPositive: true,
          maxValue: 1.0,
        ),
      );

  static const SolverInputFieldConfig _linearMaxIterationsField =
      SolverInputFieldConfig(
        name: 'maxIterations',
        label: 'Max Iterations',
        type: SolverInputFieldType.integer,
        defaultValue: 100,
        placeholder: '100',
        helperText: 'Maximum allowed iterations (1 to 10000)',
        validation: SolverFieldValidation(
          isRequired: false,
          minValue: 1,
          maxValue: 10000,
        ),
      );

  static const SolverInputFieldConfig _includeExplanationField =
      SolverInputFieldConfig(
        name: 'includeExplanation',
        label: 'Include Explanation',
        type: SolverInputFieldType.boolean,
        defaultValue: true,
        helperText: 'Generate step-by-step mathematical reasoning',
        validation: SolverFieldValidation(isRequired: false),
      );

  static const SolverInputFieldConfig _includeGraphDataField =
      SolverInputFieldConfig(
        name: 'includeGraphData',
        label: 'Include Graph Data',
        type: SolverInputFieldType.boolean,
        defaultValue: true,
        helperText:
            'Generate interactive 2D function curve and iteration points',
        validation: SolverFieldValidation(isRequired: false),
      );

  static const SolverInputFieldConfig _targetXField = SolverInputFieldConfig(
    name: 'targetX',
    label: 'Target x',
    type: SolverInputFieldType.number,
    placeholder: 'e.g. 2.5',
    helperText: 'The evaluation point x',
  );

  static const SolverInputFieldConfig _exactValueField = SolverInputFieldConfig(
    name: 'exactValue',
    label: 'Exact Value (Optional)',
    type: SolverInputFieldType.number,
    placeholder: 'e.g. 1.57079',
    helperText: 'Analytic integral value for error benchmark calculation',
    validation: SolverFieldValidation(isRequired: false),
  );

  static const SolverInputFieldConfig _exactDerivativeField =
      SolverInputFieldConfig(
        name: 'exactDerivative',
        label: 'Exact Derivative (Optional)',
        type: SolverInputFieldType.number,
        placeholder: 'e.g. 2.0',
        helperText: 'Analytic derivative value for error benchmark calculation',
        validation: SolverFieldValidation(isRequired: false),
      );

  // ===========================================================================
  // COMMON REUSABLE CROSS-FIELD RULES
  // ===========================================================================

  static num? _tryParseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  static final SolverCrossFieldRule _boundsOrderedRule = SolverCrossFieldRule(
    id: 'bounds.ordered',
    description: 'lowerBound must be less than upperBound',
    affectedFieldNames: const ['lowerBound', 'upperBound'],
    validator: (values) {
      final lower = _tryParseNum(values['lowerBound']);
      final upper = _tryParseNum(values['upperBound']);
      if (lower != null && upper != null && lower >= upper) {
        return 'lowerBound must be less than upperBound';
      }
      return null;
    },
  );

  static final SolverCrossFieldRule _secantGuessesDistinctRule =
      SolverCrossFieldRule(
        id: 'guesses.distinct',
        description: 'firstGuess and secondGuess must be different',
        affectedFieldNames: const ['firstGuess', 'secondGuess'],
        validator: (values) {
          final first = _tryParseNum(values['firstGuess']);
          final second = _tryParseNum(values['secondGuess']);
          if (first != null && second != null && first == second) {
            return 'firstGuess and secondGuess must be different';
          }
          return null;
        },
      );

  static SolverCrossFieldRule _linearDimensionRule({
    bool allowsInitialGuess = false,
  }) {
    return SolverCrossFieldRule(
      id: 'linear.dimensions',
      description:
          'Matrix must be square N x N and constants must have length N',
      affectedFieldNames: [
        'matrix',
        'constants',
        if (allowsInitialGuess) 'initialGuess',
      ],
      validator: (values) {
        final matrix = values['matrix'];
        final constants = values['constants'];
        final initialGuess = values['initialGuess'];
        if (matrix is List && constants is List) {
          final size = matrix.length;
          for (var i = 0; i < size; i++) {
            final row = matrix[i];
            if (row is! List || row.length != size) {
              return 'matrix row ${i + 1} must contain exactly $size values';
            }
          }
          if (constants.length != size) {
            return 'constants must contain exactly $size values';
          }
          if (allowsInitialGuess &&
              initialGuess != null &&
              initialGuess is List &&
              initialGuess.length != size) {
            return 'initialGuess must contain exactly $size values';
          }
        }
        return null;
      },
    );
  }

  static final SolverCrossFieldRule _uniquePointsXRule = SolverCrossFieldRule(
    id: 'points.uniqueX',
    description: 'x coordinates of points must be unique',
    affectedFieldNames: const ['points'],
    validator: (values) {
      final points = values['points'];
      if (points is List) {
        final seen = <num>{};
        for (final pt in points) {
          if (pt is Map) {
            final x = _tryParseNum(pt['x']);
            if (x != null) {
              if (seen.contains(x)) {
                return 'x values must be unique';
              }
              seen.add(x);
            }
          }
        }
      }
      return null;
    },
  );

  static final SolverCrossFieldRule _equalSpacingXRule = SolverCrossFieldRule(
    id: 'points.equalSpacing',
    description:
        'x values must be equally spaced for finite-difference methods',
    affectedFieldNames: const ['points'],
    validator: (values) {
      final points = values['points'];
      if (points is List && points.length >= 2) {
        final xList = <num>[];
        for (final pt in points) {
          if (pt is Map) {
            final x = _tryParseNum(pt['x']);
            if (x != null) {
              xList.add(x);
            }
          }
        }
        if (xList.length < points.length) return null;
        xList.sort();
        final h = xList[1] - xList[0];
        if (h.abs() <= 1e-10) {
          return 'point spacing must not be zero';
        }
        for (var i = 1; i < xList.length - 1; i++) {
          final actual = xList[i + 1] - xList[i];
          if ((actual - h).abs() > 1e-10) {
            return 'x values must be equally spaced';
          }
        }
      }
      return null;
    },
  );

  static SolverCrossFieldRule _odeStepSpecificationRule({int? minSteps}) {
    return SolverCrossFieldRule(
      id: 'ode.stepSpecification',
      description:
          'Provide either xn or steps, with xn > x0 and exact step multiple',
      affectedFieldNames: const ['x0', 'h', 'xn', 'steps'],
      validator: (values) {
        final hasXn =
            values['xn'] != null &&
            (values['xn'] is! String ||
                (values['xn'] as String).trim().isNotEmpty);
        final hasSteps =
            values['steps'] != null &&
            (values['steps'] is! String ||
                (values['steps'] as String).trim().isNotEmpty);

        if (!hasXn && !hasSteps) {
          return 'either xn or steps is required';
        }
        if (hasXn && hasSteps) {
          return 'provide either xn or steps, not both';
        }

        final x0 = _tryParseNum(values['x0']);
        final h = _tryParseNum(values['h']);
        final xn = _tryParseNum(values['xn']);
        final steps = _tryParseNum(values['steps']);

        if (hasXn && x0 != null && h != null && xn != null) {
          if (xn <= x0) {
            return 'xn must be greater than x0 for positive h';
          }
          final rawSteps = (xn - x0) / h;
          if ((rawSteps - rawSteps.round()).abs() > 1e-10) {
            return 'xn - x0 must be an exact positive multiple of h, or provide steps instead';
          }
          final resolvedSteps = rawSteps.round();
          if (minSteps != null && resolvedSteps < minSteps) {
            return 'Requires at least $minSteps steps';
          }
        }

        if (hasSteps && steps != null && minSteps != null && steps < minSteps) {
          return 'Requires at least $minSteps steps';
        }

        return null;
      },
    );
  }

  // ===========================================================================
  // 1. ROOT FINDING SOLVERS (4)
  // ===========================================================================

  /// Bisection Method: Brackets a root by repeatedly halving an interval [a, b].
  static final SolverMethodConfig bisection = SolverMethodConfig(
    id: 'bisection',
    name: 'Bisection Method',
    category: SolverCategory.rootFinding,
    description:
        'Interval-halving root-finding algorithm requiring f(a) and f(b) to have opposite signs.',
    endpoint: '/solve/root/bisection',
    fields: const [
      _equationField,
      _lowerBoundField,
      _upperBoundField,
      _rootToleranceField,
      _rootMaxIterationsField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_boundsOrderedRule],
  );

  /// Newton-Raphson Method: Uses tangent line slopes to rapidly converge to a root.
  static const SolverMethodConfig newtonRaphson = SolverMethodConfig(
    id: 'newton-raphson',
    name: 'Newton-Raphson Method',
    category: SolverCategory.rootFinding,
    description:
        "Rapidly converging open method utilizing derivative f'(x) to compute successive approximations.",
    endpoint: '/solve/root/newton',
    fields: [
      _equationField,
      SolverInputFieldConfig(
        name: 'derivativeEquation',
        label: "Derivative f'(x) (Optional)",
        type: SolverInputFieldType.equation,
        placeholder: 'e.g. 3*x^2 - 1',
        helperText:
            'Symbolic derivative. If omitted, backend approximates numerically.',
        validation: SolverFieldValidation(
          isRequired: false,
          maxLength: 500,
        ),
      ),
      SolverInputFieldConfig(
        name: 'initialGuess',
        label: 'Initial Guess (x0)',
        type: SolverInputFieldType.number,
        placeholder: 'e.g. 1.5',
        helperText: 'Starting estimate for the root',
      ),
      _rootToleranceField,
      _rootMaxIterationsField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
  );

  /// Secant Method: Root-finding using secant lines through two initial estimates.
  static final SolverMethodConfig secant = SolverMethodConfig(
    id: 'secant',
    name: 'Secant Method',
    category: SolverCategory.rootFinding,
    description:
        'Approximates the derivative using finite differences between two initial estimates.',
    endpoint: '/solve/root/secant',
    fields: const [
      _equationField,
      SolverInputFieldConfig(
        name: 'firstGuess',
        label: 'First Guess (x0)',
        type: SolverInputFieldType.number,
        placeholder: 'e.g. 1.0',
        helperText: 'First starting approximation',
      ),
      SolverInputFieldConfig(
        name: 'secondGuess',
        label: 'Second Guess (x1)',
        type: SolverInputFieldType.number,
        placeholder: 'e.g. 2.0',
        helperText: 'Second starting approximation (must differ from x0)',
      ),
      _rootToleranceField,
      _rootMaxIterationsField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_secantGuessesDistinctRule],
  );

  /// Regula Falsi (False Position) Method: Linear interpolation bracketing method.
  static final SolverMethodConfig regulaFalsi = SolverMethodConfig(
    id: 'regula-falsi',
    name: 'Regula Falsi Method',
    category: SolverCategory.rootFinding,
    description:
        'Guaranteed-convergence bracketing method connecting interval endpoints with a secant line.',
    endpoint: '/solve/root/regula-falsi',
    fields: const [
      _equationField,
      _lowerBoundField,
      _upperBoundField,
      _rootToleranceField,
      _rootMaxIterationsField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_boundsOrderedRule],
  );

  // ===========================================================================
  // 2. LINEAR ALGEBRA SOLVERS (3)
  // ===========================================================================

  /// Gauss Elimination: Direct row-reduction algorithm for solving Ax = b.
  static final SolverMethodConfig gaussElimination = SolverMethodConfig(
    id: 'gauss-elimination',
    name: 'Gauss Elimination',
    category: SolverCategory.linearAlgebra,
    description:
        'Direct elimination algorithm transforming an augmented matrix into upper triangular form with back-substitution.',
    endpoint: '/solve/linear/gauss-elimination',
    fields: const [
      SolverInputFieldConfig(
        name: 'matrix',
        label: 'Coefficient Matrix (A)',
        type: SolverInputFieldType.matrix,
        helperText: 'Square N x N coefficient matrix',
        validation: SolverFieldValidation(minItems: 1),
      ),
      SolverInputFieldConfig(
        name: 'constants',
        label: 'Constants Vector (b)',
        type: SolverInputFieldType.vector,
        helperText: 'Right-hand side vector of length N',
        validation: SolverFieldValidation(minItems: 1),
      ),
      _includeExplanationField,
    ],
    crossFieldRules: [_linearDimensionRule()],
    supportsGraph: false,
  );

  /// Jacobi Method: Iterative solver for diagonally dominant linear systems.
  static final SolverMethodConfig jacobi = SolverMethodConfig(
    id: 'jacobi',
    name: 'Jacobi Method',
    category: SolverCategory.linearAlgebra,
    description:
        'Iterative method where all new variable estimates are computed in parallel from previous iteration values.',
    endpoint: '/solve/linear/jacobi',
    fields: const [
      SolverInputFieldConfig(
        name: 'matrix',
        label: 'Coefficient Matrix (A)',
        type: SolverInputFieldType.matrix,
        helperText: 'Square N x N diagonally dominant matrix',
        validation: SolverFieldValidation(minItems: 1),
      ),
      SolverInputFieldConfig(
        name: 'constants',
        label: 'Constants Vector (b)',
        type: SolverInputFieldType.vector,
        helperText: 'Right-hand side vector of length N',
        validation: SolverFieldValidation(minItems: 1),
      ),
      SolverInputFieldConfig(
        name: 'initialGuess',
        label: 'Initial Guess (x0) (Optional)',
        type: SolverInputFieldType.vector,
        helperText:
            'Starting vector of length N. Defaults to all zeros if omitted.',
        validation: SolverFieldValidation(isRequired: false, minItems: 1),
      ),
      _linearToleranceField,
      _linearMaxIterationsField,
      _includeExplanationField,
    ],
    crossFieldRules: [_linearDimensionRule(allowsInitialGuess: true)],
    supportsGraph: false,
  );

  /// Gauss-Seidel Method: Successive-displacement iterative solver for Ax = b.
  static final SolverMethodConfig gaussSeidel = SolverMethodConfig(
    id: 'gauss-seidel',
    name: 'Gauss-Seidel Method',
    category: SolverCategory.linearAlgebra,
    description:
        'Accelerated iterative method using updated component values immediately as soon as they become available.',
    endpoint: '/solve/linear/gauss-seidel',
    fields: const [
      SolverInputFieldConfig(
        name: 'matrix',
        label: 'Coefficient Matrix (A)',
        type: SolverInputFieldType.matrix,
        helperText: 'Square N x N diagonally dominant matrix',
        validation: SolverFieldValidation(minItems: 1),
      ),
      SolverInputFieldConfig(
        name: 'constants',
        label: 'Constants Vector (b)',
        type: SolverInputFieldType.vector,
        helperText: 'Right-hand side vector of length N',
        validation: SolverFieldValidation(minItems: 1),
      ),
      SolverInputFieldConfig(
        name: 'initialGuess',
        label: 'Initial Guess (x0) (Optional)',
        type: SolverInputFieldType.vector,
        helperText:
            'Starting vector of length N. Defaults to all zeros if omitted.',
        validation: SolverFieldValidation(isRequired: false, minItems: 1),
      ),
      _linearToleranceField,
      _linearMaxIterationsField,
      _includeExplanationField,
    ],
    crossFieldRules: [_linearDimensionRule(allowsInitialGuess: true)],
    supportsGraph: false,
  );

  // ===========================================================================
  // 3. INTERPOLATION SOLVERS (7)
  // ===========================================================================

  /// Lagrange Interpolation: Constructs an interpolating polynomial using basis polynomials.
  static final SolverMethodConfig lagrangeInterpolation = SolverMethodConfig(
    id: 'lagrange',
    name: 'Lagrange Interpolation',
    category: SolverCategory.interpolation,
    description:
        'Fits a unique polynomial of degree n-1 through n discrete points using Lagrange basis polynomials.',
    endpoint: '/solve/interpolation/lagrange',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 points with unique x values (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule],
  );

  /// Newton's Divided Difference: Polynomial interpolation using divided difference table.
  static final SolverMethodConfig newtonDividedDifference = SolverMethodConfig(
    id: 'newton-divided-difference',
    name: 'Newton Divided Difference',
    category: SolverCategory.interpolation,
    description:
        'Efficient polynomial interpolation suitable for irregularly spaced data points using a divided-difference table.',
    endpoint: '/solve/interpolation/newton-divided-difference',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 points with unique x values (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule],
  );

  /// Newton Forward Interpolation: Finite-difference interpolation for values near the start.
  static final SolverMethodConfig newtonForward = SolverMethodConfig(
    id: 'newton-forward',
    name: 'Newton Forward Interpolation',
    category: SolverCategory.interpolation,
    description:
        'Forward finite-difference interpolation table designed for target points near the beginning of equally spaced data.',
    endpoint: '/solve/interpolation/newton-forward',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 equally spaced points (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule, _equalSpacingXRule],
  );

  /// Newton Backward Interpolation: Finite-difference interpolation for values near the end.
  static final SolverMethodConfig newtonBackward = SolverMethodConfig(
    id: 'newton-backward',
    name: 'Newton Backward Interpolation',
    category: SolverCategory.interpolation,
    description:
        'Backward finite-difference interpolation table designed for target points near the end of equally spaced data.',
    endpoint: '/solve/interpolation/newton-backward',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 equally spaced points (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule, _equalSpacingXRule],
  );

  /// Central Difference Interpolation: Gauss, Stirling, and Bessel formulas.
  static final SolverMethodConfig
  centralDifferenceInterpolation = SolverMethodConfig(
    id: 'central-difference',
    name: 'Central Difference Interpolation',
    category: SolverCategory.interpolation,
    description:
        'Central difference formulas (Stirling, Bessel, Gauss) for targets near the center of equally spaced tables.',
    endpoint: '/solve/interpolation/central-difference',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 3 equally spaced points (min 4 for Bessel)',
        validation: SolverFieldValidation(minItems: 3, maxItems: 100),
      ),
      _targetXField,
      SolverInputFieldConfig(
        name: 'variant',
        label: 'Central Difference Variant',
        type: SolverInputFieldType.select,
        defaultValue: 'stirling',
        helperText: 'Formula variation',
        options: [
          SolverSelectOption(label: 'Stirling Formula', value: 'stirling'),
          SolverSelectOption(label: 'Bessel Formula', value: 'bessel'),
          SolverSelectOption(label: 'Gauss Forward', value: 'gauss-forward'),
          SolverSelectOption(label: 'Gauss Backward', value: 'gauss-backward'),
        ],
        validation: SolverFieldValidation(
          allowedValues: [
            'gauss-forward',
            'gauss-backward',
            'stirling',
            'bessel',
          ],
        ),
      ),
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [
      _uniquePointsXRule,
      _equalSpacingXRule,
      SolverCrossFieldRule(
        id: 'centralDifference.besselShape',
        description:
            'Bessel interpolation requires at least 4 equally spaced points',
        affectedFieldNames: const ['points', 'variant'],
        validator: (values) {
          if (values['variant'] == 'bessel') {
            final points = values['points'];
            if (points is List && points.length < 4) {
              return 'Bessel interpolation requires at least 4 equally spaced points';
            }
          }
          return null;
        },
      ),
    ],
  );

  /// Natural Cubic Spline: Smooth piecewise cubic polynomials with zero boundary curvature.
  static final SolverMethodConfig naturalCubicSpline = SolverMethodConfig(
    id: 'natural-cubic-spline',
    name: 'Natural Cubic Spline',
    category: SolverCategory.interpolation,
    description:
        'Piecewise C2-continuous cubic polynomials with natural boundary conditions (zero second derivatives at ends).',
    endpoint: '/solve/interpolation/natural-cubic-spline',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 3 points with unique x values (max 100)',
        validation: SolverFieldValidation(minItems: 3, maxItems: 100),
      ),
      _targetXField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule],
  );

  /// Quadratic Interpolation: Fits a single 2nd-degree polynomial through 3 data points.
  static final SolverMethodConfig quadraticInterpolation = SolverMethodConfig(
    id: 'quadratic',
    name: 'Quadratic Interpolation',
    category: SolverCategory.interpolation,
    description:
        'Constructs a quadratic polynomial through 3 distinct data points.',
    endpoint: '/solve/interpolation/quadratic',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Data Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 3 points with unique x values (max 100)',
        validation: SolverFieldValidation(minItems: 3, maxItems: 100),
      ),
      _targetXField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule],
  );

  // ===========================================================================
  // 4. ORDINARY DIFFERENTIAL EQUATIONS (4)
  // ===========================================================================

  static const List<SolverInputFieldConfig> _commonOdeFields = [
    _odeEquationField,
    SolverInputFieldConfig(
      name: 'x0',
      label: 'Initial x (x0)',
      type: SolverInputFieldType.number,
      placeholder: 'e.g. 0.0',
      helperText: 'Initial value of the independent variable',
    ),
    SolverInputFieldConfig(
      name: 'y0',
      label: 'Initial y (y0)',
      type: SolverInputFieldType.number,
      placeholder: 'e.g. 1.0',
      helperText: 'Initial value of the dependent variable y(x0)',
    ),
    SolverInputFieldConfig(
      name: 'h',
      label: 'Step Size (h)',
      type: SolverInputFieldType.number,
      placeholder: 'e.g. 0.1',
      helperText: 'Positive step size between consecutive points',
      validation: SolverFieldValidation(isPositive: true),
    ),
    SolverInputFieldConfig(
      name: 'xn',
      label: 'Target x (xn) (Optional)',
      type: SolverInputFieldType.number,
      placeholder: 'e.g. 1.0',
      helperText:
          'Final x value (must be an exact multiple of h above x0). Provide either xn or steps.',
      validation: SolverFieldValidation(isRequired: false),
    ),
    SolverInputFieldConfig(
      name: 'steps',
      label: 'Steps (Optional)',
      type: SolverInputFieldType.integer,
      placeholder: 'e.g. 10',
      helperText:
          'Number of integration steps (1 to 10000). Provide either steps or xn.',
      validation: SolverFieldValidation(
        isRequired: false,
        minValue: 1,
        maxValue: 10000,
      ),
    ),
    _includeExplanationField,
    _includeGraphDataField,
  ];

  /// Euler Method: First-order numerical method for solving ODE IVPs.
  static final SolverMethodConfig euler = SolverMethodConfig(
    id: 'euler',
    name: 'Euler Method',
    category: SolverCategory.ode,
    description:
        'First-order explicit forward Euler integration stepping along the tangent slope.',
    endpoint: '/solve/ode/euler',
    fields: _commonOdeFields,
    crossFieldRules: [_odeStepSpecificationRule()],
  );

  /// Heun Method (Improved Euler): Second-order predictor-corrector ODE solver.
  static final SolverMethodConfig heun = SolverMethodConfig(
    id: 'heun',
    name: 'Heun Method',
    category: SolverCategory.ode,
    description:
        'Second-order Runge-Kutta predictor-corrector method averaging starting and predicted end slopes.',
    endpoint: '/solve/ode/heun',
    fields: _commonOdeFields,
    crossFieldRules: [_odeStepSpecificationRule()],
  );

  /// Runge-Kutta 4th Order (RK4): Standard workhorse 4th-order ODE integrator.
  static final SolverMethodConfig rk4 = SolverMethodConfig(
    id: 'rk4',
    name: 'Runge-Kutta 4th Order (RK4)',
    category: SolverCategory.ode,
    description:
        'Fourth-order Runge-Kutta algorithm combining four weighted intermediate slope estimates per step.',
    endpoint: '/solve/ode/rk4',
    fields: _commonOdeFields,
    crossFieldRules: [_odeStepSpecificationRule()],
  );

  /// Milne Predictor-Corrector Method: 4th-order multistep ODE solver.
  static final SolverMethodConfig milne = SolverMethodConfig(
    id: 'milne',
    name: 'Milne Predictor-Corrector',
    category: SolverCategory.ode,
    description:
        'Fourth-order multi-step predictor-corrector method requiring at least 4 steps.',
    endpoint: '/solve/ode/milne',
    fields: _commonOdeFields,
    crossFieldRules: [_odeStepSpecificationRule(minSteps: 4)],
  );

  // ===========================================================================
  // 5. NUMERICAL INTEGRATION SOLVERS (4)
  // ===========================================================================

  /// Trapezoidal Rule: Approximates definite integrals by summing linear trapezoids.
  static final SolverMethodConfig trapezoidal = SolverMethodConfig(
    id: 'trapezoidal',
    name: 'Trapezoidal Rule',
    category: SolverCategory.integration,
    description:
        'First-degree Newton-Cotes formula approximating the area under f(x) with trapezoids.',
    endpoint: '/solve/integration/trapezoidal',
    fields: const [
      _equationField,
      _lowerBoundField,
      _upperBoundField,
      SolverInputFieldConfig(
        name: 'subintervals',
        label: 'Subintervals (n)',
        type: SolverInputFieldType.integer,
        placeholder: 'e.g. 100',
        helperText: 'Number of subintervals (1 to 10000)',
        validation: SolverFieldValidation(
          minValue: 1,
          maxValue: 10000,
        ),
      ),
      _exactValueField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_boundsOrderedRule],
  );

  /// Simpson's 1/3 Rule: Parabolic numerical integration requiring an even number of subintervals.
  static final SolverMethodConfig simpson13 = SolverMethodConfig(
    id: 'simpson-13',
    name: "Simpson's 1/3 Rule",
    category: SolverCategory.integration,
    description:
        'Second-degree Newton-Cotes formula fitting quadratic parabolas over adjacent pairs of subintervals (n must be even).',
    endpoint: '/solve/integration/simpson-13',
    fields: const [
      _equationField,
      _lowerBoundField,
      _upperBoundField,
      SolverInputFieldConfig(
        name: 'subintervals',
        label: 'Subintervals (n)',
        type: SolverInputFieldType.integer,
        placeholder: 'e.g. 100',
        helperText: 'Number of subintervals (2 to 10000, must be even)',
        validation: SolverFieldValidation(
          minValue: 2,
          maxValue: 10000,
          mustBeEven: true,
        ),
      ),
      _exactValueField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [
      _boundsOrderedRule,
      SolverCrossFieldRule(
        id: 'subintervals.even',
        description: "subintervals must be even for Simpson's 1/3 Rule",
        affectedFieldNames: const ['subintervals'],
        validator: (values) {
          final n = values['subintervals'];
          if (n is num && n.toInt() % 2 != 0) {
            return "subintervals must be even for Simpson's 1/3 Rule";
          }
          return null;
        },
      ),
    ],
  );

  /// Simpson's 3/8 Rule: Cubic numerical integration requiring subintervals divisible by 3.
  static final SolverMethodConfig simpson38 = SolverMethodConfig(
    id: 'simpson-38',
    name: "Simpson's 3/8 Rule",
    category: SolverCategory.integration,
    description:
        'Third-degree Newton-Cotes formula fitting cubic polynomials over groups of three subintervals (n must be divisible by 3).',
    endpoint: '/solve/integration/simpson-38',
    fields: const [
      _equationField,
      _lowerBoundField,
      _upperBoundField,
      SolverInputFieldConfig(
        name: 'subintervals',
        label: 'Subintervals (n)',
        type: SolverInputFieldType.integer,
        placeholder: 'e.g. 99',
        helperText:
            'Number of subintervals (3 to 9999, must be divisible by 3)',
        validation: SolverFieldValidation(
          minValue: 3,
          maxValue: 9999,
          mustBeDivisibleBy: 3,
        ),
      ),
      _exactValueField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [
      _boundsOrderedRule,
      SolverCrossFieldRule(
        id: 'subintervals.divisibleByThree',
        description:
            "subintervals must be divisible by 3 for Simpson's 3/8 Rule",
        affectedFieldNames: const ['subintervals'],
        validator: (values) {
          final n = values['subintervals'];
          if (n is num && n.toInt() % 3 != 0) {
            return "subintervals must be divisible by 3 for Simpson's 3/8 Rule";
          }
          return null;
        },
      ),
    ],
  );

  /// Gauss-Legendre Quadrature: Optimal node placement for high-order polynomial integration.
  static final SolverMethodConfig gaussLegendre = SolverMethodConfig(
    id: 'gauss-legendre',
    name: 'Gauss-Legendre Quadrature',
    category: SolverCategory.integration,
    description:
        'Gaussian quadrature using Legendre polynomial roots and weights (exact for polynomials up to degree 2n-1).',
    endpoint: '/solve/integration/gauss-legendre',
    fields: const [
      _equationField,
      _lowerBoundField,
      _upperBoundField,
      SolverInputFieldConfig(
        name: 'points',
        label: 'Quadrature Points (n)',
        type: SolverInputFieldType.select,
        defaultValue: 3,
        helperText: 'Number of evaluation nodes (2, 3, 4, or 5)',
        options: [
          SolverSelectOption(label: '2 Points', value: '2'),
          SolverSelectOption(label: '3 Points', value: '3'),
          SolverSelectOption(label: '4 Points', value: '4'),
          SolverSelectOption(label: '5 Points', value: '5'),
        ],
        validation: SolverFieldValidation(
          allowedValues: [2, 3, 4, 5, '2', '3', '4', '5'],
        ),
      ),
      _exactValueField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_boundsOrderedRule],
  );

  // ===========================================================================
  // 6. NUMERICAL DIFFERENTIATION SOLVERS (5)
  // ===========================================================================

  /// Forward Difference (Tabular): Finite difference derivative from discrete table.
  static final SolverMethodConfig forwardDifference = SolverMethodConfig(
    id: 'forward-difference',
    name: 'Forward Difference',
    category: SolverCategory.differentiation,
    description:
        "Two-point forward difference approximation f'(x) ~ [f(x+h) - f(x)] / h using discrete tabular data.",
    endpoint: '/solve/differentiation/forward',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Tabular Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 equally spaced points (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _exactDerivativeField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [
      _uniquePointsXRule,
      _equalSpacingXRule,
      SolverCrossFieldRule(
        id: 'differentiation.forwardStencil',
        description:
            'Target point x and forward point x+h must exist in the points list',
        affectedFieldNames: const ['points', 'targetX'],
        validator: (values) {
          final points = values['points'];
          final targetX = values['targetX'];
          if (points is List && points.length >= 2 && targetX is num) {
            final xList = <num>[];
            for (final pt in points) {
              if (pt is Map && pt['x'] is num) {
                xList.add(pt['x'] as num);
              }
            }
            xList.sort();
            final h = xList[1] - xList[0];
            final hasTarget = xList.any((x) => (x - targetX).abs() <= 1e-10);
            final hasNext = xList.any(
              (x) => (x - (targetX + h)).abs() <= 1e-10,
            );
            if (!hasTarget || !hasNext) {
              return 'target and next (x+h) points are required in points table';
            }
          }
          return null;
        },
      ),
    ],
  );

  /// Backward Difference (Tabular): Finite difference derivative looking backwards.
  static final SolverMethodConfig backwardDifference = SolverMethodConfig(
    id: 'backward-difference',
    name: 'Backward Difference',
    category: SolverCategory.differentiation,
    description:
        "Two-point backward difference approximation f'(x) ~ [f(x) - f(x-h)] / h using discrete tabular data.",
    endpoint: '/solve/differentiation/backward',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Tabular Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 equally spaced points (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _exactDerivativeField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [
      _uniquePointsXRule,
      _equalSpacingXRule,
      SolverCrossFieldRule(
        id: 'differentiation.backwardStencil',
        description:
            'Previous point x-h and target point x must exist in the points table',
        affectedFieldNames: const ['points', 'targetX'],
        validator: (values) {
          final points = values['points'];
          final targetX = values['targetX'];
          if (points is List && points.length >= 2 && targetX is num) {
            final xList = <num>[];
            for (final pt in points) {
              if (pt is Map && pt['x'] is num) {
                xList.add(pt['x'] as num);
              }
            }
            xList.sort();
            final h = xList[1] - xList[0];
            final hasPrev = xList.any(
              (x) => (x - (targetX - h)).abs() <= 1e-10,
            );
            final hasTarget = xList.any((x) => (x - targetX).abs() <= 1e-10);
            if (!hasPrev || !hasTarget) {
              return 'previous (x-h) and target points are required in points table';
            }
          }
          return null;
        },
      ),
    ],
  );

  /// Central Difference (Tabular): Symmetric O(h^2) finite difference derivative.
  static final SolverMethodConfig centralDifference = SolverMethodConfig(
    id: 'central-difference-tabular',
    name: 'Central Difference',
    category: SolverCategory.differentiation,
    description:
        "Symmetric second-order accurate finite difference f'(x) ~ [f(x+h) - f(x-h)] / (2h) from discrete table.",
    endpoint: '/solve/differentiation/central',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Tabular Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 3 equally spaced points (max 100)',
        validation: SolverFieldValidation(minItems: 3, maxItems: 100),
      ),
      _targetXField,
      _exactDerivativeField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [
      _uniquePointsXRule,
      _equalSpacingXRule,
      SolverCrossFieldRule(
        id: 'differentiation.centralStencil',
        description:
            'Previous point x-h and next point x+h must exist in the points table',
        affectedFieldNames: const ['points', 'targetX'],
        validator: (values) {
          final points = values['points'];
          final targetX = values['targetX'];
          if (points is List && points.length >= 3 && targetX is num) {
            final xList = <num>[];
            for (final pt in points) {
              if (pt is Map && pt['x'] is num) {
                xList.add(pt['x'] as num);
              }
            }
            xList.sort();
            final h = xList[1] - xList[0];
            final hasPrev = xList.any(
              (x) => (x - (targetX - h)).abs() <= 1e-10,
            );
            final hasNext = xList.any(
              (x) => (x - (targetX + h)).abs() <= 1e-10,
            );
            if (!hasPrev || !hasNext) {
              return 'previous (x-h) and next (x+h) points are required in points table';
            }
          }
          return null;
        },
      ),
    ],
  );

  /// Lagrange Differentiation: Differentiates the interpolating polynomial.
  static final SolverMethodConfig lagrangeDifferentiation = SolverMethodConfig(
    id: 'lagrange-differentiation',
    name: 'Lagrange Differentiation',
    category: SolverCategory.differentiation,
    description:
        'Differentiates the unique Lagrange interpolating polynomial through arbitrarily spaced tabular points.',
    endpoint: '/solve/differentiation/lagrange',
    fields: const [
      SolverInputFieldConfig(
        name: 'points',
        label: 'Tabular Points (x, y)',
        type: SolverInputFieldType.pointList,
        helperText: 'At least 2 points with unique x values (max 100)',
        validation: SolverFieldValidation(minItems: 2, maxItems: 100),
      ),
      _targetXField,
      _exactDerivativeField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
    crossFieldRules: [_uniquePointsXRule],
  );

  /// Function Finite Difference: Evaluates symbolic f(x) at target with step h.
  static const SolverMethodConfig functionFiniteDifference = SolverMethodConfig(
    id: 'function-finite-difference',
    name: 'Function Finite Difference',
    category: SolverCategory.differentiation,
    description:
        'Computes numerical derivative of an analytical equation f(x) at targetX using forward, backward, or central stencils.',
    endpoint: '/solve/differentiation/function-finite-difference',
    fields: [
      _equationField,
      _targetXField,
      SolverInputFieldConfig(
        name: 'h',
        label: 'Step Size (h)',
        type: SolverInputFieldType.number,
        placeholder: 'e.g. 0.001',
        helperText: 'Positive perturbation step size h > 0',
        validation: SolverFieldValidation(isPositive: true),
      ),
      SolverInputFieldConfig(
        name: 'variant',
        label: 'Difference Stencil',
        type: SolverInputFieldType.select,
        defaultValue: 'central',
        helperText: 'Finite difference scheme (forward, backward, central)',
        options: [
          SolverSelectOption(
            label: 'Central Difference (O(h^2))',
            value: 'central',
          ),
          SolverSelectOption(
            label: 'Forward Difference (O(h))',
            value: 'forward',
          ),
          SolverSelectOption(
            label: 'Backward Difference (O(h))',
            value: 'backward',
          ),
        ],
        validation: SolverFieldValidation(
          allowedValues: ['forward', 'backward', 'central'],
        ),
      ),
      _exactDerivativeField,
      _includeExplanationField,
      _includeGraphDataField,
    ],
  );

  // ===========================================================================
  // ALL 27 SOLVERS REGISTRY
  // ===========================================================================

  /// Immutable ordered list of all 27 numerical solvers supported by NumLab AI.
  static final List<SolverMethodConfig> all = List.unmodifiable([
    // Root Finding (4)
    bisection,
    newtonRaphson,
    secant,
    regulaFalsi,

    // Linear Systems (3)
    gaussElimination,
    jacobi,
    gaussSeidel,

    // Interpolation (7)
    lagrangeInterpolation,
    newtonDividedDifference,
    newtonForward,
    newtonBackward,
    centralDifferenceInterpolation,
    naturalCubicSpline,
    quadraticInterpolation,

    // Ordinary Differential Equations (4)
    euler,
    heun,
    rk4,
    milne,

    // Numerical Integration (4)
    trapezoidal,
    simpson13,
    simpson38,
    gaussLegendre,

    // Numerical Differentiation (5)
    forwardDifference,
    backwardDifference,
    centralDifference,
    lagrangeDifferentiation,
    functionFiniteDifference,
  ]);

  /// Lookup a solver method configuration by its ID or endpoint path.
  static SolverMethodConfig? getById(String id) {
    for (final config in all) {
      if (config.id == id ||
          config.endpoint == id ||
          config.endpoint == '/solve/$id') {
        return config;
      }
    }
    return null;
  }

  /// Returns all solver configurations belonging to a specific [category].
  static List<SolverMethodConfig> getByCategory(SolverCategory category) {
    return all.where((c) => c.category == category).toList(growable: false);
  }

  /// Lookup a solver method configuration by its exact API endpoint.
  static SolverMethodConfig? getByEndpoint(String endpoint) {
    for (final config in all) {
      if (config.endpoint == endpoint) {
        return config;
      }
    }
    return null;
  }
}
