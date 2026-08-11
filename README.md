# skills

Reusable agent skills maintained by [walkthewalktoday](https://github.com/walkthewalktoday).

## Install

List the skills in this repository:

```bash
npx skills add walkthewalktoday/skills --list
```

Install `goodnotes-to-logseq-todos` globally for Codex:

```bash
npx skills add walkthewalktoday/skills --skill goodnotes-to-logseq-todos --agent codex --global
```

Add `-y` for a non-interactive installation.

## Available skills

### goodnotes-to-logseq-todos

Read a dated handwritten Goodnotes PDF from a Google Drive desktop mount, turn each numbered note into a separate TODO, and safely insert the tasks under the matching Logseq journal's `今日TODO` block.

Example prompt:

```text
Use $goodnotes-to-logseq-todos to sync today's Goodnotes work notes into my Logseq TODOs.
```

The skill treats Google Drive as read-only, preserves unrelated Logseq content, avoids duplicate tasks, exposes uncertain handwriting, and does not commit or push the Logseq repository unless explicitly requested.
