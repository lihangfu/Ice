# Agent Note: Reader-focused README

Status: implemented

## Problem

README 同时承载用户介绍和维护操作，构建、验证、发布及签名配置占据首页大部分篇幅，用户难以快速找到安装方式和功能。

## Decision

中英文 README 面向应用使用者，保留项目介绍、安装、功能、使用限制、常见问题入口和许可证。开发文档只在首页提供简短链接。

[开发文档](../../../development.md)及[英文版](../../../development.en.md)拥有本地构建、验证、发布、更新签名、Apple 签名与公证、发布恢复的操作契约，以及外观设置迁移和旧字段处理的兼容说明。迁移时保留完整步骤和限制，并按新位置修正相对链接。

这项决定取代[独立项目文档](2026-11-05-independent-project-documentation.md)将构建与发布说明放在 README 的部分；语言入口及居中展示继续遵循[双语 README](2026-11-05-bilingual-readme.md)的决定。

## Alternatives considered

- 将维护说明折叠在 README 中：仍将两类读者的内容绑定在首页，难以保持用户介绍简洁。
- 直接删除维护说明：会丢失现有构建、签名及发布恢复契约。

## Consequences

用户文档和维护文档分别保持中英文语义一致。更新开发命令或发布配置时修改开发文档；README 只同步用户可见的要求和行为。
