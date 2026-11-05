# 开发与发布

[返回项目介绍](../README.md) · **简体中文** · [English](development.en.md)

本文面向开发者和维护者，包含本地构建、验证、发布、签名与公证说明。以下命令均在仓库根目录执行。

## 无需 Xcode，在本地构建和运行

需要 macOS 14 或更高版本，以及包含 Swift 6 或更高版本的 Command Line Tools（命令行工具）。如未安装，可运行 `xcode-select --install`。无需安装完整的 Xcode。首次构建需要联网下载现有 Xcode `Package.resolved` 锁定的依赖，后续构建会复用 SwiftPM 缓存。

```sh
./scripts/run-app.sh
```

该命令会按当前 Mac 的架构构建源码，打包并本地签名 `build/Ice.app`，然后启动应用。重新构建前，请先退出正在运行的 `build/Ice.app`。如需只构建而不启动，或构建经过优化的本地版本：

```sh
./scripts/build-app.sh
./scripts/build-app.sh release
```

请使用打包后的 `.app`，不要使用 `swift run`：Ice 需要应用包中的元数据、图标、翻译和内嵌的 Sparkle 框架。脚本使用 Command Line Tools 提供的 Python 3 和 macOS 内置打包工具，不会安装或替换 `/Applications/Ice.app`。本地应用与 Ice 共用 bundle identifier（应用包标识符）和偏好设置；macOS 可能要求你为本地签名的应用重新授予辅助功能和屏幕录制权限。使用前请退出其他 Ice 实例。

本地构建会禁用在线更新，避免发行版替换开发中的应用。本地构建采用临时签名（ad-hoc），未经 Apple 公证。对外分发仍使用下文的 Xcode 发布工作流及其更新签名密钥。

构建完成后，验证实际应用包和本地化资源：

```sh
python3 Tests/run-build-tests.py
bash Tests/run-localization-tests.sh
```

应用包检查会在迁移或请求权限之前运行真实可执行文件，验证资源、图片缩放、浅色和深色配色、翻译、元数据、签名及应用包移动后的行为，并确认缺失资源时会失败。它还会检查旧版外观设置的迁移，但不会操作菜单栏项目或授予 macOS 权限。如需在两种系统主题下，以小、中、大三种侧边栏尺寸渲染外观编辑器和通用设置内容，并验证 Ice Bar 的外观与图标：

```sh
build/Ice.app/Contents/MacOS/Ice --validate-appearance build/appearance-validation
```

这些检查覆盖组件，不能作为设置窗口标题栏及边框的验收依据。请单独验证实际使用的 SwiftUI 设置场景：

```sh
build/Ice.app/Contents/MacOS/Ice --validate-settings-scene build/settings-scene-validation
```

该命令会在场景启动后打开真实设置窗口，跳过迁移、权限请求和正常的菜单栏初始化，并使用默认设置模型。它会截取全部六个分页在浅色和深色、滚动及回顶、宽窗口和缩回最小宽度时的状态；检查滚动不会重绘侧栏标题区，并验证窗口几何观察器在脱离窗口时会取消观察并恢复配置。退出前会恢复外观、窗口位置与尺寸和当前分页。

`scene-properties.json` 记录原生工具栏几何和实际激活状态，不会强制材质进入活动状态。其他 macOS 版本和辅助功能偏好仍需人工检查。

负向对照可追加 `--opaque-settings-window-control`，重新启用已移除的全窗口不透明标志，或追加 `--compact-settings-toolbar-control`，使用错误的工具栏配置。两者均预期以失败状态退出。已停用的 `--original-settings-titlebar-control` 会提示使用替代入口。

外观验证还会检查单色图标渲染、彩色角标保留和透明镂空，并截取实时状态栏项目作对比。设置布局检查还涵盖原生绘制、拖动预览颜色、禁用项目的淡化、点击命中和占位区域，且不会移动菜单栏项目。图标截图需要屏幕录制权限。如需确认对比度检查能捕获原先的浅色背景白色图标问题，请运行负向对照，预期该命令以失败状态退出：

```sh
build/Ice.app/Contents/MacOS/Ice --validate-appearance build/icon-negative --original-ice-bar-icons-control
```

设置布局的等效负向对照使用 `--original-layout-icons-control` 参数。

## 发布

