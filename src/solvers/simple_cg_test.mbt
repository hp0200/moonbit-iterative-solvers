///|
test "solve converges on a small SPD system and passes independent verification" {
  let matrix : Array[Array[Float]] = [[4.0, 1.0], [1.0, 3.0]]
  let b : Array[Float] = [6.0, 7.0]
  match @solvers.solve(matrix, b) {
    Ok(x) => {
      let report = @verification.verify_solution(matrix, b, x)
      assert_true(report.is_valid)
      assert_true(report.residual_norm <= @verification.verification_tolerance)
    }
    Err(diagnostic) =>
      abort(
        "expected convergence, got \{@diagnostics.SolverDiagnostic::error_code(diagnostic)}",
      )
  }
}

///|
test "solve returns SINGULAR_PIVOT for a zero matrix" {
  let matrix : Array[Array[Float]] = [[0.0, 0.0], [0.0, 0.0]]
  let b : Array[Float] = [1.0, 2.0]
  match @solvers.solve(matrix, b) {
    Ok(_) => abort("expected a singular pivot diagnostic")
    Err(diagnostic) =>
      assert_eq(
        @diagnostics.SolverDiagnostic::error_code(diagnostic),
        "SINGULAR_PIVOT",
      )
  }
}

///|
test "solve returns DIMENSION_MISMATCH for the wrong right-hand side" {
  let matrix : Array[Array[Float]] = [[2.0, 0.0], [0.0, 3.0]]
  match @solvers.solve(matrix, [1.0]) {
    Ok(_) => abort("expected a dimension diagnostic")
    Err(diagnostic) =>
      assert_eq(
        @diagnostics.SolverDiagnostic::error_code(diagnostic),
        "DIMENSION_MISMATCH",
      )
  }
}

///|
test "solve returns NON_FINITE_INPUT for NaNs" {
  let matrix : Array[Array[Float]] = [
    [Float::reinterpret_from_int(0x7FC00000), 0.0],
    [0.0, 1.0],
  ]
  match @solvers.solve(matrix, [1.0, 2.0]) {
    Ok(_) => abort("expected a non-finite input diagnostic")
    Err(diagnostic) =>
      assert_eq(
        @diagnostics.SolverDiagnostic::error_code(diagnostic),
        "NON_FINITE_INPUT",
      )
  }
}

///|
test "solve returns NON_SQUARE_MATRIX for rectangular input" {
  let matrix : Array[Array[Float]] = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]]
  match @solvers.solve(matrix, [1.0, 2.0]) {
    Ok(_) => abort("expected a non-square diagnostic")
    Err(diagnostic) =>
      assert_eq(
        @diagnostics.SolverDiagnostic::error_code(diagnostic),
        "NON_SQUARE_MATRIX",
      )
  }
}
