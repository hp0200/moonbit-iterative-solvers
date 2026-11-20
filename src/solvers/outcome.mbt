///|
pub struct SolverOutcome {
  x : Array[Double]
  iterations : Int32
  final_residual : Double
}

///|
pub fn SolverOutcome::new(
  x : Array[Double],
  iterations : Int32,
  final_residual : Double,
) -> SolverOutcome {
  SolverOutcome::{ x, iterations, final_residual, }
}

///|
pub fn SolverOutcome::dimension(self : SolverOutcome) -> Int32 {
  self.x.length()
}

///|
pub fn SolverOutcome::within_tolerance(
  self : SolverOutcome,
  tol : Double,
  rhs_norm : Double,
) -> Bool {
  self.final_residual <= tol * rhs_norm
}

///|
pub fn SolverOutcome::used_at_least_one_iteration(self : SolverOutcome) -> Bool {
  self.iterations > 0
}

///|
pub fn SolverOutcome::residual_ratio(
  self : SolverOutcome,
  rhs_norm : Double,
) -> Double {
  if rhs_norm == 0.0 {
    self.final_residual
  } else {
    self.final_residual / rhs_norm
  }
}
