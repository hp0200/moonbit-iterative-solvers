///|
fn expect_bicgstab_error(
  result : Result[@solvers.SolverOutcome, @solvers.SolverError],
  expected : @solvers.SolverError,
) -> Unit raise {
  match result {
    Err(error) => assert_eq(error, expected)
    Ok(_) => fail("expected BiCGSTAB to return \{expected.description()}")
  }
}

///|
test "BiCGSTAB solves a non-symmetric system against a reference solution" {
  let a = @sparse.from_dense(
    [[4.0, 1.0, 0.0], [2.0, 3.0, 1.0], [0.0, 1.0, 2.0]],
    0.0,
  )
  let b = [6.0, 7.0, 0.0]
  let original_b = [6.0, 7.0, 0.0]
  let outcome = @solvers.bicgstab_solve(a, b, 1.0e-12, 30, @precond.None).unwrap()
  assert_vector_close(outcome.x, [1.0, 2.0, -1.0], 1.0e-9)
  let ax = @sparse.spmv(a, outcome.x).unwrap()
  let residual = Array::make(3, 0.0)
  for i = 0; i < 3; i = i + 1 {
    residual[i] = b[i] - ax[i]
  }
  assert_true(@algebra.norm_real(residual) <= 1.0e-12 * @algebra.norm_real(b))
  assert_eq(b, original_b)
}

///|
test "BiCGSTAB reports Breakdown when the shadow rho becomes zero" {
  let a = @sparse.from_dense(
    [[-2.0, -2.0, -2.0], [-2.0, -2.0, -1.0], [-2.0, 1.0, -1.0]],
    0.0,
  )
  expect_bicgstab_error(
    @solvers.bicgstab_solve(a, [-1.0, 1.0, 1.0], 1.0e-12, 10, @precond.None),
    @solvers.Breakdown,
  )
}

///|
test "BiCGSTAB returns DimensionMismatch for a short right-hand side" {
  let a = @sparse.from_dense([[2.0, 0.0], [0.0, 3.0]], 0.0)
  expect_bicgstab_error(
    @solvers.bicgstab_solve(a, [2.0], 1.0e-12, 10, @precond.None),
    @solvers.DimensionMismatch,
  )
}
