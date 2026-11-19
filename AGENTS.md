# Agent 项目指南

## 项目定位

`moonbit-iterative-solvers` 是一个独立的新 MoonBit 开源库，专注稀疏线性方程组的迭代算法与数值抽象层。稀疏矩阵存储与数值诊断由 `hp0200/moonbit-sparse-math` 提供；本库不重复实现。依赖严格单向：本库依赖上游，上游对本库零依赖。

目标赛事方向为 MoonBit 黑客松方向四（高性能数值计算扩展）。本期范围只有泛型能力层、迭代工作区、CG、Jacobi 预条件。

## 技术栈摘要

- MoonBit，模块 `hp0200/moonbit-iterative-solvers`，版本从 `0.0.1` 起步。
- 上游依赖：`hp0200/moonbit-sparse-math` 0.2.1，Apache-2.0；开发期由 `moon.work` 将同级模块解析为本地源码。
- 算术语义：`Ring` 来自 `Luna-Flow/luna-generic` 0.4.0，写作 `@luna_generic.Ring`。
- 数值诊断量：残差范数、容差、右端项范数、breakdown 阈值固定为 `Double`。
- 预条件分派：enum 静态分派。
- 当前 CI 目标：`wasm-gc`、`js`、`native` 构建，以及格式检查；脚手架阶段不运行 CI。

除上述两个第三方依赖外，不引入新的运行时依赖。

## 上游事实与边界

已核实的上游公开仓库能力只有：

- CSR 稀疏存储：`SparseMatrix`、`from_dense`、`to_dense`、`spmv`、`transpose`（`csr.mbt`）。
- 数值诊断工具：`is_diagonally_dominant`（`diagnostic.mbt`）、`estimate_conditioning`（`diagnostic_ext.mbt`）。
- `test.mbt` 中的 10 个测试用例。
- `.github/workflows/ci.yml` 工作流。

禁止把 PCG 求解器、CSC 格式转换、SpGEMM、WebAssembly 零拷贝描述为上游已有能力。

禁止读取、复制或改写上游源码。实现只能通过依赖关系和上游公开 API 进行。若缺少所需公开能力，先记录架构决定并与上游协作，不得复制源码绕过边界。

## 架构决定（不可自行改设计）

1. 不创建上游矩阵包装类型；求解器以包级函数公开，例如 `cg_solve`。
2. 本库定义独立 `FieldSafe`，不继承 `Ring`；求解器使用多重约束 `[T : Ring + FieldSafe]`。
3. `FieldSafe` 只提供 `div_safe(Self, Self) -> Option[Self]`；除零返回 `None`，不 panic。不得在 `FieldSafe` 中重新定义加减乘。
4. 严禁 `trait FieldSafe : Ring`。`Ring` 是第三方 trait，不能把可行性押在其可继承性上。
5. 多重约束下所有 trait 方法使用限定语法，例如 `Ring::add`、`FieldSafe::div_safe`；包内用私有辅助函数降低噪音。
6. trait 名保持 `FieldSafe`，不要改成 `Field`。
7. 所有实数量固定为 `Double`；`T` 只承担向量与矩阵代数，通过 `ToDouble` 计算范数。
8. 整数类型不实现 `FieldSafe`，从而在类型系统层拒绝整数求解器实例化。
9. 预条件子用 enum 静态分派，禁止 trait object。
10. 求解器使用位置参数；返回值携带错误，数值失效不 panic。
11. 转置矩阵-向量乘积由本库自行实现，不假设上游提供；当前 CG/Jacobi 范围不依赖它。

## MoonBit 语言事实

