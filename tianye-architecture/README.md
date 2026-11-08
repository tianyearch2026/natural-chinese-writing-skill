# 田野建筑工作助手 | TIANYE Architecture Skill

面向田野建筑团队的通用引导式 AI 工作 Skill，兼容可读取 `SKILL.md` 的 Agent Skills 工具，主要用于 ZCode、WorkBuddy。版本 **v1.2.0**。

> 本技能公开分享工作方法及品牌模板。田野标志、抬头纸、联系方式和二维码供田野团队及获授权人员使用；其他机构请换用自己的品牌素材。实际客户合同、价格、个人联系资料和图纸保存在各自授权的项目目录。详见 [使用声明](LICENSE_INTERNAL.md)。

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


## v1.2 Word 抬头纸与字体
随包包含 [Word 抬头纸](assets/tianye_letterhead_v03.docx)、单页联系函及两页踏勘报告示范。规范见 [正式文书](references/word_letterhead.md)，Windows 字体检查与缺字部署见 [字体设置](references/font_setup.md)。生成文件前运行字体检查，生成后更新页码并检查PDF和逐页图像。

技能ZIP包含完整目录及工具。字体来自小米官网，不附带字体文件。首次下载和安装须由使用者确认许可；已安装时直接复用。脚本运行、Word生成与客户端自动触发均取决于实际工具环境，单纯导入ZIP不代表这些环节已验证。当前本机通过WPS验证，微软Word、WorkBuddy和ZCode的实际自动触发另行核验。

## 完整安装包
[下载田野建筑工作助手 v1.2.0](../tianye_architecture_v1_2_0_20261108.zip)
