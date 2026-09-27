/// Supported input field types for solver forms.
enum SolverInputFieldType {
  /// Mathematical expression string (e.g. "x^3 - x - 2" or "x + y").
  equation,

  /// Floating-point real number (e.g. bounds, step sizes, targets).
  number,

  /// Integer value (e.g. iteration limits, subinterval counts).
  integer,

  /// Boolean toggle / checkbox (e.g. includeExplanation, includeGraphData).
  boolean,

  /// Single-select dropdown from predefined options.
  select,

  /// 2D square matrix of numbers (`List<List<num>>`).
  matrix,

  /// 1D vector of numbers (`List<num>`).
  vector,

  /// List of 2D coordinates (`List<Map<String, num>>` or List of Points).
  pointList,
}
