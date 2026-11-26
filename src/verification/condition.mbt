///|
/// Default condition-number threshold used by `estimate_condition_number`.
///
/// A value of `1.0e6` is a common heuristic boundary: beyond it, dense
/// single-precision workflows can lose most of their useful digits, so a
/// small residual alone is weak evidence for an accurate solution. It is a
/// policy threshold, not a theorem about every matrix.
pub let default_condition_threshold : Float = 1.0e6

///|
/// Relative change at which the power iteration is considered converged.
pub let condition_power_tolerance : Float = 1.0e-6

///|
/// Maximum number of power iterations for each eigenvalue estimate.
pub let condition_max_iterations : Int32 = 200

///|
/// Relative tolerance used when checking that a matrix is symmetric.
pub let condition_symmetry_tolerance : Float = 1.0e-6

///|
/// Lightweight estimate of the spectral condition number of a symmetric
/// positive-definite matrix.
///
/// `estimable` is false when the input is empty, ragged, non-square,
/// non-finite, non-symmetric, or when power iteration breaks down. In that
/// case `kappa` is positive infinity and the other numeric fields are best
/// effort diagnostics. `iterations` counts the total power iterations used
/// for the largest and smallest eigenvalue estimates.
pub struct ConditionEstimate {
  kappa : Float
  is_well_conditioned : Bool
  estimable : Bool
  lambda_max : Float
  lambda_min : Float
  iterations : Int32
}

///|
pub fn ConditionEstimate::new(
  kappa : Float,
  is_well_conditioned : Bool,
  estimable : Bool,
  lambda_max : Float,
  lambda_min : Float,
  iterations : Int32,
) -> ConditionEstimate {
  { kappa, is_well_conditioned, estimable, lambda_max, lambda_min, iterations, }
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
fn initial_component(index : Int32) -> Float {
  match index % 4 {
    0 => 1.0
    1 => 0.75
    2 => 1.25
    _ => 0.5
  }
}

///|
fn initial_vector(n : Int32) -> Array[Float] {
  let vector : Array[Float] = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    vector[i] = initial_component(i)
  }
  let norm = stable_norm(vector)
  if norm > 0.0 {
    for i = 0; i < n; i = i + 1 {
      vector[i] = vector[i] / norm
    }
  }
  vector
}

///|
fn power_iteration(
  matrix : Array[Array[Float]],
  n : Int32,
  max_iterations : Int32,
  tolerance : Float,
) -> (Float, Int32, Bool) {
  let vector = initial_vector(n)
  let mut lambda : Float = 0.0
  let mut iterations : Int32 = 0
  for iteration = 0; iteration < max_iterations; iteration = iteration + 1 {
    let product = matvec(matrix, vector)
    if !all_finite(product) {
      return (lambda, iterations, false)
    }
    let norm = stable_norm(product)
    if !is_finite(norm) || norm <= 1.0e-30 {
      return (lambda, iterations, false)
    }
    let next_lambda = dot(vector, product)
    if !is_finite(next_lambda) {
      return (lambda, iterations, false)
    }
    for i = 0; i < n; i = i + 1 {
      vector[i] = product[i] / norm
    }
    iterations = iteration + 1
    let scale = Float::max(1.0, Float::abs(next_lambda))
    if Float::abs(next_lambda - lambda) <= tolerance * scale {
      return (next_lambda, iterations, true)
    }
    lambda = next_lambda
  }
  (lambda, iterations, false)
}

///|
fn shifted_power_iteration(
  matrix : Array[Array[Float]],
  n : Int32,
  mu : Float,
  max_iterations : Int32,
  tolerance : Float,
) -> (Float, Int32, Bool) {
  let vector = initial_vector(n)
  let shifted : Array[Float] = Array::make(n, 0.0)
  let mut quotient : Float = 0.0
  let mut iterations : Int32 = 0
  for iteration = 0; iteration < max_iterations; iteration = iteration + 1 {
    let product = matvec(matrix, vector)
    if !all_finite(product) {
      return (quotient, iterations, false)
    }
    for i = 0; i < n; i = i + 1 {
      shifted[i] = mu * vector[i] - product[i]
    }
    if !all_finite(shifted) {
      return (quotient, iterations, false)
    }
    let norm = stable_norm(shifted)
    if !is_finite(norm) || norm <= 1.0e-30 {
      return (quotient, iterations, false)
    }
    let next_quotient = dot(vector, shifted)
    if !is_finite(next_quotient) {
      return (quotient, iterations, false)
    }
    for i = 0; i < n; i = i + 1 {
      vector[i] = shifted[i] / norm
    }
    iterations = iteration + 1
    let scale = Float::max(1.0, Float::abs(next_quotient))
    if Float::abs(next_quotient - quotient) <= tolerance * scale {
      return (next_quotient, iterations, true)
    }
    quotient = next_quotient
  }
  (quotient, iterations, false)
}

