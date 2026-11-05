# Agent Note: Resumable notarization

Status: implemented

## Problem

Apple 公证可能在客户端的等待预算内无法完成。原发布流程把 JSON 输出写入临时文件，等待期间无进度；超时直接终止任务，签名应用及 Sparkle 工具也随 runner 销毁。重新运行会生成新签名包并创建新公证提交，不能继续处理原产物。

## Decision

保留[Developer ID 发布](2026-11-05-developer-id-release.md)的 Accepted 准入、签名及最终分发检查。使用 notarytool 原生进度与 30 分钟等待预算，等待结束后单独查询状态并尝试读取 Apple 日志；超时和状态查询失败仍阻止发布。

首次运行按 run ID 与 attempt 保存不可覆盖的签名产物及元数据，等待前完成上传。归档包含原应用 ZIP 及匹配的 Sparkle 工具，保留权限和符号链接，不包含凭据。元数据将公证 ID 绑定到原仓库、标签提交、运行、构建号及应用 ZIP 的 SHA-256。

维护者通过同一工作流的 workflow_dispatch 恢复原提交，GitHub Actions API 验证来源是本仓库同一工作流的标签 push，且标签未移动；下载后再次核对元数据及校验值。恢复复用原构建号和签名包，不重建、不重签、不重复提交公证。按标签共享 concurrency group，避免首次发布与恢复并发发布同一版本。操作契约由[开发文档](../../../development.md#继续已有公证提交)拥有。

## Alternatives considered

- 只延长等待超时：仍缺少可恢复产物，无法应对持续时间超过 runner 预算的延迟。
- 每次恢复重新构建并复用旧公证 ID：不能证明新签名包就是已提交的原包，也丢失原构建号和审计关系。
- 自行定时轮询及重试：notarytool 已提供进度与超时，复用原生能力，保留有限的状态查询和失败诊断。

## Consequences

artifact 保留 30 天；过期、删除、旧运行未保存产物、提交 ID 缺失或标签已移动时必须生成新构建。提交请求没有返回可用 ID 时仍保存原包，但不猜测 Apple 是否接收，也不允许按任意 ID 恢复。恢复不需要 Apple 签名私钥，仍依赖有效公证凭据、原团队和匹配的 Sparkle 更新密钥。

Tests/run-release-tests.py 通过已知违规输入验证来源、元数据及接纳守卫，执行真实 ditto/tar 归档往返及可执行文件，使用公证进程替身验证进度、超时、状态查询失败和拒绝路径。它不证明 GitHub artifact 服务、真实 Apple 公证或 Gatekeeper 验收；这些仍由实际发布 runner 提供。回退工作流及对应检查不撤销既有 Apple 提交或已发布发行版。
