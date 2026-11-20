///|
test "solver outcome reports dimensions and iteration metadata" {
  let outcome = @solvers.SolverOutcome::new([1.0, 2.0, 3.0], 4, 1.0e-10)
  assert_eq(outcome.dimension(), 3)
  assert_eq(outcome.iterations, 4)
  assert_eq(outcome.final_residual, 1.0e-10)
  assert_true(outcome.used_at_least_one_iteration())
}

///|
test "solver outcome tolerance uses the IEEE less-than-or-equal comparison" {
  let converged = @solvers.SolverOutcome::new([1.0], 1, 5.0e-7)
  assert_true(converged.within_tolerance(1.0e-6, 1.0))
  let not_converged = @solvers.SolverOutcome::new([1.0], 1, 2.0e-6)
  assert_false(not_converged.within_tolerance(1.0e-6, 1.0))
  let nan = @solvers.SolverOutcome::new([1.0], 10, 0.0 / 0.0)
  assert_false(nan.within_tolerance(1.0e-6, 1.0))
}

///|
test "solver outcome residual ratio handles zero right-hand side norms" {
  let outcome = @solvers.SolverOutcome::new([0.0], 0, 0.0)
  assert_eq(outcome.residual_ratio(2.0), 0.0)
  assert_eq(outcome.residual_ratio(0.0), 0.0)
}
