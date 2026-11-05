# Agent Note: Chinese-first bilingual README

Status: implemented

## Problem

仓库首页只有英文说明，且介绍和徽章位于居中容器之外，与图标和标题的对齐方式不一致。

## Decision

`README.md` 提供默认中文文档，`README.en.md` 保留完整英文内容。两版顶部均提供语言切换链接，并突出当前语言，避免将两种语言的长篇安装与发布说明交错展示。

图标、标题、语言选择、介绍、来源说明和徽章使用同一个居中 HTML 容器；正文保留常规左对齐。在该容器中直接使用 HTML 链接和图片，避免依赖原始 HTML 块中的 Markdown 解析。

这项决定补充[独立维护项目文档](2026-11-05-independent-project-documentation.md)的内容归属。GitHub“关于”中的网站字段由仓库元数据拥有，移除上游官网链接需要直接修改该字段，修改 README 不会同步该设置。

## Alternatives considered

- 保留英文首页，只新增中文版：不能满足默认中文的阅读入口。
- 在同一 README 中逐段并列中英文：安装与发布说明较长，重复内容会增加阅读负担。

## Consequences

后续修改安装或功能说明时，需同步两份 README 的语义和链接。构建和发布说明由[面向用户的 README](2026-11-05-reader-focused-readme.md)决定移入独立的双语开发文档。语言切换只控制文档入口，不改变应用的语言设置。

渲染验证需覆盖介绍与徽章居中、正文左对齐以及双向语言链接。GitHub 仓库元数据与本地文档分别验证；回退本地文档不会恢复网站字段。