[Release Ice 工作流](../.github/workflows/release.yml)会构建并发布 `Ice.zip`，以及包含更新签名的 `appcast.xml`，目标是标签推送到的仓库。本项目的发行版发布在 [lihangfu/Ice](https://github.com/lihangfu/Ice/releases)。

### 首次配置更新签名

除了下文的 Apple 签名身份，Sparkle 还需要一对可免费生成的 Ed25519 更新签名密钥。下载并解压 [Sparkle 2.6.4](https://github.com/sparkle-project/Sparkle/releases/tag/2.6.4)，在解压后的目录中运行：

```sh
umask 077
./bin/generate_keys --account lihangfu-Ice
./bin/generate_keys --account lihangfu-Ice -p
./bin/generate_keys --account lihangfu-Ice -x "$HOME/ice-sparkle-private-key.txt"
```

在仓库的 **Settings > Secrets and variables > Actions** 中配置：

- 仓库变量 `SPARKLE_PUBLIC_ED_KEY`：`-p` 打印的公钥。
- 仓库密钥 `SPARKLE_PRIVATE_ED_KEY`：导出的私钥文件内容。

请将私钥安全备份在仓库之外。后续发布应复用同一密钥对；更换密钥可能导致已安装的应用无法更新。使用 `xcodebuild` 进行本地构建时，也必须传入 `SPARKLE_PUBLIC_ED_KEY`。工作流会在构建前检查密钥是否缺失，并拒绝发布未签名的更新压缩包或由不匹配密钥生成的更新源。

### 首次配置 Apple 签名与公证

需要有效的 Apple Developer Program 会员资格，以及包含私钥的 Developer ID Application 证书。在“钥匙串访问”的 **login > My Certificates** 中，将签名身份导出为受密码保护的 `.p12` 文件，并保存在仓库之外。运行 `base64 -i /path/to/ice-signing.p12 | pbcopy` 将其转换为 Base64，然后在仓库 **Settings > Secrets and variables > Actions** 中配置以下 **Secrets**：

| 密钥 | 值 |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | 包含证书和私钥的 `.p12` 文件的 Base64 编码 |
| `APPLE_CERTIFICATE_PASSWORD` | 导出 `.p12` 时设置的密码 |
| `APPLE_TEAM_ID` | 证书所属的 10 位 Apple Developer Team ID |
| `APPLE_ID` | 用于公证、且有权访问该团队的 Apple 账户 |
| `APPLE_APP_SPECIFIC_PASSWORD` | 在 [Apple 账户](https://account.apple.com/)中生成的应用专用密码 |

工作流会将签名身份和 Apple Developer ID G2 中间证书导入 GitHub 托管 runner 的临时钥匙串。配置的团队必须恰好有一个有效的 Developer ID Application 签名身份；工作流会在构建前验证公证凭据。`.p12` 文件在导入后删除，钥匙串及其中的公证凭据会在任务结束时删除，失败时也会清理。凭据缺失或无效会导致发布失败，不会退回到无签名发布。

可使用 Python 3 和 macOS 系统 Ruby 在本地运行发布检查。检查使用 Ruby 内置的 YAML 和 JSON 库，无需安装 Python 包：

```sh
python3 Tests/run-release-tests.py
```

这些检查使用虚构凭据和公证结果执行工作流的准入脚本，并检查 shell 语法。它们不会导入真实私钥、归档应用或连接 Apple 公证服务。发布任务会在使用实际配置的凭据之前运行这些检查。

### 发布新版本

创建发布标签前，请先提交并推送工作流，确保标签指向的提交包含该工作流。新标签格式为 `vMAJOR.MINOR.PATCH`，例如：

```sh
git tag v0.11.15
git push origin v0.11.15
```

发布任务使用 GitHub 标准 macOS 15 Intel runner（`macos-15-intel`）和 Xcode 16.4，为 Apple Silicon 与 Intel Mac 归档并导出 Release 应用。应用版本来自标签，构建号来自 GitHub Actions 运行编号，仅在 CI 构建中设置。

Xcode 归档与导出工作流会使用 Developer ID 对应用及 Sparkle 内嵌辅助程序签名，并启用 Hardened Runtime（强化运行时）。工作流会将导出的应用提交给 Apple，最多等待 30 分钟，要求公证结果为 `Accepted`，并在生成最终 `Ice.zip` 前附加公证票据。超时会导致任务失败，但 Apple 可能仍在处理该提交。重试延迟的提交之前，请先查看任务日志中的提交 ID。

发布前，工作流会解压 `Ice.zip`，检查可执行文件、两种架构、代码签名和预期的 Developer ID 团队、公证票据、Gatekeeper 验收结果、应用版本和更新设置。随后使用锁定版本的 Sparkle 工具为压缩包签名、生成 appcast，并验证更新签名和元数据。

工作流使用具有 `contents: write` 权限的 GitHub `GITHUB_TOKEN` 发布发行版。如果仓库尚未启用 GitHub Actions，请在 Actions 页面启用。

自动和手动更新检查均读取本仓库最新发行版中的 `appcast.xml`，并下载已签名的 `Ice.zip`。从临时签名切换到 Developer ID 签名后，用户可能需要重新授予辅助功能和屏幕录制权限。

如果已安装的应用使用不同的更新源或签名密钥，请手动安装本仓库的发行版。验证更新源时，使用本仓库的两个 Release 构建：先在旧版中手动检查更新，再启用自动检查和下载，确认新版会被提示并成功安装。

工作流不会覆盖已有发行版。若发布失败，请先检查是否已创建不完整的草稿，再重新运行任务。如需撤回有问题的构建，请通过 GitHub 删除对应发行版，并使用新标签发布修正版。

如果发行版有问题，请手动安装本仓库已知可用的构建，保留同一签名密钥，再发布构建号更高的修正版。仅回退源码不会改变已安装的应用。如需回退此签名集成，请在创建新标签前回退工作流变更；旧版工作流会生成未经公证的临时签名构建。

请在 Developer ID 证书过期前轮换 `.p12` 密钥配置，保留同一团队和 Sparkle 更新签名密钥。Apple 签名身份的更换不能替代 Sparkle 更新签名密钥。

## 外观设置兼容性

着色、阴影、边框和形状在两种系统外观下共用一份配置。从动态外观设置升级时，Ice 会保留首次启动时生效的配置，并用于后续启动。独立的浅色和深色编辑器及预览控件已移除。

菜单栏背景模糊自定义功能已移除。已有的模糊强度设置会被忽略，并在保存外观设置时省略。着色、阴影、边框和形状设置仍可使用。Ice Bar 继续使用原生磨砂背景，并随系统浅色和深色外观变化。
