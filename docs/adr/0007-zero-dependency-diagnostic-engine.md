# ADR-7：零依赖诊断引擎取代稀疏迭代求解器架构

- 状态：已接受
- 日期：2026-11-25
- 取代：ADR-1 至 ADR-6

## 背景

项目定位已从“稀疏线性方程组迭代求解器”改为“AI Agent 友好的零依赖数值诊断与验证引擎”。
旧架构依赖 `hp0200/moonbit-sparse-math` 与 `Luna-Flow/luna-generic`，并通过 `moon.work`
进行本地联调。这与新定位的三个核心价值冲突：

- Agent 运行时需要零外部包、免配置的沙箱边界。
- 静默数值失败需要成为可解析的诊断数据，而不是求解器内部的附加信息。
- 结果正确性需要由独立验证器重算残差，不能依赖求解器自报状态。

## 决定

- 删除全部外部依赖、`moon.work`、旧稀疏矩阵求解器与示例模块。
- `moon.mod` 只保留本模块元数据，不声明 import 依赖。
- 源码只保留三个包：
  - `src/diagnostics`：`SolverDiagnostic` 与稳定错误码。
  - `src/verification`：独立残差验证与 `VerificationReport`。
  - `src/solvers`：零依赖极简 CG 参考实现。
- 包间依赖只允许 `verification` / `solvers` 单向依赖 `diagnostics`。
- 数值类型使用 MoonBit 内置 `Float`（32 位）；矩阵用稠密 `Array[Array[Float]]` 表示。
- `SolverDiagnostic` 是公开枚举，报告载荷包含 `error_code`、`message`、`agent_hint`
  与 `Map[String, String]` 类型的 `context`。
- 验证入口 `verify_solution` 保持任务指定的 `VerificationReport` 返回签名；另提供
  `verify_solution_with_diagnostic` 说明输入为何无效。
- 求解入口固定为 `solve(matrix, b) -> Result[Array[Float], SolverDiagnostic]`，使用固定
  容差与固定迭代预算；数值失效必须返回诊断。
- 不引入泛型 `Ring` 约束、`FieldSafe` trait、CSR 包装、预条件枚举、trait object 或 FFI 导出层。

## 后果

- 本库不再提供稀疏存储、格式转换、Jacobi 预条件、BiCGSTAB、示例应用或高性能承诺。
- 求解能力被明确限定为小规模稠密、对称正定系统的参考 CG。
- 诊断与验证 API 可以独立于求解器使用，并可在 Wasm/JS/native 间以普通数据传递。
- 未来若要重新引入外部矩阵格式、预条件或其它算法，必须先新增 ADR，并重新评估零依赖定位，
  不得把旧架构作为既成事实静默恢复。
