# reduce-ai-text · 多 Agent 适配版

中文全场景降 AI 改写 skill。本仓库以根目录 [SKILL.md](SKILL.md) 为唯一事实来源（SSOT），通过 [install.ps1](install.ps1) 自动转换为各 AI Agent 的规则/技能格式，避免手工维护多份副本。

## 已适配的 Agent

| Agent | 项目级路径 | 全局路径 | 格式 |
|---|---|---|---|
| Claude Code | `.claude/skills/reduce-ai-text/SKILL.md` | `~/.claude/skills/...` | SKILL.md |
| Trae | `.trae/rules/reduce-ai-text.md` | `~/.trae-cn/skills/...` | SKILL.md / 规则 |
| Cursor | `.cursor/rules/reduce-ai-text.mdc` | `~/.cursor/rules/...` | mdc 规则 |
| Windsurf | `.windsurf/rules/reduce-ai-text.md` | `~/.codeium/windsurf/memories/rules.md` | 规则（model_decision） |
| Codex | `AGENTS.md`（标记区块幂等合并） | `~/.codex/AGENTS.md` | 纯 Markdown |
| GitHub Copilot | `.github/instructions/reduce-ai-text.instructions.md` | 无全局约定，跳过 | instructions |
| DeepSeek Harness | `.agents/skills/reduce-ai-text/SKILL.md` | `~/.agents/skills/...` | SKILL.md（agent-skills 标准） |

## 用法

```powershell
.\install.ps1                                # 装到当前项目 + 用户全局（所有 agent）
.\install.ps1 -Scope project                 # 只装当前项目
.\install.ps1 -Scope global -Targets claude  # 只把 claude 装到全局
.\install.ps1 -Export -OutputDir .\adapters  # 只导出适配文件（跨平台手动复制用）
```

## 维护方式

只改根目录 `SKILL.md`，然后重跑 `.\install.ps1` 即可同步全部 agent；不要直接编辑 `adapters/` 或各 agent 目录下的生成文件。Codex 的 `AGENTS.md` 与 Windsurf 全局规则为共享文件，脚本用 `<!-- reduce-ai-text:start/end -->` 标记区块做幂等合并，重复执行不会产生重复内容。

注意：Windows PowerShell 5.x 要求脚本为带 BOM 的 UTF-8，重新保存时请保持该编码，否则中文注释会解析失败。

## DeepSeek Harness 适配说明

DeepSeek Harness（DSH）的接入分三层，均已覆盖：

1. **原生技能**：DSH 原生技能根为 `.dsh/skills` 与 `.agents/skills`，遵循 agent-skills 标准——目录名 kebab-case，SKILL.md frontmatter 必须含 `name`（与目录同名）和 `description`（≤1024 字符）。本 skill 的 `reduce-ai-text` 目录名与描述均满足；安装到 `.agents/skills/` 后优先级高于所有 bridge 资产。
2. **指令记忆**：DSH 自带 loader 会逐级读取项目根到工作目录之间的 `AGENTS.md` / `CLAUDE.md`（含 `.local` 变体），因此 codex 目标生成的 `AGENTS.md` 已被直接识别，无需重复安装。
3. **bridge 复用**：安装 `dsh-bridges` 插件后，已就位的 `.claude/`、`.cursor/` 等 Claude Code / Cursor / Codex / Gemini / OpenCode / CodeBuddy / Pi 资产会被桥接进 DSH（技能、记忆、hooks、MCP），会话内热加载。
