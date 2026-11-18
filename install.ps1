<#
.SYNOPSIS
  将 reduce-ai-text skill 一键适配并分发到各个 AI Agent。
.DESCRIPTION
  以根目录 SKILL.md 为唯一事实来源（SSOT），自动转换 frontmatter 格式后分发到：
  claude / trae / cursor / windsurf / codex / copilot
.EXAMPLE
  .\install.ps1                                # 安装到当前项目 + 全局（所有 agent）
  .\install.ps1 -Scope project                 # 只装到当前项目
  .\install.ps1 -Scope global -Targets claude  # 只把 claude 装到全局
  .\install.ps1 -Export -OutputDir .\adapters  # 只导出适配文件，不安装
#>
param(
  # 安装范围：project=当前项目，global=用户全局目录，all=两者
  [ValidateSet("project", "global", "all")]
  [string]$Scope = "all",
  # 目标 agent 列表，默认全部
  [string[]]$Targets = @("claude", "trae", "cursor", "windsurf", "codex", "copilot", "deepseek"),
  # 仅导出适配文件到指定目录，便于手动复制或跨平台使用
  [switch]$Export,
  [string]$OutputDir = ".\adapters"
)

$ErrorActionPreference = "Stop"

# ========== SSOT：读取并解析根目录 SKILL.md ==========
$skillFile = Join-Path $PSScriptRoot "SKILL.md"
if (-not (Test-Path $skillFile)) { throw "未找到 SSOT 文件：$skillFile" }

function Split-Frontmatter {
  # 解析 markdown 头部 frontmatter，返回 name/description 与正文
  param([string]$Content)
  $lines = $Content -split "`r?`n"
  if ($lines[0].Trim() -ne "---") { return @{ Name = ""; Description = ""; Body = $Content } }
  # 找到 frontmatter 结束行
  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "---") { $end = $i; break }
  }
  if ($end -lt 0) { return @{ Name = ""; Description = ""; Body = $Content } }
  # 逐行解析 key: value（容忍引号）
  $meta = @{}
  foreach ($line in $lines[1..($end - 1)]) {
    if ($line -match '^\s*(\w+)\s*:\s*"?(.*?)"?\s*$') { $meta[$Matches[1]] = $Matches[2] }
  }
  $body = ($lines[($end + 1)..($lines.Count - 1)] -join "`n").TrimStart()
  @{ Name = $meta["name"]; Description = $meta["description"]; Body = $body }
}

$skill = Split-Frontmatter -Content ([System.IO.File]::ReadAllText($skillFile, [System.Text.Encoding]::UTF8))

# ========== 各 agent 格式转换（每个函数只做一件事） ==========

function Convert-ToSkillMd {
  # Claude Code / Trae 的 SKILL.md 格式，与 SSOT 相同
  param($meta)
  "---`nname: `"$($meta.Name)`"`ndescription: `"$($meta.Description)`"`n---`n`n$($meta.Body)"
}

function Convert-ToCursorRule {
  # Cursor .mdc 规则：靠 description 触发，不强制全局生效
  param($meta)
  "---`ndescription: `"$($meta.Description)`"`nglobs:`nalwaysApply: false`n---`n`n$($meta.Body)"
}

function Convert-ToWindsurfRule {
  # Windsurf 规则：model_decision 由模型按描述自行触发
  param($meta)
  "---`ntrigger: model_decision`ndescription: `"$($meta.Description)`"`n---`n`n$($meta.Body)"
}

function Convert-ToCopilotInstruction {
  # GitHub Copilot instructions：applyTo 指定作用范围
  param($meta)
  "---`napplyTo: `"`**`"`ndescription: `"$($meta.Description)`"`n---`n`n$($meta.Body)"
}

function Convert-ToCodexSection {
  # Codex 无 frontmatter 机制，生成可追加进 AGENTS.md 的章节
  param($meta)
  "## $($meta.Name) skill`n`n$($meta.Body)"
}

# ========== 目标路径解析 ==========

