# 田野建筑工作助手 | TIANYE Architecture Skill

面向田野建筑团队的通用引导式 AI 工作 Skill，兼容可读取 `SKILL.md` 的 Agent Skills 工具，主要用于 ZCode、WorkBuddy。版本 **v1.1.0**。

> **仅限田野建筑内部使用。请保持仓库为 Private。** 本仓库不包含实际客户合同和敏感项目资料；不要提交实际项目价格、联系人、合同或图纸。

## 安装

**ZCode：** 下载整个仓库（`Code → Download ZIP`），解压后将本目录（含 `SKILL.md`、`references/`、`templates/`）放在 ZCode 的技能目录中，例如 `~/.zcode/skills/tianye-architecture/`。在软件技能设置中刷新并启用。不同版本以客户端支持的目录为准。

**WorkBuddy：** 下载 ZIP，选择软件内的技能导入功能；如导入要求根目录直接包含 `SKILL.md`，请先解压 GitHub 仓库 ZIP，再将内容重新压成以 `tianye-architecture/` 为唯一顶层目录的技能 ZIP。也可以将技能目录放入客户端支持的工作区技能位置。

详细安装方法请读 [团队安装与使用说明](README_安装使用.md)，新同事请先读 [新人快速上手](新人快速上手_发给团队.md)。

## 如何使用

直接输入「帮我写一份项目工作联系函」或「帮我做一个项目分析报告」。信息不足时，助手先提 1–3 个关键问题，引导明确目的、事实和成果深度；需求清晰时直接输出。支持合同/服务书、项目策略、团队运营、商务函件、技术案例、翻译整理六类工作。

## 文件结构

- `SKILL.md`：技能入口与路由
- `references/`：核心规范、交互流程、交付质量及 M1–M6 专业模块
- `templates/`：可复用文档骨架
- `examples/`：新人示例对话
- `tests/`：功能与交互验收题

## 版本管理

内部更新请通过 Pull Request 审核，更新 `CHANGELOG.md` 并重新运行 `tests/` 的典型案例。关键合同、结构消防、幕墙和法规判断仍需专业负责人复核。

[变更记录](CHANGELOG.md) · [内部使用声明](LICENSE_INTERNAL.md)
