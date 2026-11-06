# Agent Note: Notarization ticket transport

Status: implemented

## Problem

GitHub 托管 runner 到 Apple CloudKit 的 HTTP/3 连接存在[已确认的网络故障](https://github.com/actions/runner-images/issues/14924)。公证已经 Accepted、票据已经附加的应用，仍可能在后续 `stapler validate` 时因连接中断而退出 68。Apple Silicon runner 也复现了该故障，切换宿主架构不能消除对故障传输协议的依赖。

## Decision

保留标准 Intel runner `macos-15-intel` 和 Xcode 16.4。明确指定系统版本，避免 `macos-latest` 自动迁移工具链；归档和最终包继续验证 `arm64 x86_64`。

首次发布与[原产物恢复](2026-11-05-resumable-notarization.md)在附加票据前阻断出站 UDP 443，让系统自动回退到 TCP。使用系统默认 `com.apple/*` 挂载点中的独立 `com.apple/ice-notarization` PF anchor，先确认过滤挂载点存在，再加载规则并启用过滤，最后输出已加载的规则。保持系统主规则原样；配置失败即终止发布。

规则覆盖后续全部票据附加及验证请求。公证 Accepted、签名团队、票据、Gatekeeper 和 Sparkle 更新签名检查全部保留。恢复继续绑定原标签提交、签名包、公证 ID 和构建号，不为修复网络重新构建或移动标签。

## Alternatives considered

- 更换宿主架构：Apple Silicon 也复现 HTTP/3 连接中断，不能提供稳定的规避边界。
- 反复重跑或增加重试：仍使用故障协议，多次票据请求均可能失败。
- 用 PF 主规则集直接加载上游示例规则：可能冲掉系统已有规则，使用独立 anchor 保留其余规则。
- 删除票据验证或允许网络错误通过：会削弱最终发行包的验收契约。

## Consequences

此配置只用于每个任务独占的标准 GitHub 托管虚拟机。规则与本任务持有的 PF 启用引用由虚拟机销毁统一清理，不能直接复用于持久化或共享的自托管 runner。UDP 443 阻断也影响该任务后续其他 HTTP/3 请求，普通 TCP HTTPS 继续可用。

发布检查覆盖主规则保留、挂载点缺失及加载失败；真实恢复运行验证 CloudKit 可达性和完整分发检查。上游问题修复后可删除该步骤。回退工作流及对应测试、文档即可恢复原网络行为；既有公证提交、版本标签和已发布产物保持原样。
