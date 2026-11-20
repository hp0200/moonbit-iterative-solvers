///|
fn copy_vector(source : Array[Double], target : Array[Double]) -> Unit {
  for i = 0; i < source.length(); i = i + 1 {
    target[i] = source[i]
  }
}

///|
fn reciprocal_ratio(
  numerator : Double,
  denominator : Double,
) -> Result[Double, SolverError] {
  match @algebra.FieldSafe::div_safe(numerator, denominator) {
    Some(value) => Ok(value)
    None => Err(Breakdown)
  }
}

///|
pub fn bicgstab_solve(
  csr : @sparse.SparseMatrix,
  b : Array[Double],
  tol : Double,
  max_iter : Int32,
  precond : @precond.Preconditioner,
) -> Result[SolverOutcome, SolverError] {
  let n = csr.row_ptr.length() - 1
  if b.length() != n {
    return Err(DimensionMismatch)
  }
  match validate_csr_geometry(csr) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let x = Array::make(n, 0.0)
  let workspace = @workspace.KrylovWorkspace::make(n)
  workspace.reset(b)
  let rhs_norm = @algebra.norm_real(b)
  let initial_residual = @algebra.norm_real(workspace.r)
  if residual_is_small(initial_residual, tol, rhs_norm) {
    return Ok(SolverOutcome::new(x, 0, initial_residual))
  }

  // r_hat is the fixed shadow residual; it is initialized from b and never updated.
  let r_hat = Array::make(n, 0.0)
  copy_vector(workspace.r, r_hat)
  let transpose_csr = @sparse.transpose(csr)
  let transpose_r_hat = match matvec(transpose_csr, r_hat) {
    Ok(product) => product
    Err(error) => return Err(error)
  }

  // Standard BiCGSTAB initialization before the first iteration.
  let mut rho_previous = 1.0
  let mut alpha = 1.0
  let mut omega = 1.0
  let mut iteration = 0
  while iteration < max_iter {
    // rho = dot(r_hat, r)
    let rho = @algebra.dot(r_hat, workspace.r)
    if rho == 0.0 {
      return Err(Breakdown)
    }

    // z = apply(precond, r)
    match precondition(precond, csr, workspace.r, workspace.z) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }

    // beta = (rho / rho_previous) * (alpha / omega)
    let rho_ratio = match reciprocal_ratio(rho, rho_previous) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let alpha_over_omega = match reciprocal_ratio(alpha, omega) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let beta = rho_ratio * alpha_over_omega

    // p = z + beta * (p - omega * v), with v stored in workspace.ap.
    for i = 0; i < n; i = i + 1 {
      workspace.p[i] = workspace.z[i] +
        beta * (workspace.p[i] - omega * workspace.ap[i])
    }

    // v = A * p
    match load_matvec(csr, workspace.p, workspace.ap) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }

    // dot(r_hat, A * p) = dot(A^T * r_hat, p).
    let r_hat_dot_v = @algebra.dot(transpose_r_hat, workspace.p)
    // alpha = rho / dot(r_hat, v)
    alpha = match reciprocal_ratio(rho, r_hat_dot_v) {
      Ok(value) => value
      Err(error) => return Err(error)
    }

    // x = x + alpha * p
    @algebra.axpy(alpha, workspace.p, x)

    // s = r - alpha * v
    workspace.copy_r_to_s()
    @algebra.axpy(-alpha, workspace.ap, workspace.s)
    let s_norm = @algebra.norm_real(workspace.s)
    if residual_is_small(s_norm, tol, rhs_norm) {
      let true_residual = match
        recompute_residual_norm(csr, b, x, workspace.r) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      return Ok(SolverOutcome::new(x, iteration + 1, true_residual))
    }

    // z = apply(precond, s)
    match precondition(precond, csr, workspace.s, workspace.z) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }

    // t = A * z
    match load_matvec(csr, workspace.z, workspace.t) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }

    // omega = dot(s, t) / dot(t, t)
    let s_dot_t = @algebra.dot(workspace.s, workspace.t)
    let t_dot_t = @algebra.dot(workspace.t, workspace.t)
    omega = match reciprocal_ratio(s_dot_t, t_dot_t) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if omega == 0.0 {
      return Err(Breakdown)
    }

    // x = x + omega * z
    @algebra.axpy(omega, workspace.z, x)

    // r = s - omega * t
    workspace.copy_s_to_r()
    @algebra.axpy(-omega, workspace.t, workspace.r)
    let residual_norm = @algebra.norm_real(workspace.r)
    if residual_is_small(residual_norm, tol, rhs_norm) {
      let true_residual = match
        recompute_residual_norm(csr, b, x, workspace.s) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      return Ok(SolverOutcome::new(x, iteration + 1, true_residual))
    }

    // rho_previous = rho for the next beta update.
    rho_previous = rho
    iteration = iteration + 1
  }
  Err(MaxIterExceeded)
}
