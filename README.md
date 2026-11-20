# moonbit-iterative-solvers

`moonbit-iterative-solvers` 是一个独立的新 MoonBit 开源项目，面向稀疏线性方程组的迭代求解。稀疏矩阵存储与数值诊断由既有开源库 `hp0200/moonbit-sparse-math` 提供；本库不重复实现这两部分。两者是单向依赖的互补关系：本库依赖上游，上游对本库零依赖。当前实现包含泛型能力层、迭代工作区、共轭梯度（CG）、Jacobi 预条件、BiCGSTAB 与两个可运行示例。

## 项目定位

本库的目标赛事方向为 MoonBit 黑客松（高性能数值计算扩展），按新项目方向组织。项目的职责边界是：

- 提供迭代求解所需的数值抽象与能力约束。
- 组织可复用的迭代工作区与求解流程。
- 交付共轭梯度法、BiCGSTAB 与 Jacobi 预条件。
- 以明确的错误值报告数值失效，不通过 panic 终止调用方。

稀疏矩阵存储、CSR 数据组织与数值诊断不是本库的职责。本库只通过依赖关系使用上游公开能力。

## 上游依赖

上游为 `hp0200/moonbit-sparse-math`，当前版本 `0.2.1`，许可证 Apache-2.0。本库声明依赖但不复制、改写或包装上游矩阵类型。

已核实的上游公开仓库能力仅包括：

- CSR 稀疏存储：`SparseMatrix`、`from_dense`、`to_dense`、`spmv`、`transpose`（`csr.mbt`）。
- 数值诊断工具：`is_diagonally_dominant`（`diagnostic.mbt`）与 `estimate_conditioning`（`diagnostic_ext.mbt`）。
- `test.mbt` 中的 10 个测试用例。
- `.github/workflows/ci.yml` 工作流。

上述列表是本项目文档中允许引用的全部上游能力边界。上游自身不定义算术 trait；环约束 `Ring` 来自第三方包 `Luna-Flow/luna-generic`，本库同样依赖该包，版本为 `0.4.0`。

## 本期范围

当前已交付：

- 泛型能力层。
- 迭代工作区。
- 共轭梯度 CG。
- Jacobi 预条件。
- BiCGSTAB，包括转置残差点积。
- SIR 单步与 PageRank 稳态示例。

wasm/js 导出层仍不在当前交付内。路线图见 `docs/milestones.md`。

## API 设计原则

- 不新增上游矩阵类型的包装类型；求解器以包级函数公开，例如 `cg_solve`。
- 本库定义独立 trait `FieldSafe`，它不继承 `Ring`；泛型代数组件使用多重约束 `[T : Ring + FieldSafe]`。
- 当前公开求解入口使用具体 `Double`，与上游仅支持 `Double` 的 CSR 一致；见 `docs/adr/0006-concrete-double-solver-entrypoints.md`。
- `FieldSafe` 只提供除零可检测的 `div_safe(Self, Self) -> Option[Self]`，不重新定义加减乘。
- 残差范数、容差、右端项范数与 breakdown 阈值统一使用 `Double`；泛型参数 `T` 只承担向量与矩阵代数，并通过 `ToDouble` 进入实数判据。
- 整数类型不实现 `FieldSafe`，从类型系统层面拒绝整数求解器实例化。
- 预条件子使用 enum 做静态分派，不使用 trait object。
- 求解器采用位置参数，返回值携带错误信息；数值失效不使用 panic。

```moonbit
pub fn cg_solve(
  csr : @sparse.SparseMatrix,
  b : Array[Double],
  tol : Double,
  max_iter : Int,
  precond : @precond.Preconditioner,
) -> Result[SolverOutcome, SolverError]

pub fn bicgstab_solve(
  csr : @sparse.SparseMatrix,
  b : Array[Double],
  tol : Double,
  max_iter : Int,
  precond : @precond.Preconditioner,
) -> Result[SolverOutcome, SolverError]
```

## 目录结构

```text
src/algebra/      泛型数值能力与 trait 定义
src/precond/      Jacobi 对角提取与静态分派入口
src/workspace/    可复用 Krylov 工作向量
src/solvers/      CG、BiCGSTAB、错误与统一结果类型
src/wasm/         wasm/js 导出层占位（本期无 imports、无导出实现）
examples/         可运行的 SIR 与 PageRank 示例
docs/adr/         架构决定记录
docs/             架构、错误、测试、基准、里程碑与发布文档
```

核心包使用 DSL `moon.pkg`。`src/wasm` 仍未提供导出实现；数值失效通过错误值返回，不通过 panic 终止求解。

## 本地协作

本库与上游通过仓库根目录的 `moon.work` 组织工作区，两库目录须为同级。开发期 `moon.mod` 保留精确版本号，由工作区将同名上游模块解析为同级本地源码；发布前必须按 `docs/publishing-checklist.md` 确认 registry 版本可用且发布不依赖本地解析。

示例位于独立的本地示例模块中。当前工作区下运行：

```bash
moon run examples/sir_step_app --target wasm-gc
moon run examples/pagerank_app --target wasm-gc
```

## 文档

- `docs/architecture.md`：分层与依赖拓扑。
- `docs/adr/`：四项已定案的架构决定。
- `docs/error-taxonomy.md`：数值失效模式与错误语义。
- `docs/testing-strategy.md`：差分测试策略。
- `docs/benchmark-plan.md`：基准计划与指标。
- `docs/milestones.md`：里程碑与砍单顺序。
- `docs/positioning.md`：生态定位与上游边界。
- `docs/publishing-checklist.md`：打包与发布检查。

## 许可证

本仓库使用 Apache-2.0 许可证，详见根目录 `LICENSE`。
