# 架构说明

本文描述 `moonbit-iterative-solvers` 的静态分层、依赖方向与包职责。当前仓库已包含能力层、工作区、CG、BiCGSTAB、Jacobi 预条件、测试与独立示例模块；wasm/js 导出层仍为占位。

## 设计边界

本库是独立的新项目，职责是求解算法与数值抽象层。稀疏矩阵存储与数值诊断由上游 `hp0200/moonbit-sparse-math` 提供，本库不重复实现。依赖方向严格单向：

```text
hp0200/moonbit-sparse-math  ->  （不依赖本库）
moonbit-iterative-solvers   ->  hp0200/moonbit-sparse-math
```

`Luna-Flow/luna-generic` 0.4.0 是本库与上游共同依赖的第三方包，用于获得 `@luna_generic.Ring`。本库不重新定义环算术。

## 包分层

| 包目录 | 职责 | 允许依赖 |
| --- | --- | --- |
| `src/algebra` | 泛型能力约束与实数诊断桥接；`FieldSafe`、`ToDouble` 及包内限定调用辅助 | `Luna-Flow/luna-generic` |
| `src/precond` | Jacobi 对角提取、预条件错误与静态分派入口 | `src/algebra`、上游公开 CSR 类型 |
| `src/workspace` | 迭代状态组织、工作向量与 `Double` 诊断量的生命周期管理 | `src/algebra` |
| `src/solvers` | CG/BiCGSTAB 入口、错误分类、统一结果与私有线性代数编排 | `src/algebra`、`src/workspace`、`src/precond`、上游公开类型、`Luna-Flow/luna-generic` |
| `src/wasm` | wasm/js 导出层占位；本期不提供导出入口 | 无 imports |
| `examples` | 独立示例模块：SIR 单步与 PageRank 稳态 | 本库公开 API、上游公开 CSR 类型 |

各包 `moon.pkg` 已按上表声明 imports；`src/wasm` 在本期保持空配置，不提供导出层。

## 依赖拓扑

```text
src/algebra -> Luna-Flow/luna-generic
src/workspace -> src/algebra
src/precond -> src/algebra, hp0200/moonbit-sparse-math
src/solvers -> src/algebra, src/workspace, src/precond,
               hp0200/moonbit-sparse-math, Luna-Flow/luna-generic
src/wasm -> （本期无 imports）
examples -> src/solvers, src/precond, hp0200/moonbit-sparse-math
```

约束如下：

- `algebra` 不依赖 `precond`、`workspace` 或 `solvers`。
- `workspace` 只依赖 `algebra`，不依赖 `precond` 或 `solvers`。
- `precond` 只依赖 `algebra` 与上游公开 CSR，不依赖 `workspace` 或 `solvers`；错误类型转换由求解器负责。
- `solvers` 可以依赖 `algebra`、`workspace`、`precond`、上游公开 API 与 `Luna-Flow/luna-generic`。
- `wasm` 在本期不声明 imports，也不提供导出实现。
- 上游不得依赖上述任何本库包。
- 不允许通过反向回调、注册表或隐藏全局状态制造依赖倒置。

## 数值抽象层

`FieldSafe` 是独立 trait，不继承 `Ring`。泛型代数组件使用多重约束：

```text
[T : @luna_generic.Ring + FieldSafe]
```

`FieldSafe` 只承诺 `div_safe(Self, Self) -> Option[Self]`。多重约束下所有 trait 方法必须使用限定语法；公开 API 通过包级函数暴露，包内私有辅助函数负责降低 `Ring::add`、`FieldSafe::div_safe` 这类调用噪音。

所有实数量固定为 `Double`：残差范数、容差、右端项范数与 breakdown 阈值。泛型参数 `T` 只承担向量和矩阵代数；范数路径通过 `ToDouble` 转入 `Double`。因此 `T` 不需要开方或除法运算符。

当前 `FieldSafe` 只服务于 `Double` 实例化。整数类型不实现该 trait。公开的 `cg_solve` 与 `bicgstab_solve` 按 `Double` 具体化，原因见 `docs/adr/0006-concrete-double-solver-entrypoints.md`。

## 迭代工作区

工作区层负责在一次求解调用内组织可复用状态。`KrylovWorkspace` 一次性分配 `r`、`p`、`ap`、`s`、`t`、`z` 六个 `Array[Double]`；`reset` 只覆盖已有元素，不清空后重新分配。它不拥有稀疏矩阵存储，也不公开对上游矩阵的包装类型。

残差与阈值比较固定在 `Double`。求解入口只读输入并返回独立解数组；工作区测试覆盖连续问题复用、清零语义与复制辅助函数。

## 求解器层

求解器以包级函数公开：`cg_solve` 处理对称正定系统，`bicgstab_solve` 处理非对称系统。两者共享维度与 CSR 几何校验、安全除法、真实残差重算和统一 `SolverOutcome`。不使用上游矩阵的包装类型，原因见 `docs/adr/0001-no-wrapper-type.md`。

预条件子使用 enum 做静态分派：

```text
// 签名示意，非最终代码
Preconditioner = None | Jacobi | ...
```

当前只承诺 `None` 与 `Jacobi`。Jacobi 从 CSR 每行读取对角元；缺失或零对角返回 `ZeroDiagonal`。选择静态分派是为了避免 trait object 与不必要的泛型单态化，控制 WebAssembly 产物体积。

求解器参数使用位置参数，与上游既有风格一致。返回值携带解或数值错误；奇异主元、内积 breakdown、迭代超限、维度不匹配和方法前提不满足均不以 panic 表示。

## 转置运算归属

BiCGSTAB 使用上游公开 `transpose` 构造转置 CSR，并以
`dot(r_hat, A p) = dot(A^T r_hat, p)` 复用固定的阴影残差。该运算属于求解算法层，不复制存储结构，也不扩大上游 API 面；职责见 `docs/adr/0004-transpose-ownership.md`。

## FFI 与导出边界

MoonBit FFI 声明不能带类型参数。因此泛型核心包与 wasm/js 导出包必须物理分离：

```text
泛型核心包（algebra / workspace / precond / solvers）
        |
        | 按 Double 逐项具体化
        v
src/wasm 导出层（本期仅目录与空配置，不提供导出实现）
```

导出层需要为每个入口实例化具体类型，例如 `Float64` 入口。本期不交付导出层，也不在核心包中加入只对某一后端有效的 FFI 声明。

## 取消与错误传播

错误沿调用链以返回值传播：

1. 工作区检测维度或前置条件问题。
2. 预条件与内积路径通过 `div_safe` 和 `Double` 判据发现数值失效。
3. 求解器将失效归入明确错误类别并返回。
4. 调用方决定重试、换预条件、改用其它方法或终止业务逻辑。

任何层都不以 panic 代替数值错误。收敛比较只使用 `<=`、`<` 等运算符形式，不使用 `compare`，因为 `compare` 对 NaN 不提供结果保证。

## 当前实现状态

- `src/algebra`、`src/workspace`、`src/precond` 与 `src/solvers` 均包含实现和测试。
- `cg_solve` 与 `bicgstab_solve` 返回 `Result[SolverOutcome, SolverError]`，数值失效不 panic。
- 维度、CSR 几何、零内积、零对角、迭代超限与 NaN 超限路径均有明确错误分类。
- 示例位于独立本地模块 `examples/`；两个入口分别为 `examples/sir_step_app` 与 `examples/pagerank_app`。
- `src/wasm` 目录已建立但本期不提供 wasm/js 导出实现。
- 没有未实测的性能结论。
