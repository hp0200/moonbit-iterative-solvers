///|
/// Structured numerical diagnostic returned to the caller instead of a panic.
///
/// `error_code` is stable and machine-readable, `message` explains the failure,
/// `agent_hint` suggests a recovery action for an AI agent, and `context`
/// carries extensible key-value evidence such as matrix size or iteration count.
pub(all) enum SolverDiagnostic {
  Report(
    error_code~ : String,
    message~ : String,
    agent_hint~ : String,
    context~ : Map[String, String]
  )
}

///|
pub fn SolverDiagnostic::new(
  error_code : String,
  message : String,
  agent_hint : String,
  context : Map[String, String],
) -> SolverDiagnostic {
  Report(error_code~, message~, agent_hint~, context~)
}

///|
pub fn SolverDiagnostic::error_code(self : SolverDiagnostic) -> String {
  match self {
    Report(error_code~, ..) => error_code
  }
}

///|
pub fn SolverDiagnostic::message(self : SolverDiagnostic) -> String {
  match self {
    Report(message~, ..) => message
  }
}

///|
pub fn SolverDiagnostic::agent_hint(self : SolverDiagnostic) -> String {
  match self {
    Report(agent_hint~, ..) => agent_hint
  }
}

///|
pub fn SolverDiagnostic::context(
  self : SolverDiagnostic,
) -> Map[String, String] {
  match self {
    Report(context~, ..) => context
  }
}

///|
pub fn SolverDiagnostic::context_value(
  self : SolverDiagnostic,
  key : String,
) -> String? {
  SolverDiagnostic::context(self).get(key)
}

///|
fn with_value(
  key : String,
  value : String,
  context : Map[String, String],
) -> Map[String, String] {
  context.set(key, value)
  context
}

///|
pub fn empty_context() -> Map[String, String] {
  Map([])
}

///|
pub fn empty_system() -> SolverDiagnostic {
  SolverDiagnostic::new(
    "EMPTY_SYSTEM",
    "The linear system is empty; there is no equation to solve.",
    "Provide at least one row in the matrix and one entry in the right-hand side.",
    with_value("matrix_size", "0", empty_context()),
  )
}

///|
pub fn non_square_matrix(rows : Int32, columns : Int32) -> SolverDiagnostic {
  SolverDiagnostic::new(
    "NON_SQUARE_MATRIX",
    "The coefficient matrix is not square.",
    "Check the matrix shape; a square system requires rows == columns.",
    with_value(
      "matrix_size",
      "\{rows}x\{columns}",
      with_value(
        "rows",
        rows.to_string(),
        with_value("columns", columns.to_string(), empty_context()),
      ),
    ),
  )
}

///|
pub fn invalid_dimension(
  expected : Int32,
  actual : Int32,
  vector_name : String,
) -> SolverDiagnostic {
  let context = with_value(
    "expected_length",
    expected.to_string(),
    empty_context(),
  )
  let context = with_value("actual_length", actual.to_string(), context)
  SolverDiagnostic::new(
    "DIMENSION_MISMATCH",
    "The \{vector_name} length does not match the matrix size.",
    "Resize the \{vector_name} to the matrix dimension, then retry verification or solving.",
    with_value("vector", vector_name, context),
  )
}

///|
pub fn ragged_matrix(
  row : Int32,
  expected : Int32,
  actual : Int32,
) -> SolverDiagnostic {
  let context = with_value("row", row.to_string(), empty_context())
  let context = with_value("expected_length", expected.to_string(), context)
  SolverDiagnostic::new(
    "RAGGED_MATRIX",
    "A matrix row has a different length from the first row.",
    "Normalize every matrix row to the same column count before numeric work.",
    with_value("actual_length", actual.to_string(), context),
  )
}

///|
pub fn non_finite_input(
  location : String,
  row : Int32,
  column : Int32,
) -> SolverDiagnostic {
  let context = with_value("location", location, empty_context())
  let context = with_value("row", row.to_string(), context)
  SolverDiagnostic::new(
    "NON_FINITE_INPUT",
    "The input contains NaN or infinity.",
    "Reject or sanitize non-finite values before calling numerical routines.",
    with_value("column", column.to_string(), context),
  )
}

///|
pub fn invalid_tolerance(tolerance : Float) -> SolverDiagnostic {
  SolverDiagnostic::new(
    "INVALID_TOLERANCE",
    "The tolerance must be finite and non-negative.",
    "Use a small finite non-negative tolerance, for example 1.0e-6.",
    with_value("tolerance", tolerance.to_string(), empty_context()),
  )
}

///|
pub fn invalid_max_iterations(max_iterations : Int32) -> SolverDiagnostic {
  SolverDiagnostic::new(
    "INVALID_MAX_ITERATIONS",
    "The iteration limit must be positive.",
    "Set max_iterations to a positive integer and retry.",
    with_value("max_iterations", max_iterations.to_string(), empty_context()),
  )
}

///|
pub fn singular_pivot(iteration : Int32, pivot : Float) -> SolverDiagnostic {
  let context = with_value(
    "iteration_count",
    iteration.to_string(),
    empty_context(),
  )
  SolverDiagnostic::new(
    "SINGULAR_PIVOT",
    "Conjugate-gradient search broke down because the pivot is zero, negative, or non-finite.",
    "The matrix may be singular or not symmetric positive definite; inspect the input or use a direct method.",
    with_value("pivot", pivot.to_string(), context),
  )
}

///|
pub fn cg_breakdown(iteration : Int32, phase : String) -> SolverDiagnostic {
  let context = with_value(
    "iteration_count",
    iteration.to_string(),
    empty_context(),
  )
  SolverDiagnostic::new(
    "BREAKDOWN",
    "The conjugate-gradient recurrence produced a non-finite value.",
    "Check scaling and input conditioning, or use a more robust solver.",
    with_value("phase", phase, context),
  )
}

///|
pub fn max_iter_exceeded(
  iterations : Int32,
  tolerance : Float,
  residual_norm : Float,
) -> SolverDiagnostic {
  let context = with_value(
    "iteration_count",
    iterations.to_string(),
    empty_context(),
  )
  let context = with_value("tolerance", tolerance.to_string(), context)
  SolverDiagnostic::new(
    "MAX_ITER_EXCEEDED",
    "The solver reached its iteration limit before satisfying the tolerance.",
    "Increase the iteration limit, improve scaling, or verify that the matrix meets CG assumptions.",
    with_value("residual_norm", residual_norm.to_string(), context),
  )
}

///|
pub fn non_finite_residual(
  iteration : Int32,
  residual_norm : Float,
) -> SolverDiagnostic {
  let context = with_value(
    "iteration_count",
    iteration.to_string(),
    empty_context(),
  )
  SolverDiagnostic::new(
    "NON_FINITE_RESIDUAL",
    "The residual norm became NaN or infinity.",
    "Reject the current iterate; inspect input magnitudes and rescale the system.",
    with_value("residual_norm", residual_norm.to_string(), context),
  )
}
