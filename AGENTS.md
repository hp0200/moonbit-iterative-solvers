# Agent 项目指南

## 项目定位

`moonbit-iterative-solvers` 是一个独立的零依赖 MoonBit 库，定位为“AI Agent 友好的数值
诊断与验证引擎”。本项目优先保证安全失败、结构化诊断与独立验证，不以底层稀疏矩阵性能
或算法覆盖广度为目标。

## 技术栈摘要

- MoonBit，模块 `hp0200/moonbit-iterative-solvers`，版本从 `0.0.1` 起步。
- 不声明任何外部依赖，不使用 `moon.work`，不依赖本地同级模块。
- 数值类型使用 MoonBit 内置 `Float`；矩阵使用 `Array[Array[Float]]`。
- 诊断上下文使用 prelude 的 `Map[String, String]`。
- 包配置使用 DSL `moon.pkg`，当前只有 `diagnostics`、`verification`、`solvers` 三个源码包。

## 架构决定（不可自行放宽）

1. 只允许本模块内依赖：`verification -> diagnostics`、`solvers -> diagnostics`。
2. `diagnostics`、`verification`、`solvers` 均不得 import 任何外部包。
3. `SolverDiagnostic` 是公开枚举，载荷包含 `error_code`、`message`、`agent_hint` 与
   `context`。
4. 数值失败必须返回诊断，不得 panic、`abort` 或返回含 NaN 的 `Ok` 解。
5. `verify_solution(matrix, b, x) -> VerificationReport` 必须独立重算 `b - Ax`，不能读取
   求解器状态。
6. `solve(matrix, b) -> Result[Array[Float], SolverDiagnostic]` 是固定容差、固定预算的
   稠密参考 CG；不得把它描述为高性能或通用稀疏求解器。
7. 收敛判断使用 IEEE 关系运算符，不使用 `compare`。
8. 不引入稀疏存储、CSR 包装、预条件 trait/enum、BiCGSTAB/GMRES、FFI 导出层或其它未列入
   本期范围的能力。

ADR-1 至 ADR-6 是旧架构历史记录，已由 ADR-7 取代；不得据其恢复外部依赖或旧包结构。

## 目录约定

```text
src/diagnostics/   结构化诊断与错误码
src/verification/  独立残差验证
src/solvers/       零依赖参考 CG
docs/adr/          架构决定
docs/              架构、定位、错误、测试、基准、里程碑与发布文档
.github/workflows/ CI 定义
```

源码与测试只能放入已批准包范围；不得新增未列入架构的包。

## 提交信息规范

- 使用 Conventional Commits 前缀：`chore:`、`docs:`、`ci:`、`feat:`、`fix:`、`test:`、`refactor:`。
- 一个文件一次提交；不得在一次提交中夹带多个文件。
- 禁止空提交。
- 禁止 `initial commit`、`update`、`changes` 这类无信息量消息。
- 不提交 `_build/`、`target/`、`.mooncakes/`、编辑器目录、日志或环境文件。
- 不修改、不覆盖根目录 `LICENSE`。

## 实现约束

- 所有公开错误都必须映射到稳定错误码与结构化上下文。
- 输入形状和非有限值必须在计算前校验。
- 迭代中间量产生后立即检查有限性。
- 测试成功路径时用独立验证器重算残差；不得断言残差单调下降。
- 测试失败路径时按具体错误码断言。
- 不虚构性能数字、加速比、产物体积或收敛保证；只有实际测量后才能写入结论。
- 文档中的签名示意必须标记“签名示意，非最终代码”。

## 工作流程

1. 修改前阅读 `docs/architecture.md` 与相关 ADR。
2. 若实现需要改变零依赖定位、公开 API 或范围，先新增或修订 ADR，再改代码。
3. 每次改动运行与范围匹配的 `moon check`；最终运行 `moon test`。
4. 发布前逐项执行 `docs/publishing-checklist.md`。
5. 不修复与当前任务无关的失败。
