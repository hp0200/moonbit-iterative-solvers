# moonbit-iterative-solvers

**Zero-dependency numerical diagnostics and verification for AI agents.**

`hp0200/moonbit-iterative-solvers` · version `0.0.1` · Apache-2.0

This library gives numerical code an explicit boundary between a solver and the
agent using it. It provides structured failure data, an independent residual
check, and a small dense reference solver. It is implemented in pure MoonBit and
declares no external package dependencies.

## Why

AI agents calling numerical code need more than a returned number. The dangerous
failures are often quiet:

- a result becomes `NaN` or infinity, but the call still appears to succeed;
- a solver never meets its tolerance and the caller cannot tell why;
- matrix and vector dimensions do not agree;
- an agent cannot independently check whether a proposed solution is usable.

This library turns those cases into ordinary data: stable error codes, an agent
repair hint, key-value context, and a verification report computed from the
original `A`, `b`, and `x`.

The scope is deliberately narrow: solver-facing diagnostics and verification,
not low-level matrix kernels or high-performance numerical infrastructure.

## Features at a glance

| Package | Capability |
| --- | --- |
| `src/diagnostics` | `SolverDiagnostic` with `error_code`, `message`, `agent_hint`, and `context` |
| `src/verification` | `verify_solution`, which independently recomputes `b - Ax` |
| `src/solvers` | `solve`, a zero-dependency dense reference conjugate-gradient implementation |

### Structured diagnostics

`SolverDiagnostic` is a public enum whose `Report` payload contains:

| Field | Type | Purpose |
| --- | --- | --- |
| `error_code` | `String` | Stable machine-readable code, such as `SINGULAR_PIVOT` or `MAX_ITER_EXCEEDED` |
| `message` | `String` | Human-readable explanation |
| `agent_hint` | `String` | Suggested recovery action for an AI agent |
| `context` | `Map[String, String]` | Additional evidence such as matrix size or iteration count |

The diagnostics module defines codes including `EMPTY_SYSTEM`,
`NON_SQUARE_MATRIX`, `RAGGED_MATRIX`, `DIMENSION_MISMATCH`,
`NON_FINITE_INPUT`, `INVALID_TOLERANCE`, `INVALID_MAX_ITERATIONS`,
`SINGULAR_PIVOT`, `BREAKDOWN`, `MAX_ITER_EXCEEDED`, and
`NON_FINITE_RESIDUAL`.

### Independent verification

`verify_solution` does not inspect solver state. It recomputes the residual
`r = b - Ax` and returns a `VerificationReport` with:

| Field | Type | Meaning |
| --- | --- | --- |
| `residual_norm` | `Float` | `||b - Ax||` |
| `relative_error` | `Float` | `||b - Ax|| / ||b||`, or the absolute residual when `b` is zero |
| `is_valid` | `Bool` | Whether the report passes the default verification tolerance |

The default verification tolerance is `1.0e-5`. An invalid shape or non-finite
input produces an invalid report; `verify_solution_with_diagnostic` is available
when the caller needs the corresponding `SolverDiagnostic`.

### Reference CG solver

`solve` is a compact dense conjugate-gradient implementation intended to exercise
the diagnostics-and-verification loop:

- fixed relative tolerance: `cg_tolerance = 1.0e-5`;
- fixed iteration budget: `cg_max_iterations = 1000`;
- dense `Array[Array[Float]]` input;
- symmetric positive-definite systems;
- dimension, shape, and non-finite input checks before iteration;
- diagnostics for singular pivots, breakdown, residual failure, and budget
  exhaustion;
- no panic and no non-finite `Ok` solution.

A regression test covers a `2x1` matrix, confirming that the short-column shape
returns `NON_SQUARE_MATRIX` instead of indexing out of bounds.

This is a reference implementation, not a high-performance solver. It is meant
to make the diagnosis and verification contract concrete and testable.

## Zero dependencies

There is no `moon.mod.json` and no `moon.work` in this repository. The complete
`moon.mod` is:

```text
name = "hp0200/moonbit-iterative-solvers"

version = "0.0.1"

license = "Apache-2.0"

description = "Zero-dependency numerical diagnostics and verification for AI agents in MoonBit."

readme = "README.md"

repository = "https://github.com/hp0200/moonbit-iterative-solvers"

source = "src"
```

It contains no `import`, `deps`, or `bin-deps` declaration. The only package
imports are internal to this module:

```text
src/verification ──▶ src/diagnostics
src/solvers      ──▶ src/diagnostics
```

No external package needs to be resolved or configured before compilation. This
small dependency surface is intended for Wasm sandboxes and agent runtimes where
configuration-free startup matters.

## Quick start

The examples assume these package aliases are available in the consuming
`moon.pkg`:

```moonbit
import {
  "hp0200/moonbit-iterative-solvers/diagnostics" @diagnostics,
  "hp0200/moonbit-iterative-solvers/solvers" @solvers,
  "hp0200/moonbit-iterative-solvers/verification" @verification,
}
```

### 1. Solve and turn a failure into an agent action

