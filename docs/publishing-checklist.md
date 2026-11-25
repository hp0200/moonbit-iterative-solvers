# 发布检查清单

发布前逐项确认以下内容。未执行的项不得标记为通过。

## 零依赖审计

- [ ] `moon.mod` 没有 import/依赖声明。
- [ ] 源码没有 import 本模块之外的包。
- [ ] 不存在 `moon.work`，也不依赖同级本地模块解析。
- [ ] 不存在 `moon.mod.json`、旧 lock 文件或注册表依赖残留。
- [ ] 搜索确认没有 `moonbit-sparse-math`、`luna-generic` 等外部包引用，历史 ADR 中的
      记录除外且必须明确标注为已取代。

## 包结构

- [ ] 只存在 `src/diagnostics`、`src/verification`、`src/solvers` 三个源码包。
- [ ] `verification` 与 `solvers` 只依赖 `diagnostics`。
- [ ] 没有稀疏矩阵包装、CSR 字段读取或其它存储实现。
- [ ] 没有 FFI、wasm/js 导出层或未声明后端文件。

## API 契约

- [ ] `SolverDiagnostic` 包含 `error_code`、`message`、`agent_hint`、`context`。
- [ ] `VerificationReport` 包含 `residual_norm`、`relative_error`、`is_valid`。
- [ ] `verify_solution` 签名与文档一致，并独立重算 `b - Ax`。
- [ ] `solve` 签名与文档一致，失败返回诊断而非 panic。
- [ ] `solve` 返回 `Ok` 前确认解向量全部有限。

## 数值语义

- [ ] 收敛判断使用运算符，不使用 `compare`。
- [ ] 空系统、非方阵、行长不一致、维度错误、非有限输入、奇异主元、breakdown、
      迭代耗尽与非有限残差均有错误码和测试。
- [ ] 测试断言最终残差满足容差，不断言单调下降。
- [ ] 错误路径按具体错误码断言。

## 构建与测试

- [ ] `moon check` 通过。
- [ ] `moon test` 通过。
- [ ] 对 `wasm-gc`、`js`、`native` 分别执行适用的检查和测试。
- [ ] `moon fmt --check` 通过。
- [ ] 清理 `_build/`、`target/`、`.mooncakes/`、日志与编辑器目录。

## 文档

- [ ] README 开篇保持“零依赖、结构化诊断、独立验证”定位。
- [ ] 文档没有宣称稀疏存储、预条件、其它求解器或 FFI 已实现。
- [ ] 文档没有未经实测的性能数字、加速比或产物体积。
- [ ] 签名示意标注“签名示意，非最终代码”。
- [ ] ADR-7 已接受，并明确取代 ADR-1 至 ADR-6。

## 元数据与许可证

- [ ] `name = "hp0200/moonbit-iterative-solvers"`。
- [ ] `version` 与发布目标一致。
- [ ] `license = "Apache-2.0"`。
- [ ] `repository` 指向本仓库。
- [ ] 根目录 `LICENSE` 保持原文，不修改、不覆盖。

## 最终发布

- [ ] 从干净检出执行全部检查，确认无需本地工作区。
- [ ] 发布说明只描述已实现能力。
- [ ] 版本标签、提交与模块版本一致。
- [ ] 回滚方案已记录。
