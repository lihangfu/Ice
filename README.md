<div align="center">
    <img src="Ice/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="Ice" width="200" height="200">
    <h1>Ice</h1>
    <p><strong>简体中文</strong> · <a href="README.en.md">English</a></p>
    <p>Ice 是一款适用于 macOS 14 及更高版本的菜单栏管理工具。</p>
    <p>本项目基于 <a href="https://github.com/jordanbaird/Ice">jordanbaird/Ice</a>，由本仓库独立维护。</p>
    <p>
        <a href="https://github.com/lihangfu/Ice/releases/latest"><img src="https://img.shields.io/badge/download-latest-brightgreen?style=flat-square" alt="下载"></a>
        <img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square" alt="平台">
        <img src="https://img.shields.io/badge/requirements-macOS%2014%2B-fa4e49?style=flat-square" alt="系统要求">
        <a href="LICENSE"><img src="https://img.shields.io/github/license/lihangfu/Ice?style=flat-square" alt="许可证"></a>
    </p>
</div>

## 安装

从[最新发行版](https://github.com/lihangfu/Ice/releases/latest)下载 `Ice.zip`，解压后将应用移入“应用程序”（`Applications`）文件夹。

## 功能

设置项名称旁的圆形问号提供相关说明。悬停可阅读，点击或通过键盘激活帮助按钮可打开弹出说明。操作警告和状态信息会直接显示在设置页面中。

### 菜单栏项目管理

- 隐藏菜单栏项目
- 提供“始终隐藏”区域
- 鼠标悬停在菜单栏时显示隐藏项目
- 点击菜单栏空白区域时显示隐藏项目
- 在菜单栏中滚动或轻扫时显示隐藏项目
- 自动重新隐藏菜单栏项目
- 当应用菜单与已显示的菜单栏项目重叠时隐藏应用菜单
- 通过拖放排列各个菜单栏项目
- 在独立的 Ice Bar 中显示隐藏项目，适用于带刘海屏的 MacBook 等设备
- 搜索菜单栏项目
- 调整菜单栏项目间距（测试版）

### 菜单栏外观

- 菜单栏着色，支持纯色和渐变
- 菜单栏阴影
- 菜单栏边框
- 自定义菜单栏形状，支持圆角、分段或两者组合

### 快捷键

- 切换各个菜单栏区域的显示状态
- 显示搜索面板
- 启用或禁用 Ice Bar
- 显示或隐藏区域分隔图标
- 切换应用菜单的显示状态

### 其他

- 登录时启动
- 自动更新

## 为什么 Ice 仅支持 macOS 14 及更高版本？

Ice 使用了从 macOS 14 开始提供的系统 API。

## 外观

### Ice Bar 与菜单栏布局

Ice Bar 使用原生磨砂背景，模糊后方窗口的同时保持菜单栏图标清晰。它遵循 macOS 的“降低透明度”设置；开启后，模糊效果会替换为纯色背景。具有透明背景的单色图标会适应系统浅色和深色外观，上下裁剪边缘的微弱黑色阴影不影响识别。彩色图标或无法明确判断的截图会保留原色，包括带有彩色状态角标的混合图标。

这项适配同时用于 Ice Bar，以及设置中的可见、隐藏和始终隐藏区域。拖动预览使用相同的主题颜色，搜索结果保留原始图标。

### 菜单栏自定义

着色、阴影、边框和形状在浅色和深色外观下共用一份配置。菜单栏背景模糊不支持自定义。

[常见问题](FREQUENT_ISSUES.md) · [问题反馈](https://github.com/lihangfu/Ice/issues) · [开发文档](docs/development.md)

## 许可证

Ice 基于 [GPL-3.0 许可证](LICENSE)发布。
