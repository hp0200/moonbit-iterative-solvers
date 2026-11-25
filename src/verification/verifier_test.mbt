///|
test "verify_solution accepts a solution with small residual" {
  let matrix : Array[Array[Float]] = [[4.0, 1.0], [1.0, 3.0]]
  let b : Array[Float] = [6.0, 7.0]
  let x : Array[Float] = [1.0, 2.0]
  let report = @verification.verify_solution(matrix, b, x)
  assert_true(report.is_valid)
  assert_true(report.residual_norm <= @verification.verification_tolerance)
}

///|
test "verify_solution rejects an incorrect solution" {
  let matrix : Array[Array[Float]] = [[4.0, 1.0], [1.0, 3.0]]
  let b : Array[Float] = [6.0, 7.0]
  let x : Array[Float] = [0.0, 0.0]
  let report = @verification.verify_solution(matrix, b, x)
  assert_false(report.is_valid)
  assert_true(report.residual_norm > 0.0)
}

///|
test "verify_solution reports malformed input without panicking" {
  let matrix : Array[Array[Float]] = [[1.0, 0.0], [0.0, 1.0]]
  let report = @verification.verify_solution(matrix, [1.0], [1.0, 1.0])
  assert_false(report.is_valid)
  assert_true(report.residual_norm.is_inf())
  match
    @verification.verify_solution_with_diagnostic(matrix, [1.0], [1.0, 1.0]) {
    Err(diagnostic) =>
      assert_eq(
        @diagnostics.SolverDiagnostic::error_code(diagnostic),
        "DIMENSION_MISMATCH",
      )
    Ok(_) => abort("expected a dimension diagnostic")
  }
}

///|
test "verify_solution rejects NaN input without panicking" {
  let matrix : Array[Array[Float]] = [[1.0, 0.0], [0.0, 1.0]]
  let b : Array[Float] = [1.0, 2.0]
  let x : Array[Float] = [Float::reinterpret_from_int(0x7FC00000), 2.0]
  let report = @verification.verify_solution(matrix, b, x)
  assert_false(report.is_valid)
  assert_true(report.residual_norm.is_inf())
}

///|
test "verify_solution handles a matrix with fewer columns than rows" {
  let matrix : Array[Array[Float]] = [[1.0], [2.0]]
  let report = @verification.verify_solution(matrix, [1.0, 2.0], [1.0, 1.0])
  assert_false(report.is_valid)
  match
    @verification.verify_solution_with_diagnostic(matrix, [1.0, 2.0], [1.0, 1.0]) {
    Err(diagnostic) =>
      assert_eq(
        @diagnostics.SolverDiagnostic::error_code(diagnostic),
        "NON_SQUARE_MATRIX",
      )
    Ok(_) => abort("expected a non-square diagnostic")
  }
}