```moonbit
fn solve_and_handle_failure() -> Unit {
  let matrix : Array[Array[Float]] = [[0.0, 0.0], [0.0, 0.0]]
  let b : Array[Float] = [1.0, 2.0]

  match @solvers.solve(matrix, b) {
    Ok(_) => println("unexpected success")
    Err(diagnostic) => {
      let code = @diagnostics.SolverDiagnostic::error_code(diagnostic)
      let hint = @diagnostics.SolverDiagnostic::agent_hint(diagnostic)
      println("error_code = \{code}")
      println("agent_hint = \{hint}")
    }
  }
}
```

### 2. Verify a candidate solution independently

```moonbit
fn verify_candidate_solution() -> Unit {
  let matrix : Array[Array[Float]] = [[4.0, 1.0], [1.0, 3.0]]
  let b : Array[Float] = [6.0, 7.0]
  let x : Array[Float] = [1.0, 2.0]

  let report = @verification.verify_solution(matrix, b, x)
  if report.is_valid {
    println("valid: residual_norm=\{report.residual_norm}")
    println("relative_error=\{report.relative_error}")
  } else {
    println("candidate rejected")
  }
}
```

### 3. Read diagnostic context for an agent decision

```moonbit
fn inspect_diagnostic_context() -> Unit {
  let matrix : Array[Array[Float]] = [[0.0, 0.0], [0.0, 0.0]]
  let b : Array[Float] = [1.0, 2.0]

  match @solvers.solve(matrix, b) {
    Ok(_) => println("unexpected success")
    Err(diagnostic) => {
      let code = @diagnostics.SolverDiagnostic::error_code(diagnostic)
      if code == "SINGULAR_PIVOT" {
        match
          @diagnostics.SolverDiagnostic::context_value(
            diagnostic,
            "iteration_count",
          ) {
          Some(value) => println("iteration_count=\{value}")
          None => println("iteration_count unavailable")
        }
        match
          @diagnostics.SolverDiagnostic::context_value(diagnostic, "pivot") {
          Some(value) => println("pivot=\{value}")
          None => println("pivot unavailable")
        }
        println(
          "next action = \{@diagnostics.SolverDiagnostic::agent_hint(diagnostic)}",
        )
      }
    }
  }
}
```

## Architecture

```text
src/diagnostics/   diagnostics, stable codes, and context maps
src/verification/  independent residual verification
src/solvers/       dense reference CG
docs/adr/          architecture decisions
```

Only internal module dependencies are used:

```text
src/verification ──▶ src/diagnostics
src/solvers      ──▶ src/diagnostics
```

`diagnostics` has no package dependencies. This keeps the diagnosis model
reusable by verification and solver callers without pulling in a matrix backend.

## Supported targets

![moon check](https://img.shields.io/badge/moon_check-passing-brightgreen)
![moon test](https://img.shields.io/badge/moon_test-12%2F12-brightgreen)
![format check](https://img.shields.io/badge/moon_fmt--check-passing-brightgreen)
![wasm-gc](https://img.shields.io/badge/wasm--gc_check%2Ftest-passing-brightgreen)
![js](https://img.shields.io/badge/js_check%2Ftest-passing-brightgreen)
![native check](https://img.shields.io/badge/native_check-passing-brightgreen)
![native test](https://img.shields.io/badge/native_test-environment_blocked-yellow)

| Target | `moon check` | `moon test` |
| --- | --- | --- |
| default | passing | 12/12 passing |
| `wasm-gc` | passing | 12/12 passing |
| `js` | passing | 12/12 passing |
| `native` | passing | not built in this environment |

The native test executable could not be built on the current machine because the
local MSVC C++ toolchain and Windows SDK are unavailable. That is a local
toolchain limitation, not a reported source failure. No native test result is
claimed here.

## Validation and tests

Observed on the current checkout:

| Command | Result |
| --- | --- |
| `moon check` | passing |
| `moon test` | 12 tests passed, 0 failed |
| `moon fmt --check` | passing |
| `moon check --target wasm-gc` | passing |
| `moon test --target wasm-gc` | 12 tests passed, 0 failed |
| `moon check --target js` | passing |
| `moon test --target js` | 12 tests passed, 0 failed |
| `moon check --target native` | passing |
| `moon test --target native` | environment-blocked before test execution |

The tests cover diagnostic fields and context, valid and invalid independent
verification, NaN input, dimension and matrix-shape failures, CG convergence
through independent verification, singular pivots, and the short-column `2x1`
regression.

## Design decisions

The zero-dependency diagnostic-engine decision is recorded in
`docs/adr/0007-zero-dependency-diagnostic-engine.md`. It supersedes ADR-1 through
ADR-6, which describe the earlier sparse-solver architecture and remain only as
historical records.

## Scope and boundaries

This library does not implement:

- sparse matrix storage or format conversion;
- a high-performance matrix kernel;
- preconditioners, BiCGSTAB, GMRES, or other solvers;
- FFI or a wasm/js export surface;
- performance, throughput, or convergence claims beyond the observed tests.

It is not a replacement for sparse-math or floating-point utility libraries;
their responsibilities are different. This project concentrates on the solver
interface, structured failure reporting, and independent verification of a
result.

## License

Apache-2.0. See `LICENSE`.
