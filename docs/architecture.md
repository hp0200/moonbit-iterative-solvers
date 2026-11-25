# 架构说明

本库是一个零依赖的 AI Agent 数值诊断与验证引擎。它不实现稀疏存储，也不再依赖任何
外部 MoonBit 包；全部能力都建立在内置数组、`Float`、`Result` 与标准 prelude 之上。

## 设计边界

```text
src/diagnostics  <-  src/verification
src/diagnostics  <-  src/solvers
```

- `diagnostics` 不依赖任何本库其它包。
- `verification` 只依赖 `diagnostics`。
- `solvers` 只依赖 `diagnostics`。
- 三个包都不声明外部包 import。
- 不存在 `moon.work`、上游源码解析或本地同级模块假设。

新定位的架构决定见 `docs/adr/0007-zero-dependency-diagnostic-engine.md`。ADR-1 至 ADR-6
描述旧稀疏求解器方案，现仅作为历史记录保留。

## 包职责

| 包 | 职责 | 依赖 |
| --- | --- | --- |
| `src/diagnostics` | 结构化诊断、稳定错误码、上下文 Map | 无 |
| `src/verification` | 独立计算残差并生成 `VerificationReport` | `diagnostics` |
| `src/solvers` | 稠密、小规模、固定参数的参考 CG | `diagnostics` |

## 诊断模型

`SolverDiagnostic` 是公开枚举，其 `Report` 载荷直接包含：

- `error_code : String`
- `message : String`
- `agent_hint : String`
- `context : Map[String, String]`

错误码是稳定的分支条件，解释文本与 Agent 建议不是解析依据。上下文字段只能保存字符串
键值，避免把闭包、外部对象或运行时句柄带入导出边界。

所有已知失败模式都有集中构造器，包括空系统、非方阵、行长不一致、维度不匹配、非有限
输入、奇异主元、CG breakdown、迭代预算耗尽与非有限残差。新增数值失效模式时，必须先
定义错误码、上下文契约与测试，再接入求解路径。

## 独立验证

验证器不读取求解器迭代状态，也不调用求解器。它只接收 `A`、`b`、`x`，重新计算：

```text
r = b - A x
residual_norm = ||r||
relative_error = ||r|| / ||b||   (b != 0)
relative_error = ||r||           (b == 0)
```

`VerificationReport` 包含 `residual_norm`、`relative_error` 与 `is_valid`。默认容差为
`1.0e-5`，`is_valid` 只根据验证器算出的相对残差与有限性决定。

公开签名示意，非最终代码：

```text
verify_solution(matrix, b, x) -> VerificationReport
verify_solution_with_diagnostic(matrix, b, x) -> Result[VerificationReport, SolverDiagnostic]
```

## 参考 CG

求解器只处理稠密方阵，目标是小规模对称正定系统：

```text
solve(matrix, b) -> Result[Array[Float], SolverDiagnostic]
```

上述为签名示意，非最终代码。实现使用固定容差 `1.0e-5` 与固定预算 1000 次迭代。
每次矩阵乘法、内积、步长、解更新和搜索方向更新后都检查有限性。零主元、负曲率、
非有限中间量、非有限残差与预算耗尽均返回诊断。

返回 `Ok(x)` 前再次检查 `x` 的所有分量均为有限值。库内不使用 panic、`abort` 或
“返回 NaN 当作失败”的约定。

## 数值规则

- 实数量与矩阵元素统一使用 MoonBit 内置 `Float`。
- 收敛判断使用 IEEE 关系运算符，不使用 `compare`。
- 范数计算采用缩放求平方和，减少过早溢出与下溢。
- 输入在进入计算前完成形状与有限性校验。
- 验证容差与求解容差是公开常量，便于调用方理解行为。

## 范围外

- 稀疏矩阵存储、CSR/CSC 转换与 SpGEMM。
- Jacobi、SSOR 或其它预条件子。
- BiCGSTAB、GMRES、PCG 或其它求解算法。
- FFI、wasm/js 导出层与零拷贝边界。
- 面向大矩阵的性能优化与加速比承诺。

这些能力没有被本期实现。未来若引入，必须先修订 ADR，而不能静默恢复旧架构。
