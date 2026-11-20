///|
#derive(Eq, Debug)
pub(all) enum SolverError {
  DimensionMismatch
  MaxIterExceeded
  Breakdown
  ZeroDiagonal
}

///|
pub fn SolverError::dimension_mismatch_reason() -> String {
  "DimensionMismatch: the right-hand side length is not the CSR row count."
}

///|
pub fn SolverError::max_iter_exceeded_reason() -> String {
  "MaxIterExceeded: the tolerance was not met before max_iter iterations."
}

///|
pub fn SolverError::breakdown_reason() -> String {
  "Breakdown: a required inner product or safe division became zero."
}

///|
pub fn SolverError::zero_diagonal_reason() -> String {
  "ZeroDiagonal: a Jacobi row has no diagonal entry or its diagonal is zero."
}

///|
pub fn SolverError::description(self : SolverError) -> String {
  match self {
    DimensionMismatch => SolverError::dimension_mismatch_reason()
    MaxIterExceeded => SolverError::max_iter_exceeded_reason()
    Breakdown => SolverError::breakdown_reason()
    ZeroDiagonal => SolverError::zero_diagonal_reason()
  }
}
