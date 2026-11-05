# Agent Note: Developer ID release signing

Status: implemented

## Problem

发布流程只使用临时签名，并为加载 Sparkle 关闭 Hardened Runtime；产物没有 Apple 公证，不能提供正常的 Developer ID 分发体验。Apple 签名与已有 Sparkle 更新签名承担不同职责，接入 Apple 凭据不能替换更新信任链。

## Decision

发布流程使用配置的 Developer ID Application 身份和团队，通过 Xcode archive/export 处理应用及 Sparkle 内嵌组件的分发签名，启用 Hardened Runtime。保留现有标签、版本、双架构、更新地址及 Sparkle 密钥契约；本地 Command Line Tools 构建继续临时签名并禁用更新，其理由见[本地构建记录](2026-11-04-command-line-tools-build.md)。

Apple 公证必须返回 Accepted；票据附加到应用后再生成最终压缩包及 Sparkle 更新签名。发布前从最终包解压，检查签名团队、Developer ID Application 证书类型、票据和 Gatekeeper。凭据缺失、身份不匹配、公证拒绝或超时均阻止发布，不退回临时签名。

签名身份和公证凭据只放入 GitHub 托管 runner 的临时钥匙串。导入文件由退出处理删除，任务结束始终删除钥匙串。配置与验收命令由[开发文档](../../../development.md)拥有；Tests/run-release-tests.py 直接执行工作流中的接纳检查，以虚构输入验证缺失凭据、错误团队、身份歧义及非 Accepted 状态会失败。

## Alternatives considered

- 保留临时签名作为凭据缺失时的回退：会使一次凭据配置错误生成与预期不同的公开安全属性。
- 在普通 build 后手动逐个重签 Sparkle 组件：Xcode archive/export 已拥有嵌套签名、权限保留及分发清理，手写组件清单会重复维护第三方结构。

## Consequences

发布依赖有效的付费开发者会员、Developer ID 私钥及公证凭据；证书轮换保留团队与 Sparkle 更新密钥。临时签名向 Developer ID 的切换可能要求用户重新授予系统权限。超时只结束等待，Apple 仍可能继续处理；维护者应根据日志中的提交 ID 判断后续操作。

回退通过新标签所包含的工作流版本完成；已分发应用的恢复仍使用[开发文档](../../../development.md)中的已知可用包及更高构建号策略。源代码回退不能撤回既有公证或已安装应用。

无凭据测试覆盖接纳检查及脚本语法，不代替真实 Xcode 16.4 归档、Sparkle 加载、Apple 公证、最终包 Gatekeeper 检查及旧版到新版更新验证；这些证据由实际发布 runner 和图形会话提供。
