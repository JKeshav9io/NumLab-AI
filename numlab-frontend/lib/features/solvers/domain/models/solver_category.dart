/// Enum representing the 6 mathematical categories of numerical solvers.
enum SolverCategory {
  /// Root-finding methods for nonlinear equations f(x) = 0.
  rootFinding(
    id: 'root-finding',
    displayName: 'Root Finding',
    description:
        'Algorithms for locating real roots of nonlinear equations f(x) = 0.',
  ),

  /// Linear system solvers for Ax = b.
  linearAlgebra(
    id: 'linear-algebra',
    displayName: 'Linear Systems',
    description:
        'Direct elimination and iterative solvers for systems of linear equations Ax = b.',
  ),

  /// Interpolation and curve fitting methods.
  interpolation(
    id: 'interpolation',
    displayName: 'Interpolation',
    description:
        'Polynomial, spline, and central-difference interpolation through discrete data points.',
  ),

  /// Ordinary differential equation initial value problem solvers.
  ode(
    id: 'ode',
    displayName: 'Differential Equations',
    description:
        'Single-step and multi-step initial value problem numerical ODE solvers.',
  ),

  /// Definite numerical integration methods.
  integration(
    id: 'integration',
    displayName: 'Numerical Integration',
    description:
        'Newton-Cotes formulas and Gaussian quadrature for approximating definite integrals.',
  ),

  /// Numerical differentiation approximations.
  differentiation(
    id: 'differentiation',
    displayName: 'Numerical Differentiation',
    description:
        'Finite difference approximations and polynomial differentiation for tabular data and functions.',
  );

  const SolverCategory({
    required this.id,
    required this.displayName,
    required this.description,
  });

  /// The unique string identifier for the category.
  final String id;

  /// The human-readable display title for UI headers and tabs.
  final String displayName;

  /// Detailed description of the mathematical domain.
  final String description;

  /// Resolves a [SolverCategory] from its string [id], or null if not found.
  static SolverCategory? fromId(String id) {
    for (final category in SolverCategory.values) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}
