///|
test "diagnostic exposes stable fields and context" {
  let diagnostic = @diagnostics.singular_pivot(3, 0.0)
  assert_eq(
    @diagnostics.SolverDiagnostic::error_code(diagnostic),
    "SINGULAR_PIVOT",
  )
  assert_eq(
    @diagnostics.SolverDiagnostic::context_value(diagnostic, "iteration_count"),
    Some("3"),
  )
  assert_eq(
    @diagnostics.SolverDiagnostic::context_value(diagnostic, "pivot"),
    Some("0"),
  )
  assert_true(
    @diagnostics.SolverDiagnostic::agent_hint(diagnostic).length() > 0,
  )
}

///|
test "diagnostic context is structured key-value data" {
  let diagnostic = @diagnostics.invalid_dimension(3, 2, "right-hand side (b)")
  assert_eq(
    @diagnostics.SolverDiagnostic::error_code(diagnostic),
    "DIMENSION_MISMATCH",
  )
  assert_eq(
    @diagnostics.SolverDiagnostic::context_value(diagnostic, "expected_length"),
    Some("3"),
  )
  assert_eq(
    @diagnostics.SolverDiagnostic::context_value(diagnostic, "actual_length"),
    Some("2"),
  )
}
