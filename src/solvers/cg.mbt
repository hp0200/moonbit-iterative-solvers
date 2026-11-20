///|
fn map_preconditioner_error(
  error : @precond.PreconditionerError,
) -> SolverError {
  match error {
    @precond.DimensionMismatch => DimensionMismatch
    @precond.ZeroDiagonal => ZeroDiagonal
  }
}

///|
fn precondition(
  precond : @precond.Preconditioner,
  csr : @sparse.SparseMatrix[Double],
  source : Array[Double],
  target : Array[Double],
) -> Result[Unit, SolverError] {
  match @precond.apply(precond, csr, source, target) {
    Ok(_) => Ok(())
    Err(error) => Err(map_preconditioner_error(error))
  }
}

///|
fn matvec(
  csr : @sparse.SparseMatrix[Double],
  vector : Array[Double],
) -> Result[Array[Double], SolverError] {
  match @sparse.spmv(csr, vector) {
    Ok(product) => Ok(product)
    Err(_) => Err(DimensionMismatch)
  }
}

///|
fn load_matvec(
  csr : @sparse.SparseMatrix[Double],
  vector : Array[Double],
  target : Array[Double],
) -> Result[Unit, SolverError] {
  let product = match matvec(csr, vector) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  for i = 0; i < target.length(); i = i + 1 {
    target[i] = product[i]
  }
  Ok(())
}

///|
fn residual_is_small(
  residual_norm : Double,
  tol : Double,
  rhs_norm : Double,
) -> Bool {
  residual_norm <= tol * rhs_norm
}

///|
fn rz_product(
  precond : @precond.Preconditioner,
  r : Array[Double],
  z : Array[Double],
) -> Double {
  match precond {
    @precond.None => @algebra.dot(r, r)
    @precond.Jacobi => @algebra.dot(r, z)
  }
}

///|
pub fn cg_solve(
  csr : @sparse.SparseMatrix[Double],
  b : Array[Double],
  tol : Double,
  max_iter : Int32,
  precond : @precond.Preconditioner,
) -> Result[SolverOutcome, SolverError] {
  let n = csr.row_ptr.length() - 1
  if b.length() != n {
    return Err(DimensionMismatch)
  }
  let x = Array::make(n, 0.0)
  let workspace = @workspace.KrylovWorkspace::make(n)
  workspace.reset(b)
  let rhs_norm = @algebra.norm_real(b)
  let initial_residual = @algebra.norm_real(workspace.r)
  if residual_is_small(initial_residual, tol, rhs_norm) {
    return Ok(SolverOutcome::new(x, 0, initial_residual))
  }
  match precondition(precond, csr, workspace.r, workspace.z) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  workspace.copy_z_to_p()
  let mut iteration = 0
  while iteration < max_iter {
    match load_matvec(csr, workspace.p, workspace.ap) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let p_ap = @algebra.dot(workspace.p, workspace.ap)
    let rz = rz_product(precond, workspace.r, workspace.z)
    let alpha = match @algebra.FieldSafe::div_safe(rz, p_ap) {
      Some(value) => value
      None => return Err(Breakdown)
    }
    @algebra.axpy(alpha, workspace.p, x)
    workspace.copy_r_to_s()
    @algebra.axpy(-alpha, workspace.ap, workspace.s)
    match precondition(precond, csr, workspace.s, workspace.t) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let residual_norm = @algebra.norm_real(workspace.s)
    if residual_is_small(residual_norm, tol, rhs_norm) {
      return Ok(SolverOutcome::new(x, iteration + 1, residual_norm))
    }
    let rz_new = rz_product(precond, workspace.s, workspace.t)
    let beta = match @algebra.FieldSafe::div_safe(rz_new, rz) {
      Some(value) => value
      None => return Ok(SolverOutcome::new(x, iteration + 1, residual_norm))
    }
    @algebra.scale(beta, workspace.p)
    @algebra.axpy(1.0, workspace.t, workspace.p)
    workspace.copy_s_to_r()
    for i = 0; i < n; i = i + 1 {
      workspace.z[i] = workspace.t[i]
    }
    iteration = iteration + 1
  }
  Err(MaxIterExceeded)
}
