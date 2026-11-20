///|
pub fn run_pagerank() -> Unit {
  let n = 5
  let damping = 0.85
  let transition = [
    [5.0 / 8.0, 1.0 / 8.0, 0.0, 1.0 / 8.0, 1.0 / 8.0],
    [2.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0, 0.0, 1.0 / 8.0],
    [0.0, 1.0 / 8.0, 6.0 / 8.0, 1.0 / 8.0, 0.0],
    [1.0 / 8.0, 1.0 / 8.0, 0.0, 4.0 / 8.0, 2.0 / 8.0],
    [2.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0, 0.0, 4.0 / 8.0],
  ]
  let dense : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < n; j = j + 1 {
      let identity_entry = if i == j { 1.0 } else { 0.0 }
      row.push(identity_entry - damping * transition[j][i])
    }
    dense.push(row)
  }
  let csr = @sparse.from_dense(dense, 0.0)
  let teleport = (1.0 - damping) / 5.0
  let rhs = Array::make(n, teleport)
  match @solvers.bicgstab_solve(csr, rhs, 1.0e-12, 200, @precond.None) {
    Ok(outcome) => {
      println("PageRank solve: (I - alpha P^T) x = (1 - alpha) / n")
      println("BiCGSTAB iterations: \{outcome.iterations}")
      println("BiCGSTAB final residual: \{outcome.final_residual}")
      let mut total = 0.0
      for i = 0; i < outcome.x.length(); i = i + 1 {
        total = total + outcome.x[i]
        println("rank[\{i}] = \{outcome.x[i]}")
      }
      println("rank sum = \{total}")
    }
    Err(error) => println("BiCGSTAB failed: \{error.description()}")
  }
}
