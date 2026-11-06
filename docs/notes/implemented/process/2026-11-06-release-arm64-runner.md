# Agent Note: Apple Silicon release runner

Status: implemented

## Problem

GitHub 的 `macos-15-intel` 到 Apple CloudKit 的 HTTP/3 连接存在[已确认的网络故障](https://github.com/actions/runner-images/issues/14924)。公证已经 Accepted、票据已经附加的应用，仍可能在后续 `stapler validate` 时因连接中断而退出 68；恢复同一签名包也会遇到该故障。

## Decision

发布和[原产物恢复](2026-11-05-resumable-notarization.md)共用标准 Apple Silicon runner `macos-15`，保留 Xcode 16.4。使用明确的系统版本标签，避免 `macos-latest` 自动迁移工具链。归档仍显式指定 `arm64 x86_64`，最终 ZIP 继续验证两种架构；runner 架构不改变发行包的支持范围。

保留公证 Accepted、票据附加与验证、签名团队、Gatekeeper 和 Sparkle 更新签名检查。恢复旧版本只更换执行环境，继续校验原标签提交、原签名包和公证 ID，复用原构建号。

## Alternatives considered

- 在 Intel runner 上反复重跑或增加重试：仍经过已确认不稳定的网络路径，且多次票据请求均可能失败。
- 在 Intel runner 上阻断 UDP 443 以强制 TCP：上游提供此临时方案，但需要额外的特权网络配置；标准 Apple Silicon runner 已提供所需 Xcode 和分发工具。
- 删除票据验证或允许网络错误通过：会削弱最终发行包的验收契约。

## Consequences

标准 Apple Silicon runner 的内存和 CPU 配额与 Intel runner 不同；首次双架构归档及实际票据请求由真实发布运行验证。本地发布守卫与 actionlint 只能证明脚本、配置和接纳条件，不能证明 GitHub 到 Apple 的网络可用。上游故障修复后可重新评估宿主选择，无需更改产物格式或恢复协议。

回退时还原 runner 标签及对应开发文档，不移动既有版本标签，也不重建已公证的恢复包；回退会重新暴露 Intel 网络故障。
