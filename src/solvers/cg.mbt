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
  csr : @sparse.SparseMatrix,
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
  csr : @sparse.SparseMatrix,
  vector : Array[Double],
) -> Result[Array[Double], SolverError] {
  Ok(@sparse.spmv(csr, vector))
}

///|
fn validate_csr_geometry(
  csr : @sparse.SparseMatrix,
) -> Result[Unit, SolverError] {
  if csr.row_ptr.length() == 0 {
    return Err(DimensionMismatch)
  }
  let n = csr.row_ptr.length() - 1
  if csr.col_indices.length() != csr.values.length() {
    return Err(DimensionMismatch)
  }
  if csr.row_ptr[0] != 0 || csr.row_ptr[n] != csr.values.length() {
    return Err(DimensionMismatch)
  }
  for row = 0; row < n; row = row + 1 {
    let start = csr.row_ptr[row]
    let end = csr.row_ptr[row + 1]
    if start < 0 || end < start || end > csr.values.length() {
      return Err(DimensionMismatch)
    }
  }
  for position = 0; position < csr.col_indices.length(); position = position + 1 {
    let column = csr.col_indices[position]
    if column < 0 || column >= n {
      return Err(DimensionMismatch)
    }
  }
  Ok(())
}

///|
fn recompute_residual_norm(
  csr : @sparse.SparseMatrix,
  b : Array[Double],
  x : Array[Double],
  storage : Array[Double],
) -> Result[Double, SolverError] {
  let product = match matvec(csr, x) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  for i = 0; i < b.length(); i = i + 1 {
    storage[i] = b[i] - product[i]
  }
  Ok(@algebra.norm_real(storage))
}

///|
fn load_matvec(
  csr : @sparse.SparseMatrix,
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
      let true_residual = match
        recompute_residual_norm(csr, b, x, workspace.r) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      return Ok(SolverOutcome::new(x, iteration + 1, true_residual))
    }
    let rz_new = rz_product(precond, workspace.s, workspace.t)
    let beta = match @algebra.FieldSafe::div_safe(rz_new, rz) {
      Some(value) => value
      None => {
        let true_residual = match
          recompute_residual_norm(csr, b, x, workspace.r) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        return Ok(SolverOutcome::new(x, iteration + 1, true_residual))
      }
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
