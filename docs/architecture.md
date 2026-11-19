# 架构说明

本文描述 `moonbit-iterative-solvers` 的静态分层、依赖方向与包职责。当前仓库处于脚手架阶段，只存在包清单，不包含实现。

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
| `src/precond` | 预条件构造与静态分派支持 | `src/algebra`、`src/workspace` |
| `src/workspace` | 迭代状态组织、工作向量与 `Double` 诊断量的生命周期管理 | `src/algebra` |
| `src/solvers` | 包级求解函数、CG 流程编排、Jacobi 预条件与静态分派 enum | `src/algebra`、`src/workspace`、`src/precond`、上游公开类型、`Luna-Flow/luna-generic` |
| `src/wasm` | wasm/js 导出层占位；本期不提供导出入口 | 无 imports |

各包 `moon.pkg` 已按上表声明 imports；`src/wasm` 在本期保持空配置，不提供导出层。

## 依赖拓扑

```text
src/algebra -> Luna-Flow/luna-generic
src/workspace -> src/algebra
src/precond -> src/algebra, src/workspace
src/solvers -> src/algebra, src/workspace, src/precond,
               hp0200/moonbit-sparse-math, Luna-Flow/luna-generic
src/wasm -> （本期无 imports）
```

约束如下：

- `algebra` 不依赖 `precond`、`workspace` 或 `solvers`。
- `workspace` 只依赖 `algebra`，不依赖 `precond` 或 `solvers`。
- `precond` 只依赖 `algebra` 与 `workspace`，不依赖 `solvers`。
- `solvers` 可以依赖 `algebra`、`workspace`、`precond`、上游公开 API 与 `Luna-Flow/luna-generic`。
- `wasm` 在本期不声明 imports，也不提供导出实现。
- 上游不得依赖上述任何本库包。
- 不允许通过反向回调、注册表或隐藏全局状态制造依赖倒置。

## 数值抽象层

`FieldSafe` 是独立 trait，不继承 `Ring`。求解器使用多重约束：

```text
[T : @luna_generic.Ring + FieldSafe]
```

`FieldSafe` 只承诺 `div_safe(Self, Self) -> Option[Self]`。多重约束下所有 trait 方法必须使用限定语法；公开 API 通过包级函数暴露，包内私有辅助函数负责降低 `Ring::add`、`FieldSafe::div_safe` 这类调用噪音。

所有实数量固定为 `Double`：残差范数、容差、右端项范数与 breakdown 阈值。泛型参数 `T` 只承担向量和矩阵代数；范数路径通过 `ToDouble` 转入 `Double`。因此 `T` 不需要开方或除法运算符。

本期 `FieldSafe` 只服务于 `Double` 实例化。整数类型不实现该 trait，求解器对整数实例化在编译期不可用。

## 迭代工作区

工作区层负责在一次求解调用内组织可复用状态，包括迭代向量、标量诊断量以及临时存储的生命周期。它不拥有稀疏矩阵存储，也不公开对上游矩阵的包装类型。

工作区的几何代数运算保持泛型，残差与阈值比较固定在 `Double`。自别名行为、输入输出所有权和 NaN 传播语义在实现前写入公开 API 契约，并由测试策略覆盖。

## 求解器层

求解器以包级函数公开，例如 `cg_solve`。不使用上游矩阵的包装类型，原因见 `docs/adr/0001-no-wrapper-type.md`。

预条件子使用 enum 做静态分派：

```text
// 签名示意，非最终代码
Preconditioner = None | Jacobi | ...
```

本期只承诺 `None` 与 `Jacobi` 的求解路径；enum 的后续扩展必须服从里程碑文档，不在脚手架阶段提前承诺。选择静态分派是为了避免 trait object 与不必要的泛型单态化，控制 WebAssembly 产物体积。

求解器参数使用位置参数，与上游既有风格一致。返回值携带解或数值错误；奇异主元、内积 breakdown、迭代超限、维度不匹配和方法前提不满足均不以 panic 表示。

## 转置运算归属

本库负责实现转置矩阵-向量乘积，不假设上游提供。该运算属于求解算法层，通过上游公开数据访问能力完成，不复制存储结构。当前 CG/Jacobi 里程碑不依赖它；职责见 `docs/adr/0004-transpose-ownership.md`。

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

## 当前脚手架状态

- 有 `moon.mod`、`moon.work`、五个 `moon.pkg`、工作区文件与文档。
- 四个旧格式 JSON 清单待人工清理：根目录 `moon.mod.json` 与 `src/algebra`、`src/solvers`、`src/workspace` 下的 `moon.pkg.json`。
- 本库包目录内没有 `.mbt` 源码或测试文件。
- `src/wasm` 目录已建立但本期不提供 wasm/js 导出实现。
- 没有未实测的性能结论。
