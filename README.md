# reduce-ai-text · 中文全场景降 AI 改写 Skill

一个可安装到多种 AI Agent 的中文文本改写技能：把大模型生成的模板化、机械化文本，改写为符合人类母语写作者习惯的自然表达。英文输入则保持英文输出，沿用同样的自然化原则。

## Skill 功能

**核心任务**：对文本进行"去 AI 化"重写。先判断文体、受众、写作目的、正式度和结构约束，再选择相应策略；目标是消除 AI 模板痕迹和冗余填充，而不是压缩内容、改变原意或强行"文学化"。

**覆盖文体**（各有一套改写尺度，不用同一套口语化标准）：

| 文体 | 处理要点 |
|---|---|
| 学术论文 / 学位论文 / 期刊论文 | 删"值得注意的是"等填充和"XX是YY的重要线索"式价值声明，保留术语、数据、引用、公式 |
| 小说 / 故事 / 叙事散文 | 删"心中涌起暖流"式情绪总结，用动作、感官、对话呈现；不改情节和人物关系 |
| 诗歌 | 最高阈值，保留分行、韵律、意象；不改散文化、不轻易动 |
| 报告 / 总结 / 商业分析 | 删"在当今背景下""持续赋能"等套话，事实和数据先行 |
| 公文 / 通知 / 政策文本 | 保持庄重规范，只删空泛修饰，不动条款和固定表述 |
| 新闻稿 / 通讯 | 删"引发广泛关注"等宣传腔，保留时间地点人物数据和引语 |
| 散文 / 随笔 / 评论 | 删"不禁让人深思"式元评论，保留观点锋芒 |
| 剧本 / 对话稿 | 保留场景格式，对白符合人物身份 |
| 技术文档 | 步骤、编号、警告、代码原样保留，只删填充词 |
| 文案 / 新媒体 | 可适度口语化，删"赋能""闭环"等滥用词 |

**改写原则**：保留原意与实质信息（不增事实、不减数据）；保持文体正式度（学术/公文/新闻不降级为口语）；保留 LaTeX 公式、引用编号、代码块、表格、诗歌分行等原始标记；禁止空洞价值声明和"总括—分述"模板；已自然的文本检测通过后原样保留。

**自进化机制**：每次调用会在当前工作区维护 `.reduce-ai-text/` 正反例库（positive/negative），改写前检索同类案例规避模板，改写后沉淀用户反馈的案例；候选规则须经人工确认才可补充主规则，可回滚。

**输出格式**：Part 1 输出改写后文本（已足够好则输出原文），Part 2 输出修改日志或"[检测通过]"评价，无多余对话。完整规则见 [SKILL.md](SKILL.md)。

## 触发方式

skill 通过关键词触发，安装后在支持它的 Agent 中说"降AI / 去AI / 降低AI痕迹 / 去AI化 / 人工化改写 / 改得像人写的 / 小说去AI / 论文降AI / 报告去AI"，或明确要求降低 AI 痕迹、自然化改写即可。

## 多 Agent 适配

仓库以根目录 [SKILL.md](SKILL.md) 为唯一事实来源（SSOT），[install.ps1](install.ps1) 自动转换 frontmatter 并分发，避免手工维护多份副本。

### 已适配的 Agent

| Agent | 项目级路径 | 全局路径 | 格式 |
|---|---|---|---|
| Claude Code | `.claude/skills/reduce-ai-text/SKILL.md` | `~/.claude/skills/...` | SKILL.md |
| Trae | `.trae/rules/reduce-ai-text.md` | `~/.trae-cn/skills/...` | SKILL.md / 规则 |
| Cursor | `.cursor/rules/reduce-ai-text.mdc` | `~/.cursor/rules/...` | mdc 规则 |
| Windsurf | `.windsurf/rules/reduce-ai-text.md` | `~/.codeium/windsurf/memories/rules.md` | 规则（model_decision） |
| Codex | `AGENTS.md`（标记区块幂等合并） | `~/.codex/AGENTS.md` | 纯 Markdown |
| GitHub Copilot | `.github/instructions/reduce-ai-text.instructions.md` | 无全局约定，跳过 | instructions |
| DeepSeek Harness | `.agents/skills/reduce-ai-text/SKILL.md` | `~/.agents/skills/...` | SKILL.md（agent-skills 标准） |

### 安装

```powershell
.\install.ps1                                # 装到当前项目 + 用户全局（所有 agent）
.\install.ps1 -Scope project                 # 只装当前项目
.\install.ps1 -Scope global -Targets claude  # 只把 claude 装到全局
.\install.ps1 -Export -OutputDir .\adapters  # 只导出适配文件（跨平台手动复制用）
```

不跑脚本也可手动复制：[adapters/](adapters/) 目录按 agent 分好了现成的格式转换结果。

### DeepSeek Harness 适配说明

DSH 的接入分三层，均已覆盖：

1. **原生技能**：DSH 原生技能根为 `.dsh/skills` 与 `.agents/skills`，遵循 agent-skills 标准——目录名 kebab-case，SKILL.md frontmatter 必须含 `name`（与目录同名）和 `description`（≤1024 字符）。本 skill 的 `reduce-ai-text` 目录名与描述均满足；安装到 `.agents/skills/` 后优先级高于所有 bridge 资产。
2. **指令记忆**：DSH 自带 loader 会逐级读取项目根到工作目录之间的 `AGENTS.md` / `CLAUDE.md`（含 `.local` 变体），因此 codex 目标生成的 `AGENTS.md` 已被直接识别，无需重复安装。
3. **bridge 复用**：安装 `dsh-bridges` 插件后，已就位的 `.claude/`、`.cursor/` 等 Claude Code / Cursor / Codex / Gemini / OpenCode / CodeBuddy / Pi 资产会被桥接进 DSH（技能、记忆、hooks、MCP），会话内热加载。

## 维护方式

只改根目录 `SKILL.md`，然后重跑 `.\install.ps1` 即可同步全部 agent；不要直接编辑 `adapters/` 或各 agent 目录下的生成文件。Codex 的 `AGENTS.md` 与 Windsurf 全局规则为共享文件，脚本用 `<!-- reduce-ai-text:start/end -->` 标记区块做幂等合并，重复执行不会产生重复内容。

注意：Windows PowerShell 5.x 要求脚本为带 BOM 的 UTF-8，重新保存时请保持该编码，否则中文注释会解析失败。