function Get-Destination {
  # 返回指定 agent 在 project / global 两种范围的落盘路径映射
  param([string]$Target)
  $map = @{
    claude   = @{ project = ".claude/skills/reduce-ai-text/SKILL.md"; global = ".claude/skills/reduce-ai-text/SKILL.md"; converter = "Convert-ToSkillMd" }
    trae     = @{ project = ".trae/rules/reduce-ai-text.md";           global = ".trae-cn/skills/reduce-ai-text/SKILL.md";  converter = "Convert-ToSkillMd" }
    cursor   = @{ project = ".cursor/rules/reduce-ai-text.mdc";        global = ".cursor/rules/reduce-ai-text.mdc";         converter = "Convert-ToCursorRule" }
    windsurf = @{ project = ".windsurf/rules/reduce-ai-text.md";       global = ".codeium/windsurf/memories/rules.md";      converter = "Convert-ToWindsurfRule" }
    codex    = @{ project = "AGENTS.md";                               global = ".codex/AGENTS.md";                         converter = "Convert-ToCodexSection" }
    copilot  = @{ project = ".github/instructions/reduce-ai-text.instructions.md"; global = "";                             converter = "Convert-ToCopilotInstruction" }
    # DeepSeek Harness 原生技能目录遵循 agent-skills 标准（SKILL.md + name/description），
    # 项目级 .agents/skills 与用户级 ~/.agents/skills 均为原生根，优先级高于 bridge 资产
    deepseek = @{ project = ".agents/skills/reduce-ai-text/SKILL.md";         global = ".agents/skills/reduce-ai-text/SKILL.md";  converter = "Convert-ToSkillMd" }
  }
  if (-not $map.ContainsKey($Target)) { throw "未知目标：$Target（可选：claude trae cursor windsurf codex copilot deepseek）" }
  $map[$Target]
}

# 全局目录前缀（windsurf/codex 等全局路径基于用户主目录）
$globalBase = @{
  claude   = $HOME
  trae     = $HOME
  cursor   = $HOME
  windsurf = $HOME
  codex    = $HOME
  copilot  = $HOME
  deepseek = $HOME
}

function Write-Utf8File {
  # 统一以 UTF-8 无 BOM 写文件，避免部分 agent 识别异常
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Merge-CodeAgentsFile {
  # codex 的 AGENTS.md 采用标记区块做幂等合并：已存在则替换，否则追加
  param([string]$Path, [string]$Section)
  $start = "<!-- reduce-ai-text:start -->"
  $endMark = "<!-- reduce-ai-text:end -->"
  $block = "$start`n$Section`n$endMark"
  if (Test-Path $Path) {
    $existing = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($existing.Contains($start)) {
      # 用正则替换旧区块，保持文件其余部分不动
      $pattern = "(?s)" + [regex]::Escape($start) + ".*?" + [regex]::Escape($endMark)
      $merged = [regex]::Replace($existing, $pattern, $block.Replace("`n", "`n"))
      Write-Utf8File -Path $Path -Content $merged
      return
    }
    Write-Utf8File -Path $Path -Content ($existing.TrimEnd() + "`n`n" + $block + "`n")
  } else {
    Write-Utf8File -Path $Path -Content ($block + "`n")
  }
}

# windsurf 全局 rules.md 是共享文件，同样做幂等合并
function Merge-WindsurfGlobal {
  param([string]$Path, [string]$Content)
  Merge-CodeAgentsFile -Path $Path -Section $Content
}

# ========== 安装 / 导出主流程 ==========

$results = @()
foreach ($target in $Targets) {
  $dest = Get-Destination -Target $target
  $content = & $dest.converter $skill

  if ($Export) {
    # 导出模式：按 agent 名分目录，便于手动复制
    $outPath = Join-Path $OutputDir (Join-Path $target (Split-Path -Leaf $dest.project))
    Write-Utf8File -Path $outPath -Content $content
    $results += "export  -> $outPath"
    continue
  }

  # project 范围：写入当前项目（codex 特例走幂等合并）
  if ($Scope -in @("project", "all")) {
    $projPath = Join-Path (Get-Location).Path $dest.project
    if ($target -eq "codex") { Merge-CodeAgentsFile -Path $projPath -Section $content }
    else { Write-Utf8File -Path $projPath -Content $content }
    $results += "project -> $projPath"
  }

  # global 范围：写入用户主目录（copilot 无全局文件约定，跳过）
  if ($Scope -in @("global", "all")) {
    if ($target -eq "copilot") { $results += "global  -> copilot 无全局规则文件约定，已跳过"; continue }
    $gPath = Join-Path $globalBase[$target] $dest.global
    if ($target -eq "codex") { Merge-CodeAgentsFile -Path $gPath -Section $content }
    elseif ($target -eq "windsurf") { Merge-WindsurfGlobal -Path $gPath -Section $content }
    else { Write-Utf8File -Path $gPath -Content $content }
    $results += "global  -> $gPath"
  }
}

$results | ForEach-Object { Write-Host $_ }
Write-Host "`n完成：SSOT = $skillFile" -ForegroundColor Green
