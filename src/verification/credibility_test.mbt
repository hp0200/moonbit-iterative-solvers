///|
fn close_enough(left : Float, right : Float, tolerance : Float) -> Bool {
  Float::abs(left - right) <= tolerance
}

///|
test "credible verdict for a well-conditioned SPD system" {
  let matrix : Array[Array[Float]] = [[4.0, 1.0], [1.0, 3.0]]
  let b : Array[Float] = [6.0, 7.0]
  let x : Array[Float] = [1.000001, 2.000001]
  let report = @verification.verify_solution_with_credibility(matrix, b, x)
  assert_true(@verification.CredibilityVerdict::is_credible(report.verdict))
  assert_true(report.relative_residual <= @verification.verification_tolerance)
  assert_true(report.condition_estimate.estimable)
  assert_true(report.condition_estimate.is_well_conditioned)
  match report.error_upper_bound {
    Some(bound) => assert_true(bound > 0.0 && bound < 1.0e-3)
    None => abort("expected a numeric error upper bound for a credible verdict")
  }
  assert_true(report.reason.contains("well-conditioned"))
}

///|
test "ill-conditioned SPD is not credible from a tiny residual" {
  let matrix : Array[Array[Float]] = [[1.0, 0.0], [0.0, 1.0e-7]]
  let b : Array[Float] = [1.0, 1.0e-7]
  let x : Array[Float] = [1.0, 1.0]
  let report = @verification.verify_solution_with_credibility(matrix, b, x)
  assert_true(
    @verification.CredibilityVerdict::is_not_verifiable(report.verdict),
  )
  assert_true(report.condition_estimate.estimable)
  assert_true(report.condition_estimate.kappa > 1.0e6)
  assert_false(report.condition_estimate.is_well_conditioned)
  match report.error_upper_bound {
    Some(_) =>
      abort("an ill-conditioned system must not expose a credibility bound")
    None => ()
  }
}

///|
test "non-symmetric matrix is not verifiable from residual" {
  let matrix : Array[Array[Float]] = [[1.0, 2.0], [0.0, 1.0]]
  let b : Array[Float] = [3.0, 1.0]
  let x : Array[Float] = [1.0, 1.0]
  let report = @verification.verify_solution_with_credibility(matrix, b, x)
  assert_false(report.condition_estimate.estimable)
  assert_true(
    @verification.CredibilityVerdict::is_not_verifiable(report.verdict),
  )
  assert_true(report.reason.contains("non-symmetric"))
  assert_true(report.condition_estimate.kappa.is_inf())
}

///|
test "residual above tolerance is rejected" {
  let matrix : Array[Array[Float]] = [[2.0, 0.0], [0.0, 3.0]]
  let b : Array[Float] = [2.0, 3.0]
  let x : Array[Float] = [0.0, 0.0]
  let report = @verification.verify_solution_with_credibility(matrix, b, x)
  assert_true(@verification.CredibilityVerdict::is_rejected(report.verdict))
  assert_true(report.relative_residual > @verification.verification_tolerance)
  assert_false(report.condition_estimate.estimable)
  match report.error_upper_bound {
    Some(_) => abort("a rejected solution must not expose a credibility bound")
    None => ()
  }
}

///|
test "power iteration estimates known diagonal eigenvalues" {
  let matrix : Array[Array[Float]] = [[2.0, 0.0], [0.0, 5.0]]
  let estimate = @verification.estimate_condition_number(matrix)
  assert_true(estimate.estimable)
  assert_true(close_enough(estimate.lambda_max, 5.0, 1.0e-2))
  assert_true(close_enough(estimate.lambda_min, 2.0, 1.0e-2))
  assert_true(close_enough(estimate.kappa, 2.5, 1.0e-2))
  assert_true(estimate.iterations > 0)
  assert_true(estimate.is_well_conditioned)
}

///|
test "degenerate boundary inputs return a state without panicking" {
  let zero : Array[Array[Float]] = [[0.0, 0.0], [0.0, 0.0]]
  let zero_estimate = @verification.estimate_condition_number(zero)
  assert_false(zero_estimate.estimable)
  assert_true(zero_estimate.kappa.is_inf())
  let zero_report = @verification.verify_solution_with_credibility(
    zero,
    [0.0, 0.0],
    [0.0, 0.0],
  )
  assert_true(
    @verification.CredibilityVerdict::is_not_verifiable(zero_report.verdict),
  )

  let scalar : Array[Array[Float]] = [[4.0]]
  let scalar_estimate = @verification.estimate_condition_number(scalar)
  assert_true(scalar_estimate.estimable)
  assert_true(close_enough(scalar_estimate.kappa, 1.0, 1.0e-3))
  let scalar_report = @verification.verify_solution_with_credibility(
    scalar,
    [8.0],
    [2.0],
  )
  assert_true(
    @verification.CredibilityVerdict::is_credible(scalar_report.verdict),
  )

  let nan_matrix : Array[Array[Float]] = [
    [Float::reinterpret_from_int(0x7FC00000), 0.0],
    [0.0, 1.0],
  ]
  let nan_estimate = @verification.estimate_condition_number(nan_matrix)
  assert_false(nan_estimate.estimable)
  let nan_report = @verification.verify_solution_with_credibility(
    nan_matrix,
    [1.0, 1.0],
    [1.0, 1.0],
  )
  assert_true(
    @verification.CredibilityVerdict::is_not_verifiable(nan_report.verdict),
  )
}
