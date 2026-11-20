# ADR-6：当前求解器入口使用具体 `Double`

- 状态：已接受
- 日期：2026-11-20

## 背景

早期架构把求解器描述为 `[T : Ring + FieldSafe]` 的泛型入口。本次实现要求 CG 与 BiCGSTAB
直接接收上游 `SparseMatrix[Double]`，并以 `Double` 组织残差、容差和迭代诊断量。

上游当前只公开 `Double` 稀疏矩阵；若在求解入口继续保留泛型参数，入口并不能扩大可实例化范围，
反而会重复泛型约束并把诊断量转换散落在主循环中。

## 决定

- `cg_solve` 与 `bicgstab_solve` 当前使用具体 `Double` 入口与 `Array[Double]` 工作向量。
- `src/algebra` 保持泛型；`FieldSafe`、`ToDouble`、`dot`、`axpy`、`scale` 与 `norm_real` 的公开 API 不变。
- 整数类型仍不实现 `FieldSafe`；当前具体入口也不会接受整数稀疏矩阵。
- 未来若增加泛型求解入口，应复用现有 `Double` 实现作为验证基线，并以新的 ADR 记录约束和实例化策略。

## 后果

求解主循环可直接使用 `Double` 诊断量并保持与上游 CSR 类型一致。泛型能力层仍是独立可测试的数值抽象，
但公开求解 API 暂不承诺任意 `Ring + FieldSafe` 实例化。
