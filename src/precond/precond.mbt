///|
#derive(Eq, Debug)
pub(all) enum Preconditioner {
  None
  Jacobi
}

///|
#derive(Eq, Debug)
pub(all) enum PreconditionerError {
  DimensionMismatch
  ZeroDiagonal
}

///|
pub fn PreconditionerError::description(self : PreconditionerError) -> String {
  match self {
    DimensionMismatch =>
      "DimensionMismatch: input and output vectors must have CSR row count entries."
    ZeroDiagonal =>
      "ZeroDiagonal: a Jacobi row has no diagonal entry or its diagonal is zero."
  }
}

///|
pub fn diag_of_csr(
  csr : @sparse.SparseMatrix[Double],
) -> Result[Array[Double], PreconditionerError] {
  let n = csr.row_ptr.length() - 1
  let diagonal = Array::make(n, 0.0)
  for row = 0; row < n; row = row + 1 {
    let start = csr.row_ptr[row]
    let end = csr.row_ptr[row + 1]
    for position = start; position < end; position = position + 1 {
      if csr.col_indices[position] == row {
        diagonal[row] = csr.values[position]
      }
    }
    if diagonal[row] == 0.0 {
      return Err(ZeroDiagonal)
    }
  }
  Ok(diagonal)
}

///|
fn validate_vector_lengths(
  n : Int32,
  r : Array[Double],
  z : Array[Double],
) -> Result[Unit, PreconditionerError] {
  if r.length() != n || z.length() != n {
    Err(DimensionMismatch)
  } else {
    Ok(())
  }
}

///|
pub fn apply(
  precond : Preconditioner,
  csr : @sparse.SparseMatrix[Double],
  r : Array[Double],
  z : Array[Double],
) -> Result[Unit, PreconditionerError] {
  let n = csr.row_ptr.length() - 1
  match validate_vector_lengths(n, r, z) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match precond {
    None => {
      for i = 0; i < n; i = i + 1 {
        z[i] = r[i]
      }
      Ok(())
    }
    Jacobi => {
      let diagonal = match diag_of_csr(csr) {
        Ok(values) => values
        Err(error) => return Err(error)
      }
      for i = 0; i < n; i = i + 1 {
        match @algebra.FieldSafe::div_safe(r[i], diagonal[i]) {
          Some(value) => z[i] = value
          None => return Err(ZeroDiagonal)
        }
      }
      Ok(())
    }
  }
}

///|
pub fn apply_none(
  csr : @sparse.SparseMatrix[Double],
  r : Array[Double],
  z : Array[Double],
) -> Result[Unit, PreconditionerError] {
  apply(None, csr, r, z)
}

///|
pub fn apply_jacobi(
  csr : @sparse.SparseMatrix[Double],
  r : Array[Double],
  z : Array[Double],
) -> Result[Unit, PreconditionerError] {
  apply(Jacobi, csr, r, z)
}
