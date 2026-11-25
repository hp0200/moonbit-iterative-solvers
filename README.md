# 数值诊断与验证引擎

**面向 AI Agent 的零依赖数值安全边界**

> 仓库标识 `moonbit-iterative-solvers` 为初版遗留命名，
> 当前职责已收敛为诊断与验证层，命名保留以维持已发布包
> 与提交历史的连续性。

`hp0200/moonbit-iterative-solvers` · 版本 `0.0.2` · Apache-2.0

## 动机

AI Agent 正在大量生成数值代码，并把求解器、矩阵运算和误差判断组合进自动化流程。
这些代码中的失败往往是静默的：结果可能返回 `NaN`，迭代可能不收敛，矩阵与向量的维度
可能不一致，但调用仍然继续执行。

调用方因此难以判断一个结果是可信解、未收敛的中间值，还是已经失效的数值。仅返回一个
数组或一个布尔值，无法说明失败发生在哪里，也无法告诉 Agent 下一步应该检查什么。

本库为此提供两件事：第一，把数值失败转换为结构化、可按错误码分派的诊断；第二，不依赖
求解器内部状态，独立重算残差来验证已有结果。共轭梯度求解器在这里承担参考实现的角色，
用于跑通诊断与验证闭环，而不是作为性能竞争项。

## 功能概览

| 模块 | 能力 |
| --- | --- |
| `src/diagnostics` | `SolverDiagnostic`，包含稳定错误码、解释、`agent_hint` 与上下文 |
| `src/verification` | `verify_solution`，独立重算 `b - Ax` 并返回验证报告 |
| `src/solvers` | `solve`，零依赖的稠密参考共轭梯度实现 |

### 结构化诊断

`SolverDiagnostic` 是公开枚举，其 `Report` 载荷包含：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `error_code` | `String` | 稳定、可按值分派的错误码，例如 `SINGULAR_PIVOT`、`MAX_ITER_EXCEEDED` |
| `message` | `String` | 面向人类读者的失败解释 |
| `agent_hint` | `String` | 面向 AI Agent 的修复建议 |
| `context` | `Map[String, String]` | 矩阵规模、迭代次数、主元等附加证据 |

错误码围绕四类数值失效组织：

- 维度不一致：`DIMENSION_MISMATCH`、`NON_SQUARE_MATRIX`、`RAGGED_MATRIX`；
- 奇异主元：`SINGULAR_PIVOT`、`BREAKDOWN`；
- 迭代超限：`MAX_ITER_EXCEEDED`；
- 退化输入：`EMPTY_SYSTEM`、`NON_FINITE_INPUT`、`NON_FINITE_RESIDUAL`、`INVALID_TOLERANCE`、`INVALID_MAX_ITERATIONS`。

诊断模块自身不执行矩阵运算，也不判断解是否正确；它只定义失败如何被表达和传递。

### 独立验证

`verify_solution` 只接收 `matrix`、`b` 与 `x`，重新计算：

```text
r = b - Ax
```

它不读取求解器的残差、迭代次数或工作向量。`VerificationReport` 包含：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `residual_norm` | `Float` | `||b - Ax||` |
| `relative_error` | `Float` | `||b - Ax|| / ||b||`；当 `b` 为零向量时使用绝对残差 |
| `is_valid` | `Bool` | 是否通过默认验证容差 |

默认验证容差为 `1.0e-5`。非方阵、行长不一致、维度不匹配或非有限输入会产生无效报告；
需要具体失败原因时，可调用 `verify_solution_with_diagnostic`。

验证过程不依赖求解器内部状态，因此验证方与求解方可以来自不同实现。只要双方遵守相同的
`A`、`b`、`x` 数据结构，验证器就可以独立检查结果。

### 参考共轭梯度求解器

`solve` 是固定容差、固定迭代预算的稠密参考实现：

- 相对残差容差：`cg_tolerance = 1.0e-5`；
- 迭代预算：`cg_max_iterations = 1000`；
- 输入类型：`Array[Array[Float]]` 与 `Array[Float]`；
- 适用对象：对称正定系统；
- 迭代前检查维度、矩阵形状和非有限输入；
- 失败时返回 `SolverDiagnostic`，覆盖奇异主元、breakdown、残差失效与预算耗尽；
- 不 panic，不返回包含非有限分量的成功解。

现有测试包含 `2x1` 短列矩阵回归，确认该输入返回 `NON_SQUARE_MATRIX`，不会发生越界访问。

## 零依赖

仓库中不存在 `moon.mod.json`，也不存在 `moon.work`。完整的 `moon.mod` 为：

```text
name = "hp0200/moonbit-iterative-solvers"

version = "0.0.2"

license = "Apache-2.0"

description = "Zero-dependency numerical diagnostics and verification for AI agents in MoonBit."

readme = "README.md"

repository = "https://github.com/hp0200/moonbit-iterative-solvers"

source = "src"
```

该文件不包含 `import`、`deps` 或 `bin-deps`。库内依赖只有：

```text
src/verification ──▶ src/diagnostics
src/solvers      ──▶ src/diagnostics
```

`diagnostics` 不依赖任何包。使用者无需解析或配置额外包，即可在 Wasm 沙箱和 Agent 运行时
中加载本库。

## 快速开始

以下示例假设使用者在 `moon.pkg` 中声明了对应包别名：

```moonbit
import {
  "hp0200/moonbit-iterative-solvers/diagnostics" @diagnostics,
  "hp0200/moonbit-iterative-solvers/solvers" @solvers,
  "hp0200/moonbit-iterative-solvers/verification" @verification,
}
```

