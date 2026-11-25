///|
/// Default relative residual threshold used by `verify_solution`.
pub let verification_tolerance : Float = 1.0e-5

///|
/// Independent quality report for an approximate solution.
///
/// `relative_error` is `||b - Ax|| / ||b||`, using `||b - Ax||` directly when
/// `b` is the zero vector. All fields are finite for validly shaped, finite
/// inputs.
pub struct VerificationReport {
  residual_norm : Float
  relative_error : Float
  is_valid : Bool
}

///|
pub fn VerificationReport::new(
  residual_norm : Float,
  relative_error : Float,
  is_valid : Bool,
) -> VerificationReport {
  { residual_norm, relative_error, is_valid, }
}

///|
fn positive_infinity() -> Float {
  Float::reinterpret_from_int(0x7F800000)
}

///|
fn is_finite(value : Float) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn invalid_report() -> VerificationReport {
  let infinity = positive_infinity()
  VerificationReport::new(infinity, infinity, false)
}

///|
fn validate_inputs(
  matrix : Array[Array[Float]],
  b : Array[Float],
  x : Array[Float],
) -> Result[Unit, @diagnostics.SolverDiagnostic] {
  let n = matrix.length()
  if n == 0 {
    return Err(@diagnostics.empty_system())
  }
  let columns = matrix[0].length()
  for i = 0; i < n; i = i + 1 {
    let row = matrix[i]
    if row.length() != columns {
      return Err(@diagnostics.ragged_matrix(i, columns, row.length()))
    }
    for j = 0; j < columns; j = j + 1 {
      if !is_finite(row[j]) {
        return Err(@diagnostics.non_finite_input("matrix", i, j))
      }
    }
  }
  if columns != n {
    return Err(@diagnostics.non_square_matrix(n, columns))
  }
  if b.length() != n {
    return Err(
      @diagnostics.invalid_dimension(n, b.length(), "right-hand side (b)"),
    )
  }
  if x.length() != n {
    return Err(@diagnostics.invalid_dimension(n, x.length(), "solution (x)"))
  }
  for i = 0; i < n; i = i + 1 {
    if !is_finite(b[i]) {
      return Err(@diagnostics.non_finite_input("right-hand side", i, -1))
    }
    if !is_finite(x[i]) {
      return Err(@diagnostics.non_finite_input("solution", i, -1))
    }
  }
  Ok(())
}

///|
fn stable_norm(values : Array[Float]) -> Float {
  let mut scale : Float = 0.0
  let mut sum_squares : Float = 1.0
  for value in values {
    let magnitude = Float::abs(value)
    if magnitude != 0.0 {
      if scale < magnitude {
        let ratio = scale / magnitude
        sum_squares = 1.0 + sum_squares * ratio * ratio
        scale = magnitude
      } else {
        let ratio = magnitude / scale
        sum_squares = sum_squares + ratio * ratio
      }
    }
  }
  if scale == 0.0 {
    0.0
  } else {
    scale * Float::sqrt(sum_squares)
  }
}

///|
fn accumulate_norm(
  scale : Float,
  sum_squares : Float,
  value : Float,
) -> (Float, Float) {
  let magnitude = Float::abs(value)
  if magnitude == 0.0 {
    (scale, sum_squares)
  } else if scale < magnitude {
    let ratio = scale / magnitude
    (magnitude, 1.0 + sum_squares * ratio * ratio)
  } else {
    let ratio = magnitude / scale
    (scale, sum_squares + ratio * ratio)
  }
}

///|
fn finish_norm(scale : Float, sum_squares : Float) -> Float {
  if scale == 0.0 {
    0.0
  } else {
    scale * Float::sqrt(sum_squares)
  }
}

///|
fn make_report(residual_norm : Float, rhs_norm : Float) -> VerificationReport {
  let denominator_floor : Float = 1.0e-30
  let relative_error = if rhs_norm > denominator_floor {
    residual_norm / rhs_norm
  } else {
    residual_norm
  }
  let is_valid = is_finite(relative_error) &&
    relative_error <= verification_tolerance
  VerificationReport::new(residual_norm, relative_error, is_valid)
}

///|
/// Verify an approximate solution without consulting any solver internals.
///
/// The residual is recomputed as `r = b - Ax`. Malformed or non-finite inputs
/// produce an invalid report instead of a panic. Use
/// `verify_solution_with_diagnostic` when the failure reason is needed.
pub fn verify_solution(
  matrix : Array[Array[Float]],
  b : Array[Float],
  x : Array[Float],
) -> VerificationReport {
  match verify_solution_with_diagnostic(matrix, b, x) {
    Ok(report) => report
    Err(_) => invalid_report()
  }
}

///|
/// Detailed verification entry that explains why a report is invalid.
pub fn verify_solution_with_diagnostic(
  matrix : Array[Array[Float]],
  b : Array[Float],
  x : Array[Float],
) -> Result[VerificationReport, @diagnostics.SolverDiagnostic] {
  match validate_inputs(matrix, b, x) {
    Err(diagnostic) => return Err(diagnostic)
    Ok(_) => ()
  }
  let n = matrix.length()
  let rhs_norm = stable_norm(b)
  let mut scale : Float = 0.0
  let mut sum_squares : Float = 1.0
  for i = 0; i < n; i = i + 1 {
    let row = matrix[i]
    let mut product : Float = 0.0
    for j = 0; j < n; j = j + 1 {
      product = product + row[j] * x[j]
    }
    let residual = b[i] - product
    if !is_finite(residual) {
      return Err(@diagnostics.non_finite_residual(i, positive_infinity()))
    }
    let next = accumulate_norm(scale, sum_squares, residual)
    scale = next.0
    sum_squares = next.1
  }
  let residual_norm = finish_norm(scale, sum_squares)
  if !is_finite(residual_norm) || !is_finite(rhs_norm) {
    return Err(@diagnostics.non_finite_residual(n, residual_norm))
  }
  Ok(make_report(residual_norm, rhs_norm))
}
