///|
/// Three-state conclusion about whether a solution can be trusted.
///
/// `Credible` means the residual passed and the matrix was well-conditioned
/// enough for the residual-to-error bound to be meaningful. `Rejected` means
/// the residual itself failed. `NotVerifiableFromResidual` means the residual
/// passed but the matrix was ill-conditioned, non-symmetric, non-square, or
/// otherwise not amenable to a cheap condition estimate.
pub(all) enum CredibilityVerdict {
  Credible
  Rejected
  NotVerifiableFromResidual
}

///|
pub fn CredibilityVerdict::label(self : CredibilityVerdict) -> String {
  match self {
    Credible => "Credible"
    Rejected => "Rejected"
    NotVerifiableFromResidual => "NotVerifiableFromResidual"
  }
}

///|
pub fn CredibilityVerdict::is_credible(self : CredibilityVerdict) -> Bool {
  match self {
    Credible => true
    _ => false
  }
}

///|
pub fn CredibilityVerdict::is_rejected(self : CredibilityVerdict) -> Bool {
  match self {
    Rejected => true
    _ => false
  }
}

///|
pub fn CredibilityVerdict::is_not_verifiable(self : CredibilityVerdict) -> Bool {
  match self {
    NotVerifiableFromResidual => true
    _ => false
  }
}

///|
/// Credibility report for a candidate solution.
///
/// `error_upper_bound` is present only for a `Credible` verdict. It is the
/// first-order bound `kappa_hat * relative_residual`, expressed as `Double`
/// so callers can inspect the bound without narrowing it back to `Float`.
pub struct CredibilityReport {
  verdict : CredibilityVerdict
  residual_norm : Float
  relative_residual : Float
  condition_estimate : ConditionEstimate
  error_upper_bound : Double?
  reason : String
}

///|
pub fn CredibilityReport::new(
  verdict : CredibilityVerdict,
  residual_norm : Float,
  relative_residual : Float,
  condition_estimate : ConditionEstimate,
  error_upper_bound : Double?,
  reason : String,
) -> CredibilityReport {
  {
    verdict,
    residual_norm,
    relative_residual,
    condition_estimate,
    error_upper_bound,
    reason,
  }
}

///|
fn unestimated_condition() -> ConditionEstimate {
  ConditionEstimate::new(positive_infinity(), false, false, 0.0, 0.0, 0)
}

///|
fn sanitize_residual_tolerance(value : Float) -> Float {
  if is_finite(value) && value >= 0.0 {
    value
  } else {
    verification_tolerance
  }
}

///|
fn sanitize_condition_threshold(value : Float) -> Float {
  if is_finite(value) && value > 0.0 {
    value
  } else {
    default_condition_threshold
  }
}

///|
/// Decide whether an independently computed residual supports accepting a
/// solution.
///
/// The decision order is fixed:
/// 1. Recompute `r = b - Ax`; a relative residual above the tolerance is
///    `Rejected`.
/// 2. Estimate `kappa(A)` with power iteration.
/// 3. If `kappa(A)` is not estimable, return `NotVerifiableFromResidual`.
/// 4. If `kappa(A)` is above `condition_threshold`, return
///    `NotVerifiableFromResidual` even when the residual is tiny.
/// 5. Otherwise return `Credible` with
///    `error_upper_bound = kappa_hat * relative_residual`.
///
/// The bound is a first-order relative-error estimate. It is meaningful only
/// under the well-conditioned premise; it is not a proof of componentwise
/// accuracy. The default residual tolerance is `verification_tolerance`, and
/// the default conditioning threshold is `default_condition_threshold`.
pub fn verify_solution_with_credibility(
  matrix : Array[Array[Float]],
  b : Array[Float],
  x : Array[Float],
  tolerance? : Float,
  condition_threshold? : Float,
) -> CredibilityReport {
  let residual_tolerance = match tolerance {
    Some(value) => sanitize_residual_tolerance(value)
    None => verification_tolerance
  }
  let threshold = match condition_threshold {
    Some(value) => sanitize_condition_threshold(value)
    None => default_condition_threshold
  }
  match verify_solution_with_diagnostic(matrix, b, x) {
    Err(diagnostic) => {
      let code = @diagnostics.SolverDiagnostic::error_code(diagnostic)
      let message = @diagnostics.SolverDiagnostic::message(diagnostic)
      let estimate = estimate_condition_number_with_threshold(matrix, threshold)
      CredibilityReport::new(
        NotVerifiableFromResidual,
        positive_infinity(),
        positive_infinity(),
        estimate,
        None,
        "Input is not verifiable (\{code}): \{message} A residual check cannot support acceptance.",
      )
    }
    Ok(report) => {
      let relative = report.relative_error
      if !is_finite(relative) || relative > residual_tolerance {
        CredibilityReport::new(
          Rejected,
          report.residual_norm,
          relative,
          unestimated_condition(),
          None,
          "Residual exceeds tolerance; the solution does not satisfy the equation.",
        )
      } else {
        let estimate = estimate_condition_number_with_threshold(
          matrix, threshold,
        )
        if !estimate.estimable {
          let cause = condition_failure_reason(matrix)
          CredibilityReport::new(
            NotVerifiableFromResidual,
            report.residual_norm,
            relative,
            estimate,
            None,
            "Condition number is not estimable: \{cause}. A passing residual is insufficient for credibility; use a direct method or a structure-aware analysis.",
          )
        } else if !is_finite(estimate.kappa) || estimate.kappa > threshold {
          CredibilityReport::new(
            NotVerifiableFromResidual,
            report.residual_norm,
            relative,
            estimate,
            None,
            "Matrix is ill-conditioned (kappa approx. \{estimate.kappa.to_string()}); a small residual does not imply an accurate solution. Use a direct method or higher precision.",
          )
        } else {
          let bound = estimate.kappa.to_double() * relative.to_double()
          CredibilityReport::new(
            Credible,
            report.residual_norm,
            relative,
            estimate,
            Some(bound),
            "Residual is within tolerance and the matrix is well-conditioned; the relative error is bounded by approximately \{bound.to_string()}.",
          )
        }
      }
    }
  }
}
