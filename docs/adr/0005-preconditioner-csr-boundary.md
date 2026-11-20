# ADR-5：预条件层直接读取 CSR 公开数据

- 状态：已接受
- 日期：2026-11-20

## 背景

Jacobi 预条件需要从系数矩阵的每一行提取对角元。任务要求的静态分派入口是
`apply(preconditioner, csr, r, z)`，因此 `precond` 包必须能读取上游
`SparseMatrix[Double]` 的公开 CSR 字段。

原先的包依赖表只列出 `algebra` 与 `workspace`，没有描述 `precond` 对上游稀疏类型的只读依赖。

## 决定

- `precond` 直接依赖 `hp0200/moonbit-sparse-math`，只读取公开的
  `values`、`col_indices` 与 `row_ptr`。
- `precond` 不依赖 `solvers`，因此定义自己的 `PreconditionerError`；求解器负责把它映射为公开的
  `SolverError`。
- 对角提取集中在 `diag_of_csr`，`apply` 只负责静态分派与安全除法。
- 不复制 CSR 存储，不新增矩阵包装类型，不把上游错误或求解器错误类型反向引入上游。

## 后果

依赖拓扑增加一条 `precond -> hp0200/moonbit-sparse-math` 的只读边，方向仍严格单向。
预条件层可以独立测试 CSR 对角缺失与零对角错误，而求解器保持统一的错误分类。
