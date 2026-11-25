# 错误分类与数值失效语义

本库把数值失效视为普通可返回数据，而不是进程级故障。所有求解与详细验证错误都映射到
`SolverDiagnostic`，调用方无需捕获异常或检查全局状态。

## 统一原则

- 不用 panic、`abort` 或宿主异常表示数值失败。
- 不把非收敛结果报告为成功。
- 不返回包含 NaN 或无穷分量的 `Ok` 解。
- 输入形状与非有限值在计算前校验。
- 迭代中间量在产生后立即校验有限性。
- 收敛判断使用 IEEE 关系运算符，不使用 `compare`。
- 诊断的 `context` 只保存字符串键值，便于跨边界传递与记录。

`SolverDiagnostic::new` 是通用映射入口；任何新失效模式都必须先定义稳定错误码和上下文，
再通过专用构造器公开。

## 错误码

| 错误码 | 触发条件 | 典型上下文 | Agent 建议方向 |
| --- | --- | --- | --- |
| `EMPTY_SYSTEM` | 矩阵没有行 | `matrix_size = 0` | 提供至少一行方程 |
| `NON_SQUARE_MATRIX` | 行数不等于列数 | `matrix_size`、`rows`、`columns` | 改为方阵或更换方法 |
| `RAGGED_MATRIX` | 某行长度与首行不同 | `row`、`expected_length`、`actual_length` | 统一每行列数 |
| `DIMENSION_MISMATCH` | `b` 或 `x` 长度与矩阵阶数不同 | `expected_length`、`actual_length`、`vector` | 调整向量长度后重试 |
| `NON_FINITE_INPUT` | 输入含 NaN 或无穷值 | `location`、`row`、`column` | 清洗或拒绝输入 |
| `INVALID_TOLERANCE` | 容差不是有限非负值 | `tolerance` | 使用小的有限正容差 |
| `INVALID_MAX_ITERATIONS` | 迭代上限不是正数 | `max_iterations` | 设置正整数预算 |
| `SINGULAR_PIVOT` | CG 曲率为零、负或非有限 | `iteration_count`、`pivot` | 检查奇异/非 SPD 输入，考虑直接法 |
| `BREAKDOWN` | CG 递推产生非有限值 | `iteration_count`、`phase` | 检查缩放与条件数，更换稳健方法 |
| `MAX_ITER_EXCEEDED` | 预算耗尽仍未满足容差 | `iteration_count`、`tolerance`、`residual_norm` | 增加预算、改善缩放或验证方法前提 |
| `NON_FINITE_RESIDUAL` | 残差范数为 NaN 或无穷 | `iteration_count`、`residual_norm` | 拒绝当前迭代并重新缩放输入 |

当前固定参数的 `solve` 不接收容差或迭代上限，因此 `INVALID_TOLERANCE` 与
`INVALID_MAX_ITERATIONS` 是公共构造器提供的通用分类，不会被当前 `solve` 自动触发。
当前 `solve` 与验证器实际产生的错误码均有测试覆盖。

## 失败类别说明

### 输入与形状错误

输入错误在分配迭代工作向量或执行矩阵运算前返回。实现不截断、不补零、不广播，避免把
调用方契约问题伪装成数值问题。

### 奇异与曲率失效

CG 要求对称正定矩阵。若搜索方向曲率 `p^T A p` 为零或负数，说明系统奇异或方法前提不
满足；非有限曲率同样归入 `SINGULAR_PIVOT`，因为它不能提供安全步长。

### Breakdown

CG 递推中的内积、步长、方向缩放或中间向量变为非有限值时返回 `BREAKDOWN`。实现不会
继续执行可能把 NaN 带入最终解的递推。

### 预算耗尽

达到 1000 次迭代仍不满足 `1.0e-5` 相对残差容差时返回 `MAX_ITER_EXCEEDED`，并附带最后
一次有限残差。调用方可以选择拒绝结果、增加预算或换方法；本库不会自动扩大预算。

### 验证失败

验证器对空系统、非方阵、行长不一致、维度不匹配和非有限输入返回详细诊断。简版
`verify_solution` 则返回 `is_valid = false` 且度量值为正无穷，确保调用方不会把不可计算
的输入误判为有效解。
