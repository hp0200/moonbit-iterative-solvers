///|
/// Relative residual tolerance used by `solve`.
pub let cg_tolerance : Float = 1.0e-5

///|
/// Iteration budget used by `solve` when no convergence is observed.
pub let cg_max_iterations : Int32 = 1000

///|
fn positive_infinity() -> Float {
  Float::reinterpret_from_int(0x7F800000)
}

///|
fn is_finite(value : Float) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn validate_problem(
  matrix : Array[Array[Float]],
  b : Array[Float],
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
  for i = 0; i < n; i = i + 1 {
    if !is_finite(b[i]) {
      return Err(@diagnostics.non_finite_input("right-hand side", i, -1))
    }
  }
  Ok(())
}

///|
fn dot(left : Array[Float], right : Array[Float]) -> Float {
  let mut total : Float = 0.0
  for i = 0; i < left.length(); i = i + 1 {
    total = total + left[i] * right[i]
  }
  total
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
fn matvec(matrix : Array[Array[Float]], vector : Array[Float]) -> Array[Float] {
  let n = matrix.length()
  let product : Array[Float] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    let row = matrix[i]
    let mut total : Float = 0.0
    for j = 0; j < n; j = j + 1 {
      total = total + row[j] * vector[j]
    }
    product[i] = total
  }
  product
}

///|
fn all_finite(values : Array[Float]) -> Bool {
  for value in values {
    if !is_finite(value) {
      return false
    }
  }
  true
}

///|
/// Solve a small symmetric positive-definite system with conjugate gradients.
///
/// This is a deliberately compact reference implementation: it accepts dense
/// rows, uses a fixed tolerance (`cg_tolerance`), and stops after
/// `cg_max_iterations`. Numerical failure is returned as a structured
/// diagnostic; the function never panics and never returns a non-finite
/// solution.
pub fn solve(
  matrix : Array[Array[Float]],
  b : Array[Float],
) -> Result[Array[Float], @diagnostics.SolverDiagnostic] {
  match validate_problem(matrix, b) {
    Err(diagnostic) => return Err(diagnostic)
    Ok(_) => ()
  }
  let n = matrix.length()
  let x : Array[Float] = Array::make(n, 0.0)
  let residual : Array[Float] = Array::make(n, 0.0)
  let direction : Array[Float] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    residual[i] = b[i]
    direction[i] = b[i]
  }
  let rhs_norm = stable_norm(b)
  let initial_residual_norm = stable_norm(residual)
  if !is_finite(initial_residual_norm) || !is_finite(rhs_norm) {
    return Err(@diagnostics.non_finite_residual(0, initial_residual_norm))
  }
  if initial_residual_norm <= cg_tolerance * rhs_norm {
    return Ok(x)
  }
  let mut residual_squared = dot(residual, residual)
  if !is_finite(residual_squared) {
    return Err(@diagnostics.cg_breakdown(0, "initial residual inner product"))
  }
  for iteration = 0; iteration < cg_max_iterations; iteration = iteration + 1 {
    let product = matvec(matrix, direction)
    if !all_finite(product) {
      return Err(@diagnostics.cg_breakdown(iteration, "matrix-vector product"))
    }
    let curvature = dot(direction, product)
    if !is_finite(curvature) {
      return Err(@diagnostics.singular_pivot(iteration, curvature))
    }
    if curvature <= 0.0 {
      return Err(@diagnostics.singular_pivot(iteration, curvature))
    }
    let alpha = residual_squared / curvature
    if !is_finite(alpha) {
      return Err(@diagnostics.cg_breakdown(iteration, "step size"))
    }
    for i = 0; i < n; i = i + 1 {
      x[i] = x[i] + alpha * direction[i]
      residual[i] = residual[i] - alpha * product[i]
    }
    if !all_finite(x) {
      return Err(@diagnostics.cg_breakdown(iteration, "solution update"))
    }
    if !all_finite(residual) {
      return Err(
        @diagnostics.non_finite_residual(iteration, positive_infinity()),
      )
    }
    let residual_norm = stable_norm(residual)
    if !is_finite(residual_norm) {
      return Err(@diagnostics.non_finite_residual(iteration, residual_norm))
    }
    if residual_norm <= cg_tolerance * rhs_norm {
      return Ok(x)
    }
    let next_residual_squared = dot(residual, residual)
    if !is_finite(next_residual_squared) {
      return Err(@diagnostics.cg_breakdown(iteration, "residual inner product"))
    }
    if residual_squared == 0.0 {
      return Err(@diagnostics.singular_pivot(iteration, residual_squared))
    }
    let beta = next_residual_squared / residual_squared
    if !is_finite(beta) {
      return Err(@diagnostics.cg_breakdown(iteration, "direction scaling"))
    }
    for i = 0; i < n; i = i + 1 {
      direction[i] = residual[i] + beta * direction[i]
    }
    if !all_finite(direction) {
      return Err(@diagnostics.cg_breakdown(iteration, "search direction"))
    }
    residual_squared = next_residual_squared
  }
  let final_residual_norm = stable_norm(residual)
  Err(
    @diagnostics.max_iter_exceeded(
      cg_max_iterations, cg_tolerance, final_residual_norm,
    ),
  )
}