- trait 支持多父声明与默认实现；实现子 trait 前必须先实现全部父 trait。
- 受子 trait 约束时，调用父 trait 方法必须使用限定语法；多重约束下所有 trait 方法都必须限定调用。
- `impl Trait for Type` 只记录实现关系；点号语法还需要额外的 `extend Type with Trait::{method}`。
- `impl` 本库 trait for 外部类型合法，但点号语法只在本包有效，下游只能限定调用；因此公开 API 一律使用包级函数。
- FFI 声明不能带类型参数；泛型核心包与 wasm/js 导出包必须物理分离，导出层按实例化逐个具体化为 `Float64` 入口。
- 本地工具链的 derive 使用 `#derive(...)` 属性；整数类型使用 `Int32`（`Int` 仍可作别名）。
- `compare` 对 NaN 不保证结果；`==`、`<=`、`<` 等运算符保持 IEEE 语义。收敛判断只用运算符形式，禁止用 `compare` 比较残差。
- `moon.mod` 的依赖使用精确版本号。开发期通过 `moon.work` 将同名模块解析为同级本地源码；发布前必须确认 registry 版本可用且不依赖本地解析。
- 两库联调使用仓库根目录的 `moon.work`，且两库目录必须同级。

## 目录约定

```text
src/algebra/      泛型能力层：FieldSafe、ToDouble 与限定调用辅助
src/precond/      预条件构造与静态分派支持
src/workspace/    迭代工作区：迭代状态与 Double 诊断量
src/solvers/      CG、Jacobi、预条件 enum 与包级求解入口
src/wasm/         wasm/js 导出层占位；本期无 imports、无导出实现
docs/adr/         已接受架构决定
docs/             架构、错误、测试、基准、里程碑、定位与发布文档
testdata/         后续差分测试 fixture；不得加入 .gitignore
.github/workflows CI 定义
```

当前脚手架阶段，五个包目录使用 DSL `moon.pkg`；旧 `moon.pkg.json` 与根目录 `moon.mod.json` 仅待人工清理，不得据其继续扩展。本库包目录内不得创建任何 `.mbt` 文件。进入实现阶段后，源码与测试只能放入已批准包范围；不得新增未列入架构的包。

## 提交信息规范

- 使用 Conventional Commits 前缀：`chore:`、`docs:`、`ci:`、`feat:`、`fix:`、`test:`、`refactor:`。
- 一个文件一次提交；不得在一次提交中夹带多个文件。
- 禁止空提交。
- 禁止 `initial commit`、`update`、`changes` 这类无信息量消息。
- 脚手架阶段严格使用任务指定的提交消息原文；实现阶段每条消息应说明具体能力或修复。
- 不提交 `target/`、编辑器目录、日志、环境文件或生成产物。
- 不修改、不覆盖根目录 `LICENSE`。

## 实现阶段持久约束

- 不实现稀疏存储、格式转换或数值诊断工具；这些属于上游。
- 不新增上游矩阵包装类型，不复制上游存储结构。
- 不新增主库与 `Luna-Flow/luna-generic` 之外的第三方依赖。
- 不放宽 `FieldSafe` 独立 trait、多重约束、`Double` 诊断量、整数排除或 enum 静态分派。
- 不把未进入本期里程碑的算法写成公开承诺；路线图外能力只允许在里程碑文档中讨论。
- 不声称未核实的上游能力，不把上游测试或 CI 当作本库证据。
- 不虚构性能数字、加速比、产物体积或收敛保证；只有实际测量后才能写入结论。
- 不生成徽章或未经实测的量化指标。
- 数值失效必须返回错误，不得 panic；收敛判断不得使用 `compare`。
- 测试必须断言残差满足容差，不得断言残差单调下降；自别名、输入不变性与 NaN 路径必须有明确契约和覆盖。
- 文档中的签名示意必须标记“签名示意，非最终代码”；不得把示意当作实现已存在。

## 工作流程

1. 修改前阅读 `docs/architecture.md` 与相关 ADR。
2. 脚手架阶段只做配置与文档；没有明确指令不进入算法实现。
3. 实现阶段按 `docs/milestones.md` 顺序推进，本期四项先行。
4. 若实现需要偏离已定架构，先新增或修订 ADR，再改代码。
5. 运行与改动范围匹配的格式、构建与测试；不修复无关失败。
6. 发布前逐项执行 `docs/publishing-checklist.md`，特别是确认 registry 版本可用且发布不依赖 `moon.work` 的本地解析。
