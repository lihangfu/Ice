# Agent Note: Command Line Tools build

Status: implemented

## Problem

只有 Command Line Tools（命令行开发工具）的机器缺少 `xcodebuild` 和 `actool`，无法直接构建现有 Xcode 工程。开发者需要从同一份源码启动完整 Ice，包括菜单栏管理、第三方依赖、图标、中文文案和设置窗口。

## Decision

新增 Swift Package Manager（Swift 包管理器）入口及本地应用打包脚本。Package.swift 从现有 Xcode 锁文件读取依赖提交，不单独维护依赖版本；打包时从 Xcode 工程读取版本、标识和系统要求。根目录自动生成的 Package.resolved 是派生文件，忽略提交。

SwiftPM 原样复制资产目录；IceAssets 读取当前图片的倍率、模板标记和明暗颜色，以避开 actool，同时保持资产目录为唯一来源。Xcode 构建仍走系统资产加载。仅供 Xcode 画布使用的预览宏不参与 SwiftPM 构建。

本地脚本将可执行文件、资源包、主包本地化、应用图标和 Sparkle 框架放入完整应用包，使用临时签名。资源先从应用包内查找，避免依赖 SwiftPM 生成访问器中指向构建目录的绝对路径。应用已运行时拒绝覆盖，打包或签名失败时不删除原有应用。

本地包显式标记 IceLocalBuild，更新管理器不启动，设置页说明更新停用；防止正式发布版替换开发产物。Xcode 发布流程继续拥有分发和更新签名。

## Alternatives considered

- 直接使用 swiftc 并手动编译全部依赖：需要维护第三方模块的编译顺序、框架查找与链接细节，SwiftPM 已提供这些能力。
- 从已安装的 Ice.app 复制编译后的资源和框架：依赖用户先安装旧版，且源码变更可能与旧资源不匹配。
- 只提供设置预览：无法验证或启动真正的菜单栏应用，不满足完整项目启动要求。
- 新建独立资源副本及手工版本清单：容易与 Xcode 工程及原资产目录漂移。

## Consequences

本地要求 macOS 14 及 Swift 6 或更新的 Command Line Tools，首次解析依赖需要联网。打包脚本使用系统 Python 3、iconutil 和 codesign，不需要完整 Xcode；产物只包含当前机器架构，不是通用分发包，也不替换 Applications 目录中的安装版本。

本地应用沿用 Ice 的标识和偏好，但临时签名可能需要用户重新授予系统权限。`--validate-build` 在状态初始化和迁移前执行实际二进制的资源检查；Tests/run-build-tests.py 检查搬迁、签名、图标模板及倍率、明暗颜色、本地化和资源缺失时的失败。真实菜单栏交互与系统授权仍需图形会话验证，不能由资源检查代替。

本机验证覆盖 Apple Silicon 的调试构建、完整应用打包、运行和资源检查，以及发布优化编译；发布优化打包因调试应用正在运行而被保护检查拒绝。尚未在 Intel 或完整 Xcode 环境执行本次兼容性回归。
