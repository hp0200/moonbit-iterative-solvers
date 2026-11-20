///|
test "diag_of_csr extracts diagonal entries in row order" {
  let csr = @sparse.from_dense(
    [[4.0, 1.0, 0.0], [1.0, 3.0, 1.0], [0.0, 1.0, 2.0]],
    0.0,
  )
  assert_eq(@precond.diag_of_csr(csr), Ok([4.0, 3.0, 2.0]))
}

///|
test "apply None copies the residual without changing it" {
  let csr = @sparse.from_dense([[2.0, 0.0], [0.0, 5.0]], 0.0)
  let r = [6.0, -10.0]
  let z = [0.0, 0.0]
  assert_eq(@precond.apply(@precond.None, csr, r, z), Ok(()))
  assert_eq(z, [6.0, -10.0])
  assert_eq(r, [6.0, -10.0])
}

///|
test "apply Jacobi divides every residual entry by its row diagonal" {
  let csr = @sparse.from_dense(
    [[4.0, 1.0, 0.0], [1.0, 3.0, 1.0], [0.0, 1.0, 2.0]],
    0.0,
  )
  let z = [0.0, 0.0, 0.0]
  assert_eq(@precond.apply_jacobi(csr, [8.0, -3.0, 5.0], z), Ok(()))
  assert_eq(z, [2.0, -1.0, 2.5])
}

///|
test "apply Jacobi rejects a missing or zero row diagonal" {
  let missing = @sparse.from_dense([[0.0, 1.0], [1.0, 2.0]], 0.0)
  let z = [0.0, 0.0]
  assert_eq(
    @precond.apply(@precond.Jacobi, missing, [1.0, 2.0], z),
    Err(@precond.ZeroDiagonal),
  )
}

///|
test "preconditioner rejects vector lengths outside the CSR geometry" {
  let csr = @sparse.from_dense([[2.0, 0.0], [0.0, 3.0]], 0.0)
  assert_eq(
    @precond.apply(@precond.None, csr, [1.0], [0.0, 0.0]),
    Err(@precond.DimensionMismatch),
  )
}
