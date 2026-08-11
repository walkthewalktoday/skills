---
name: goodnotes-to-logseq-todos
description: 从 Google Drive 桌面挂载目录读取指定日期的 Goodnotes 手写工作笔记 PDF，把每个编号事项转写为独立 TODO，并安全插入对应 Logseq 日志的“今日TODO”块。用户要求同步、导入、整理或写入今天或指定日期的 Goodnotes 笔记到 Logseq TODO 时使用，支持 Windows 与 macOS。
---

# Goodnotes 转 Logseq TODO

把指定日期的 Goodnotes 手写工作笔记 PDF 转换为有序的 Logseq TODO 块，同时保留日志原有内容和工作区中的未提交修改。

## 确定日期与路径

1. 用户指定日期时使用该日期；否则使用用户所在时区的当天日期。
2. 用户明确提供源文件或 Logseq 图谱路径时，优先使用该路径。
3. 未提供源文件路径时，只在以下有限候选位置查找准确的 `YYYYMMDD.pdf`：
   - Windows 个人默认位置：`G:\我的云端硬盘\GoodNotes\工作随笔\YYYYMMDD.pdf`
   - Windows 文件资源管理器可见的 Google Drive 盘符下：`My Drive/GoodNotes/工作随笔` 或 `我的云端硬盘/GoodNotes/工作随笔`
   - macOS Finder 可见的 Google Drive 位置，通常位于 `~/Library/CloudStorage/GoogleDrive-*/My Drive/GoodNotes/工作随笔`
4. 优先读取准确的本地文件。只要本地文件存在，就不要改用浏览器或 Google Drive 连接器。
5. 本地文件不存在时，使用可用的 Google Drive 连接器，在 `GoodNotes/工作随笔` 下查找日期完全匹配的文件。
6. 找不到文件或存在多个候选文件时，询问用户。不要根据模糊日期猜测，也不要扫描整块磁盘。
7. 在本流程中只读 Google Drive，不要修改云端文件。

按以下顺序确定 Logseq 图谱：

1. 使用用户提供的路径。
2. 使用正在运行的 Logseq API 返回的当前图谱。
3. 当 `D:\github.com\logseq` 存在时，将其作为个人默认路径。
4. 仍无法确定时，询问用户图谱目录。

对于文件型图谱，目标文件为 `journals/YYYY_MM_DD.md`。对于 DB 图谱，通过 Logseq API 写入，不要假定存在日志 Markdown 文件。

## 写入前检查

1. 读取当前可用的 Logseq 与 PDF Skill。
2. 检查目标 Logseq 图谱的 Git 状态，并以 UTF-8 读取目标日志。
3. 保留所有已有及无关修改。除非用户明确要求，否则不要执行提交、拉取、变基或推送。
4. 检查现有“今日TODO”块，收集已有 TODO 文本，用于重复检测。

## 读取手写 PDF

1. 使用 Poppler 或可用的 PDF 渲染器，把 PDF 的每一页渲染为高分辨率 PNG。不要依赖 PDF 文本提取；Goodnotes 手写笔记通常没有文本层。
2. 逐页目视检查渲染图片。字迹难以辨认时，使用高分辨率局部裁剪继续确认。
3. 保留原始顺序和层级：
   - 每个顶层编号事项只转换为一条 TODO。
   - 使用分号或括号把下级说明合并进对应 TODO。
   - 技术标识符保持原样。
4. 不要臆测模糊字迹。无法确认的片段使用 `[字迹待确认：…]`；当不确定内容会改变任务含义时，询问用户。

## 写入日志

1. Logseq API 可用时优先使用 API；否则用最小补丁编辑日志文件。
2. 按文件原有缩进格式，把任务作为子块插入准确的 `- 今日TODO` 块：

   ```markdown
   - 今日TODO
     - TODO 第一项
     - TODO 第二项
   ```

3. 存在空占位子块时，只替换该占位。不要替换已有 TODO、日志查询、“今日主题”、属性或其他无关块。
4. 不存在“今日TODO”时，在不重构日志的前提下追加该块。日志文件不存在时，只创建与相邻日志一致的最小结构。
5. 去掉空白与任务标记后，若某事项已存在，则跳过它。重复执行时不要生成重复任务。

## 验证并报告

1. 重新读取日志，核对新增数量、原始顺序、周边内容是否保留，以及目标 Git 状态。
2. 清理临时生成的 PDF 页面图片。
3. 报告源 PDF、目标日志、新增与跳过数量，以及所有 `[字迹待确认]` 片段。
4. 除非用户要求执行 Git 操作，否则说明修改仍未提交。