///|
fn matrix_shape_is_valid(matrix : Array[Array[Float]]) -> Bool {
  let n = matrix.length()
  if n == 0 {
    return false
  }
  for i = 0; i < n; i = i + 1 {
    if matrix[i].length() != n {
      return false
    }
  }
  true
}

///|
fn matrix_is_finite(matrix : Array[Array[Float]]) -> Bool {
  for row in matrix {
    for value in row {
      if !is_finite(value) {
        return false
      }
    }
  }
  true
}

///|
fn matrix_is_symmetric(matrix : Array[Array[Float]]) -> Bool {
  if !matrix_shape_is_valid(matrix) {
    return false
  }
  let n = matrix.length()
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      let left = matrix[i][j]
      let right = matrix[j][i]
      if !is_finite(left) || !is_finite(right) {
        return false
      }
      let scale = Float::max(
        1.0,
        Float::max(Float::abs(left), Float::abs(right)),
      )
      if Float::abs(left - right) > condition_symmetry_tolerance * scale {
        return false
      }
    }
  }
  true
}

///|
fn condition_input_is_valid(matrix : Array[Array[Float]]) -> Bool {
  matrix_shape_is_valid(matrix) && matrix_is_finite(matrix)
}

///|
fn condition_failure_reason(matrix : Array[Array[Float]]) -> String {
  if matrix.length() == 0 {
    "the matrix is empty"
  } else if !matrix_shape_is_valid(matrix) {
    "the matrix is non-square or ragged"
  } else if !matrix_is_finite(matrix) {
    "the matrix contains NaN or infinity"
  } else if !matrix_is_symmetric(matrix) {
    "the matrix is non-symmetric"
  } else {
    "power iteration did not converge or the matrix has no positive dominant eigenvalue"
  }
}

///|
fn unestimable_condition(iterations : Int32) -> ConditionEstimate {
  ConditionEstimate::new(
    positive_infinity(),
    false,
    false,
    0.0,
    0.0,
    iterations,
  )
}

///|
/// Estimate the spectral condition number with power iteration.
///
/// The largest eigenvalue is estimated on `A`. The smallest is estimated by
/// running power iteration on `(mu I - A)` with `mu >= lambda_max`; this uses
/// only matrix-vector products and never forms an inverse or an LU
/// factorization. Non-symmetric, non-square, empty, or non-finite matrices
/// return an estimate with `estimable = false` instead of panicking.
pub fn estimate_condition_number_with_threshold(
  matrix : Array[Array[Float]],
  threshold : Float,
) -> ConditionEstimate {
  let safe_threshold = if is_finite(threshold) && threshold > 0.0 {
    threshold
  } else {
    default_condition_threshold
  }
  if !condition_input_is_valid(matrix) || !matrix_is_symmetric(matrix) {
    return unestimable_condition(0)
  }
  let n = matrix.length()
  let (lambda_max, max_iterations, max_ok) = power_iteration(
    matrix, n, condition_max_iterations, condition_power_tolerance,
  )
  if !max_ok || !is_finite(lambda_max) || lambda_max <= 0.0 {
    return ConditionEstimate::new(
      positive_infinity(),
      false,
      false,
      lambda_max,
      0.0,
      max_iterations,
    )
  }
  let mu = lambda_max + Float::abs(lambda_max) * 1.0e-3
  let (shifted_quotient, min_iterations, min_ok) = shifted_power_iteration(
    matrix, n, mu, condition_max_iterations, condition_power_tolerance,
  )
  let iterations = max_iterations + min_iterations
  if !min_ok || !is_finite(shifted_quotient) {
    return ConditionEstimate::new(
      positive_infinity(),
      false,
      false,
      lambda_max,
      0.0,
      iterations,
    )
  }
  let mut lambda_min = mu - shifted_quotient
  if !is_finite(lambda_min) {
    return ConditionEstimate::new(
      positive_infinity(),
      false,
      false,
      lambda_max,
      0.0,
      iterations,
    )
  }
  if lambda_min < 0.0 && lambda_min > -1.0e-6 * mu {
    lambda_min = 0.0
  }
  if lambda_min <= 0.0 {
    return ConditionEstimate::new(
      positive_infinity(),
      false,
      true,
      lambda_max,
      lambda_min,
      iterations,
    )
  }
  let kappa = lambda_max / lambda_min
  if !is_finite(kappa) {
    return ConditionEstimate::new(
      positive_infinity(),
      false,
      true,
      lambda_max,
      lambda_min,
      iterations,
    )
  }
  ConditionEstimate::new(
    kappa,
    kappa <= safe_threshold,
    true,
    lambda_max,
    lambda_min,
    iterations,
  )
}

///|
/// Estimate the spectral condition number using the default threshold.
pub fn estimate_condition_number(
  matrix : Array[Array[Float]],
) -> ConditionEstimate {
  estimate_condition_number_with_threshold(matrix, default_condition_threshold)
}