### 示例一：求解失败后读取诊断与修复建议

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

零矩阵会触发 `SINGULAR_PIVOT`。Agent 可以直接按 `error_code` 分支，也可以把
`agent_hint` 作为下一步检查或换用直接法的依据。

### 示例二：独立验证已有解

```moonbit
fn verify_existing_solution() -> Unit {
  let matrix : Array[Array[Float]] = [[4.0, 1.0], [1.0, 3.0]]
  let b : Array[Float] = [6.0, 7.0]
  let x : Array[Float] = [1.0, 2.0]

  let report = @verification.verify_solution(matrix, b, x)
  if report.is_valid {
    println("verified: residual_norm=\{report.residual_norm}")
    println("relative_error=\{report.relative_error}")
  } else {
    println("rejected")
  }
}
```

该示例中的 `x` 满足 `A x = b`，因此验证报告应为有效，残差范数为零。

## 架构

```text
src/diagnostics/   数值诊断、错误码与上下文
src/verification/  独立残差验证
src/solvers/       稠密参考共轭梯度
docs/adr/          架构决策记录
```

依赖方向固定为：

```text
src/verification ──▶ src/diagnostics
src/solvers      ──▶ src/diagnostics
```

`diagnostics` 没有依赖；`verification` 只依赖 `diagnostics`；`solvers` 只依赖
`diagnostics`。这三层分离使诊断类型可以被验证器和求解器共享，而不引入矩阵后端。

## 模块说明

### `diagnostics`

职责是定义数值失败的公共表达：`SolverDiagnostic`、错误码、解释、`agent_hint` 和
`Map[String, String]` 上下文。

它无依赖，不执行矩阵乘法、残差计算或求解，也不依赖任何后端状态。

### `verification`

职责是对任意 `(A, b, x)` 三元组独立重算残差 `r = b - Ax`，并返回
`VerificationReport`。

它只依赖 `diagnostics`。验证方与求解方可以是不同实现，因为验证不读取求解器内部状态，
也不需要求解器提供迭代过程。

它不求解方程，不修改输入，也不根据求解器自报的残差给出结论。

### `solvers`

职责是提供一个可运行的参考共轭梯度实现，用于展示失败如何映射为诊断，以及结果如何交给
独立验证器检查。

它只依赖 `diagnostics`。实现面向稠密、对称正定系统，使用固定容差与固定迭代预算；不负责
稀疏存储、预条件、性能优化或其它算法。

## 后端支持

| 目标 | 状态 |
| --- | --- |
| `wasm-gc` | `moon test --target wasm-gc` 为 12/12 通过 |
| `js` | `moon test --target js` 为 12/12 通过 |
| `native` | CI 已在 Linux runner 上将 native 纳入构建矩阵；`moon check --target native` 通过 |

在 Windows 本机执行 native 测试时，需要安装 MSVC Build Tools 的 C++ 工作负载与 Windows SDK。
`moon` 会自动查找 `cl.exe` 或 `clang-cl.exe`，无需从 Developer Command Prompt 启动。

## 验证与测试

当前已验证的命令与结果：

| 命令 | 结果 |
| --- | --- |
| `moon fmt` | 干净 |
| `moon check --target all` | 通过 |
| `moon test --target wasm-gc` | 12 个测试通过，0 个失败 |
| `moon test --target js` | 12 个测试通过，0 个失败 |
| `moon check --target native` | 通过 |

CI 配置位于 `.github/workflows/ci.yml`，其中 native 已包含在 Linux runner 的构建矩阵中。

测试覆盖诊断字段与上下文、有效与无效验证、NaN 输入、维度与矩阵形状错误、共轭梯度
收敛后的独立验证、奇异主元，以及 `2x1` 短列矩阵回归。

## 设计决策

零依赖诊断引擎的决策记录在
`docs/adr/0007-zero-dependency-diagnostic-engine.md`。该决定取代 ADR-1 至 ADR-6；
后者描述早期稀疏求解器架构，仅作为历史记录保留。

## 设计边界

本库不实现新的数值算法。`solvers` 中的共轭梯度法是教科书算法的参考实现。

本库不追求求解性能，定位是求解之外的诊断与验证层，不进行求解速度比较。

结构化错误返回是 MoonBit 语言已有的能力。本库的贡献在于数值失效领域的错误分类、
稳定的错误码契约，以及面向 Agent 的可执行修复建议。

本库不实现稀疏矩阵存储、格式转换、预条件、BiCGSTAB、GMRES、FFI 或 wasm/js 导出层。
它与 sparse-math、floating 等项目的职责不同，不替代这些项目，也不评价其能力。

## 贡献

修改本库时请保持零依赖、三模块结构和上述依赖方向。提交前建议运行：

```bash
moon fmt
moon fmt --check
moon check --target all
moon test --target wasm-gc
moon test --target js
```

在 Windows 本机执行 native 测试前，请确认 MSVC Build Tools 与 Windows SDK 已安装。更新
数值错误语义时，应同时补充对应的诊断测试和验证测试。

## 变更记录

### 0.0.2

- 完成零依赖重构，移除外部依赖、旧求解器、预条件、workspace、wasm 占位、examples 与 `moon.work`。
- 源码收敛为 `diagnostics`、`verification`、`solvers` 三个模块。
- 提供结构化诊断、独立残差验证和稠密参考共轭梯度实现。
- CI 在 Linux runner 上将 native 纳入构建矩阵。

## 许可证

Apache-2.0，见仓库根目录 `LICENSE`。
