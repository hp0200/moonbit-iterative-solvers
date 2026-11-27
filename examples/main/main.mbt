///|
fn print_section(title : String) -> Unit {
  println("")
  println("============================================================")
  println(title)
  println("============================================================")
}

///|
fn print_vector(label : String, values : Array[Float]) -> Unit {
  let mut text = "\{label} = ["
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      text = text + ", "
    }
    text = text + values[i].to_string()
  }
  println(text + "]")
}

///|
fn print_diagnostic(diagnostic : @diagnostics.SolverDiagnostic) -> Unit {
  println(
    "error_code        = \{@diagnostics.SolverDiagnostic::error_code(diagnostic)}",
  )
  println(
    "message           = \{@diagnostics.SolverDiagnostic::message(diagnostic)}",
  )
  println(
    "agent_hint        = \{@diagnostics.SolverDiagnostic::agent_hint(diagnostic)}",
  )
}

///|
fn print_verification(report : @verification.VerificationReport) -> Unit {
  println("residual_norm     = \{report.residual_norm}")
  println("relative_error    = \{report.relative_error}")
  println("is_valid          = \{report.is_valid}")
}

///|
fn print_condition(estimate : @verification.ConditionEstimate) -> Unit {
  println("estimable         = \{estimate.estimable}")
  println("is_well_conditioned = \{estimate.is_well_conditioned}")
  println("kappa             = \{estimate.kappa}")
  println("lambda_max        = \{estimate.lambda_max}")
  println("lambda_min        = \{estimate.lambda_min}")
  println("iterations        = \{estimate.iterations}")
}

///|
fn print_credibility(report : @verification.CredibilityReport) -> Unit {
  println(
    "verdict           = \{@verification.CredibilityVerdict::label(report.verdict)}",
  )
  println("residual_norm     = \{report.residual_norm}")
  println("relative_residual = \{report.relative_residual}")
  match report.error_upper_bound {
    Some(bound) => println("error_upper_bound = \{bound}")
    None => println("error_upper_bound = unavailable")
  }
  println("reason            = \{report.reason}")
}

///|
fn demonstrate_well_conditioned_system() -> Unit {
  print_section("Demo 1: well-conditioned SPD system -> credible result")
  println("A is a symmetric positive-definite tridiagonal matrix.")
  println("A = [[4, 1, 0], [1, 3, 1], [0, 1, 2]]")
  println("b = [1, 2, 3]")
  let matrix : Array[Array[Float]] = [
    [4.0, 1.0, 0.0],
    [1.0, 3.0, 1.0],
    [0.0, 1.0, 2.0],
  ]
  let b : Array[Float] = [1.0, 2.0, 3.0]
  match @solvers.solve(matrix, b) {
    Err(diagnostic) => {
      println("solve failed")
      print_diagnostic(diagnostic)
    }
    Ok(x) => {
      println("")
      println("1. solve returned a candidate solution")
      print_vector("x", x)

      println("")
      println("2. independent residual verification")
      let verification = @verification.verify_solution(matrix, b, x)
      print_verification(verification)

      println("")
      println("3. condition-number estimate")
      let estimate = @verification.estimate_condition_number(matrix)
      print_condition(estimate)

      println("")
      println("4. three-state credibility verdict")
      let credibility = @verification.verify_solution_with_credibility(
        matrix, b, x,
      )
      print_credibility(credibility)
      if @verification.CredibilityVerdict::is_credible(credibility.verdict) {
        match credibility.error_upper_bound {
          Some(bound) =>
            println(
              "Quantified bound: relative error is approximately <= \{bound}",
            )
          None => println("Quantified bound is unexpectedly unavailable.")
        }
      }
    }
  }
}

///|
fn demonstrate_ill_conditioned_system() -> Unit {
  print_section(
    "Demo 2: ill-conditioned system -> small residual is not enough",
  )
  println("A = diag(1, 1e-7), so kappa(A) is about 1e7.")
  println("b = [1, 1e-7]")
  println("The residual can pass, but a small residual does not imply a")
  println("componentwise-accurate solution for this matrix.")
  let matrix : Array[Array[Float]] = [[1.0, 0.0], [0.0, 1.0e-7]]
  let b : Array[Float] = [1.0, 1.0e-7]
  match @solvers.solve(matrix, b) {
    Err(diagnostic) => {
      println("solve failed")
      print_diagnostic(diagnostic)
    }
    Ok(x) => {
      println("")
      println("1. solve returned a candidate solution")
      print_vector("x", x)

      println("")
      println("2. independent residual verification")
      let verification = @verification.verify_solution(matrix, b, x)
      print_verification(verification)

      println("")
      println("3. condition-number estimate")
      let estimate = @verification.estimate_condition_number(matrix)
      print_condition(estimate)

      println("")
      println("4. three-state credibility verdict")
      let credibility = @verification.verify_solution_with_credibility(
        matrix, b, x,
      )
      print_credibility(credibility)
      if @verification.CredibilityVerdict::is_not_verifiable(
          credibility.verdict,
        ) {
        println(
          "Conclusion: the residual passed, but credibility is not established from it.",
        )
      }
    }
  }
}

///|
fn main {
  println("moonbit-iterative-solvers: numerical credibility example")
  println("Residual pass is necessary, but not sufficient, for trust.")
  demonstrate_well_conditioned_system()
  demonstrate_ill_conditioned_system()
}
