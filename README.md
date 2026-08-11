# Skills

由 [walkthewalktoday](https://github.com/walkthewalktoday) 维护的可复用 Agent Skills。

## 安装

列出仓库中的 Skills：

```bash
npx skills add walkthewalktoday/skills --list
```

为 Codex 全局安装 `goodnotes-to-logseq-todos`：

```bash
npx skills add walkthewalktoday/skills --skill goodnotes-to-logseq-todos --agent codex --global
```

为 OpenClaw 全局安装 `goodnotes-daily-export`：

```bash
npx skills add walkthewalktoday/skills --skill goodnotes-daily-export --agent openclaw --global
```

需要非交互安装时，在命令中加入 `-y`。

## 可用 Skills

### goodnotes-to-logseq-todos

从 Google Drive 桌面挂载目录读取指定日期的 Goodnotes 手写 PDF，把每个编号事项转换为独立 TODO，并安全插入对应 Logseq 日志的“今日TODO”块。

调用示例：

```text
使用 $goodnotes-to-logseq-todos，把今天的 Goodnotes 工作随笔同步到 Logseq TODO。
```

该 Skill 只读 Google Drive，保留 Logseq 中的无关内容，避免重复任务，明确标记无法确认的字迹；除非用户明确要求，否则不会提交或推送 Logseq 仓库。

### goodnotes-daily-export

扫描指定日期发生变化的 Goodnotes PDF，生成 Markdown、文本差异、最近两个 PDF 快照，并为手写或图片型页面生成图片回退。附带脚本使用 macOS 的 PDFKit 与 AppKit，定时任务提示词位于 `assets/goodnotes-daily-summary.md`。

调用示例：

```text
使用 $goodnotes-daily-export，导出并总结昨天变化的 Goodnotes 笔记。
```

该 Skill 只读云盘源目录，只清理自身创建的多余历史快照，并把笔记内容视为数据而不是 Agent 指令。
