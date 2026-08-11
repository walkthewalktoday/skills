---
name: goodnotes-to-logseq-todos
description: Read a dated handwritten Goodnotes work-note PDF from a Google Drive desktop mount, transcribe each numbered note into a separate TODO, and safely insert the tasks under the matching Logseq journal's 今日TODO block. Use when the user asks to sync, import, summarize, or write today's or a specified date's Goodnotes notes into Logseq TODOs on Windows or macOS.
---

# Goodnotes To Logseq TODOs

Convert one dated Goodnotes work-note PDF into ordered Logseq TODO blocks while preserving the journal's existing content and dirty-worktree state.

## Resolve the date and paths

1. Use the explicit date from the request; otherwise use today's date in the user's local timezone.
2. Use an explicit source or Logseq graph path from the user when provided.
3. Otherwise, look for the exact `YYYYMMDD.pdf` only in these narrow candidates:
   - Windows personal default: `G:\我的云端硬盘\GoodNotes\工作随笔\YYYYMMDD.pdf`
   - Windows Google Drive volumes visible in File Explorer, under `My Drive` or `我的云端硬盘/GoodNotes/工作随笔`
   - macOS Google Drive locations visible in Finder, commonly under `~/Library/CloudStorage/GoogleDrive-*/My Drive/GoodNotes/工作随笔`
4. Prefer an exact local file. Do not use a browser or Drive connector when it exists.
5. If the local file is absent, use an available Google Drive connector to locate the exact dated file under `GoodNotes/工作随笔`.
6. If zero or multiple candidates remain, ask the user. Do not guess from a fuzzy date or search an entire disk.
7. Treat Google Drive as read-only for this workflow.

Resolve the Logseq graph in this order:

1. Use the path supplied by the user.
2. Use the current graph reported by a running Logseq API.
3. Use `D:\github.com\logseq` when it exists as the personal default.
4. Otherwise ask for the graph directory.

For file graphs, target `journals/YYYY_MM_DD.md`. Adapt through the Logseq API for a DB graph instead of assuming a journal Markdown file.

## Inspect before writing

1. Read the available Logseq and PDF skills.
2. Inspect targeted Git status in the resolved Logseq graph and read the journal as UTF-8.
3. Preserve all pre-existing and unrelated changes. Never commit, pull, rebase, or push unless the user explicitly asks.
4. Check the existing `今日TODO` block and collect its TODO text for duplicate detection.

## Read the handwritten PDF

1. Render every PDF page to high-resolution PNG with Poppler or the available PDF renderer. Do not rely on PDF text extraction; Goodnotes handwriting often has no text layer.
2. Visually inspect every rendered page. Use focused high-resolution page crops when handwriting is hard to read.
3. Preserve the source order and hierarchy:
   - Convert each numbered top-level note into exactly one TODO.
   - Merge subordinate lines into that TODO using semicolons or parentheses.
   - Keep technical identifiers verbatim.
4. Do not invent unclear handwriting. Use `[字迹待确认：…]` for an uncertain fragment, or ask the user when uncertainty changes the task's meaning.

## Write the journal

1. Prefer the Logseq API when available. Otherwise edit the journal file with a minimal patch.
2. Insert tasks as child blocks under the exact `- 今日TODO` block using the file's existing indentation style:

   ```markdown
   - 今日TODO
     - TODO 第一项
     - TODO 第二项
   ```

3. Replace only an empty placeholder child when present. Never replace existing TODOs, journal queries, `今日主题`, properties, or unrelated blocks.
4. If `今日TODO` is missing, append that block without restructuring the journal. If the journal is missing, create only the minimal structure consistent with adjacent journal files.
5. Skip an item already present after trimming whitespace and the task marker. Do not duplicate tasks across repeated runs.

## Verify and report

1. Re-read the journal and verify the inserted count, original order, preserved surrounding content, and targeted Git status.
2. Clean up temporary PDF renders.
3. Report the source PDF, target journal, inserted and skipped counts, and any `[字迹待确认]` fragments.
4. State that changes remain uncommitted unless the user asked for Git operations.
