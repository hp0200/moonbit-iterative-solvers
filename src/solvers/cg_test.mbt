///|
fn assert_close(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Unit raise {
  assert_true(
    Double::abs(actual - expected) <= tolerance,
    msg="expected \{expected}, got \{actual}",
  )
}

///|
fn assert_vector_close(
  actual : Array[Double],
  expected : Array[Double],
  tolerance : Double,
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i = 0; i < actual.length(); i = i + 1 {
    assert_close(actual[i], expected[i], tolerance)
  }
}

///|
fn expect_cg_error(
  result : Result[@solvers.SolverOutcome, @solvers.SolverError],
  expected : @solvers.SolverError,
) -> Unit raise {
  match result {
    Err(error) => assert_eq(error, expected)
    Ok(_) => fail("expected CG to return \{expected.description()}")
  }
}

///|
test "CG solves a 3x3 SPD system and satisfies the residual bound" {
  let a = @sparse.from_dense(
    [[4.0, 1.0, 0.0], [1.0, 3.0, 1.0], [0.0, 1.0, 2.0]],
    0.0,
  )
  let b = [6.0, 10.0, 8.0]
  let original_b = [6.0, 10.0, 8.0]
  let outcome = @solvers.cg_solve(a, b, 1.0e-12, 20, @precond.None).unwrap()
  assert_vector_close(outcome.x, [1.0, 2.0, 3.0], 1.0e-9)
  let ax = @sparse.spmv(a, outcome.x).unwrap()
  let residual = Array::make(3, 0.0)
  for i = 0; i < 3; i = i + 1 {
    residual[i] = b[i] - ax[i]
  }
  assert_true(@algebra.norm_real(residual) <= 1.0e-12 * @algebra.norm_real(b))
  assert_eq(b, original_b)
}

///|
test "CG returns DimensionMismatch for a short right-hand side" {
  let a = @sparse.from_dense([[2.0, 0.0], [0.0, 3.0]], 0.0)
  expect_cg_error(
    @solvers.cg_solve(a, [2.0], 1.0e-12, 10, @precond.None),
    @solvers.DimensionMismatch,
  )
}

///|
test "CG reports Breakdown for a singular zero-curvature direction" {
  let singular = @sparse.from_dense([[1.0, 1.0], [1.0, 1.0]], 0.0)
  expect_cg_error(
    @solvers.cg_solve(singular, [1.0, -1.0], 1.0e-12, 10, @precond.None),
    @solvers.Breakdown,
  )
}

///|
test "CG reaches MaxIterExceeded when the residual contains NaN" {
  let identity = @sparse.from_dense(
    [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
    0.0,
  )
  let nan = 0.0 / 0.0
  expect_cg_error(
    @solvers.cg_solve(identity, [nan, 1.0, 0.0], 1.0e-12, 3, @precond.None),
    @solvers.MaxIterExceeded,
  )
}

///|
test "CG Jacobi uses no more iterations than unpreconditioned CG" {
  let a = @sparse.from_dense(
    [
      [10.0, 1.0, 0.0, 0.0],
      [1.0, 12.0, 1.0, 0.0],
      [0.0, 1.0, 14.0, 1.0],
      [0.0, 0.0, 1.0, 16.0],
    ],
    0.0,
  )
  let b = [11.0, 14.0, 16.0, 17.0]
  let plain = @solvers.cg_solve(a, b, 1.0e-10, 50, @precond.None).unwrap()
  let jacobi = @solvers.cg_solve(a, b, 1.0e-10, 50, @precond.Jacobi).unwrap()
  assert_true(jacobi.iterations <= plain.iterations)
  assert_vector_close(jacobi.x, plain.x, 1.0e-8)
}

///|
test "CG Jacobi returns ZeroDiagonal when a diagonal is unavailable" {
  let missing = @sparse.from_dense([[0.0, 1.0], [1.0, 2.0]], 0.0)
  expect_cg_error(
    @solvers.cg_solve(missing, [1.0, 3.0], 1.0e-12, 10, @precond.Jacobi),
    @solvers.ZeroDiagonal,
  )
}
