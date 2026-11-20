///|
pub fn run_sir_step() -> Unit {
  let dt = 0.25
  let identity = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
  let stiffness = [[-12.0, -4.0, 0.0], [-4.0, -8.0, -4.0], [0.0, -4.0, -4.0]]
  let dense : Array[Array[Double]] = []
  for i = 0; i < 3; i = i + 1 {
    let row : Array[Double] = []
    for j = 0; j < 3; j = j + 1 {
      row.push(identity[i][j] - dt * stiffness[i][j])
    }
    dense.push(row)
  }
  let csr = @sparse.from_dense(dense)
  let rhs = [6.0, 10.0, 8.0]
  match @solvers.cg_solve(csr, rhs, 1.0e-12, 50, @precond.None) {
    Ok(outcome) => {
      println("SIR step system: (I - dt A) x = b, dt = \{dt}")
      println("CG iterations: \{outcome.iterations}")
      println("CG final residual: \{outcome.final_residual}")
      for i = 0; i < outcome.x.length(); i = i + 1 {
        println("x[\{i}] = \{outcome.x[i]}")
      }
    }
    Err(error) => println("CG failed: \{error.description()}")
  }
}
