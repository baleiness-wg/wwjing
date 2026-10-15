# AGENTS.md — echklst

## AGENTS.md版本

- v4

## OpenSpec & opencode 约定

- 所有 OpenSpec 技能（openspec-*）和命令（opsx-*）定义在父级 `/Users/Baleine/git/opencode/.opencode/`，由 opencode 自动向上继承
- 本地 `.opencode/` 不维护 openspec 技能副本，避免冗余
- 如需新技能，直接添加到父级 `.opencode/skills/` 和 `.opencode/commands/`

## 项目状态

当前为**wwj**。已有代码、文档。所有规则均为前瞻性约定，生成代码时须严格遵守。

---

## 技术约束

| 项目 | 值 |
|------|-----|
| 生成框架 | Plain HTML / JavaScript |
| 脚本语言 | JavaScript ES6+ |
| 运行环境 | VS Code Live Preview（无需 HTTP Server） |
| 跨域方案 | 不涉及 |
| 交互语言 | 中文 |
| 页面目标 | 在 Pad 浏览器上访问，不同目录对应不同功能，统一显示风格 |

---

## 开发工作流

本项目的开发流程基于 **OpenSpec** 变更管理：

- **探索** → `/opsx-explore` - 当项目specs目录不存在，但有original目录时，读取original目录下的文件，并生成 specs目录，将分析得到的信息和交互得到的信息写入 specs/spec.md
- **方案** → `/opsx-propose <change-name>` — 创建 proposal/design/tasks 等 artifact
- **实现** → `/opsx-apply` — 按 tasks 逐步实现代码；**实现完成后必须更新 `src/[模块]/build.json`**（`built` 设为当前时间 `yyyyMMddHHmm`，`llmodel` 设为所用模型名称）；如有接口定义，同步生成/更新 `src/[模块]/README.http`
- **归档** → `/opsx-archive` — 完成后归档变更记录

> `openspec` CLI 是底层工具。opsx 命令封装了完整工作流。

---

## 目录结构约定（AI 强制遵守）

**模块定义：**

模块根据 specs/ 子目录定义，允许创建多个模块；也允许不创建子目录，此时仅有一个spec.md，相关约定和规则中 [模块] 这一级目录将被忽略。

**根目录结构：**

| 路径 | 用途 | 状态 |
|------|------|------|
| `src/` | 业务代码（index.html / config.html / report.json / build.json） | 已完成 |
| `specs/[模块]/spec.md` | 归档后的需求规格（中文描述） | 已完成 |
| `original/` | 原始工程文件（原 spec.md / think.md / report.json） | 完成迁移后删除 |
| `openspec/changes/<name>/` | 活跃变更的 artifacts（proposal/design/specs/tasks） | 变更管理期间存在，归档后冻结 |
| `backups/[模块]/` | 修改前自动备份 | 变更期间存在 |

**规则：**

- 生成代码前**必须检查**对应模块的 `specs/[模块]/spec.md`（归档后）或 `openspec/changes/<change>/specs/<模块>/spec.md`（变更期间）
- 实现代码放入 `src/` 下
- 全局类型/错误 → 仅限 `specs/core/spec.md`
- 禁止在根目录创建业务文件
- 禁止修改不属于当前模块的文件
- **Spec 语言**：`specs/` 下所有 spec.md 必须使用中文编写（场景描述、需求标题等），保持 当/则 结构标记不变
- 禁止修改 `.opencode/` 下的任何文件
- 配置文件使用 `.jsonc` 格式（支持 `//` 行注释）

---

## 代码生成规则

1. 生成代码前**必须检查**对应模块的 `specs/[模块]/spec.md` 是否存在
2. 生成代码必须放入对应 `src/[模块]/` 目录
3. 修改文件前自动备份旧版本到 `backups/[模块]/`
4. 每次 spec 更新 → 旧版归档至 `specs/[模块]/history/`
5. 新增/修改接口、数据模型前 → 先更新 spec.md
6. **禁止**不修改 spec.md 直接新增业务代码
7. 根目录 `specs/[模块]/spec.md` 必须使用项目模块规格格式，而不是 OpenSpec 的 `Requirement/Scenario` 主规格格式。文档依次包含：模块标题、版本信息、最后更新时间、模块名称、业务概述、核心业务流程、页面布局约束、接口说明和版本记录。
8. 模块规格标题使用 `# [模块名称] 模块规格说明`；开头元信息至少包含 `- 版本：`、`- 最后更新：` 和 `- 模块名称：`。
9. 业务需求使用中文 Markdown 编写，按业务概述、核心业务流程和页面布局约束组织；可验证行为使用 `-` 列表描述，接口说明必须包含接口路径、请求方式、请求参数和返回参数，并使用 JSON 示例说明数据结构。
10. 版本记录必须使用 Markdown 表格，至少包含 `日期`、`版本` 和 `变更说明` 三列；每次修改 spec.md 都必须追加版本记录，不得删除既有记录。
11. 模块规格必须使用中文编写；接口路径统一放在“接口说明”章节中，接口定义应同步生成或更新 `src/[模块]/README.http`，并添加便于阅读和调试的注释。
12. 每次变更代码需要同步生成或更新 `src/[模块]/build.json`，内容为在页脚显示的版本信息，格式为 `{"built": "yyyyMMddHHmm", "llmodel": "当前所使用的 LLM 模型名称"}`。
13. **BUILD_TIME 自动替换**：HTML 中标记 `// BUILD_TIME: YYYY/MM/DD HH:mm`，opencode 每次重新生成文件时，将该值替换为当前时间的 `YYYY/MM/DD HH:mm` 格式。禁止使用 `document.lastModified` 等运行时方式。
14. **视觉风格**：实现页面样式前，先加载 `design-taste-frontend` skill，参照其色彩校准（第 4.2 节）、排版规则（第 4.1 节）、布局多元化（第 4.3 节）等约束指导代码生成，避免 AI 默认样式。

---

## markdown书写规则

- 标题和列表间要有一个空行
- 段落：使用 `回车` 换行
- 标题：使用 `#` 符号，例如：`# 标题`
- 列表：使用 `-` 符号，例如：`- 列表项`

---

## 版本定义

- 格式：`yyyyMMddhhmm`（以日期为版本号）
- 每次生成目标文件后，在文件内更新该版本信息
- **禁止**使用文件修改时间作为版本号

---

## 代码风格

- 当前**尚无 ESLint/Prettier 配置**，生成代码时遵循 JavaScript ES6+ 常规规范
- 缩进：2 空格
- 命名：camelCase（变量/函数）、PascalCase（类）、kebab-case（文件名）
- 注释：中文注释，复杂逻辑必须注释

---

## 第三方依赖

- 未在 spec 中声明的第三方库**禁止使用**
- 只可安装 spec 中声明的 npm 包

---

## Copyright

如未额外定义，所有 copyright 均使用：

```txt
Inventec (Tianjin) Electronics Technology Co., Ltd. All Rights Reserved.
```
