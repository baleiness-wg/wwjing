# Design

## Context

当前 Web 使用 Vue 3、Vue Router 和 Element Plus，收藏页 `BookmarksView.vue` 已掌握当前空间、当前目录、目录路径、分页收藏条目和目录树。当前 Node 服务使用 CommonJS、Express 5、JWT 认证和 Pino 日志，收藏路由通过 `auth` 中间件保护。AI Key 属于外部 Agnes AI 平台，不能进入前端构建产物或浏览器请求。

本设计对应 `specs/ai-directory-chat/spec.md`。Agnes 的确切 Base URL、模型名称和是否完整兼容 OpenAI Chat Completions 需要在实现前通过其 API 文档或控制台确认；配置不确定时服务端必须启动但 AI 接口返回配置错误，而不能猜测并把 Key 发送到错误地址。

## Goals / Non-Goals

**Goals:**

- 在现有收藏页内提供可复用的悬浮聊天面板，不改变既有目录和收藏操作。
- 由 Node 服务端统一处理 Agnes AI 调用、认证、输入校验、超时、错误映射和日志脱敏。
- 使用当前页面已经加载的收藏元数据构造目录上下文，避免实现阶段新增网页抓取和 SSRF 风险。
- 让同一聊天面板支持连续对话、加载状态和失败重试，并覆盖窄屏/PAD 使用。
- 通过独立 AI service 隔离供应商协议，后续可替换为其他 OpenAI 兼容服务或原生 HTTP 适配器。

**Non-Goals:**

- 本变更不实现网页全文抓取、文件内容解析、向量数据库、RAG、Agent 工具调用或长期会话存储。
- 本变更不实现流式 SSE/WebSocket；第一版返回完整 AI 回复。
- 本变更不将对话历史写入 PostgreSQL；历史只存在当前页面会话内，刷新页面后清空。
- 本变更不在浏览器直连 Agnes，也不把 API Key 放进 Web 环境变量或前端 bundle。

## Decisions

### 服务端代理而不是浏览器直连

新增认证的 `/api/ai/chat` 路由，复用现有 JWT 中间件。前端只发送上下文和消息到自己的 Node 服务；Node 服务读取 `AI_API_KEY`、`AI_BASE_URL` 和 `AI_MODEL`，调用 Agnes 后只返回规范化的回复。这样可以保护 Key，并集中控制超时、限流、审计和供应商错误。

备选方案是前端直接调用 Agnes，优点是服务端改动少，但会暴露 Key、绕过现有用户认证并难以控制第三方调用，因此不采用。

### 独立的 AI service 与供应商适配

将供应商调用放在 `src/services/ai.service.js`，控制器只负责 HTTP 输入输出。优先采用 OpenAI-compatible Chat Completions 客户端或原生 `fetch` 封装；具体 SDK 选择以 Agnes 文档确认结果为准。若接口兼容，使用 `baseURL` 配置切换；若不兼容，只在 service 内实现 Agnes 请求格式，不改变前端 API。

### 当前页面数据作为上下文源

`BookmarksView.vue` 已有 `activeFolderId`、`activeTitle`、`folderPath`、`items` 和 `currentSpace`。打开或发送消息时构造纯 JSON 的 `directoryContext`：空间、目录 ID/名称/路径、当前已加载条目及必要字段。服务端再次限制字段长度、条目数和总字符数。对于分页未加载的条目，界面显示“当前上下文仅包含已加载收藏”，不隐式请求全部数据；后续若需要完整目录分析，再单独设计服务端聚合接口。

备选方案是服务端接收目录 ID 后自行查询全量收藏，数据一致性更强但会扩大接口职责、上下文费用和隐私范围；第一版不采用。

### 统一错误结构和请求超时

控制器将输入错误、未配置、超时、供应商失败和解析失败分别映射为稳定错误码，例如 `AI_INVALID_INPUT`、`AI_NOT_CONFIGURED`、`AI_TIMEOUT` 和 `AI_PROVIDER_ERROR`。AI service 使用 AbortController 或 SDK timeout；客户端的 `request` 错误解析可直接展示 message，并在失败时保留输入文本。

### 前端使用页面级可复用组件

在 Web 端新增 `AiChatPanel.vue` 和 `api/ai.js`，由收藏页传入当前上下文并控制打开状态。悬浮按钮和面板归属于收藏页而不是全局 AppLayout，因为只有收藏页能准确提供当前目录上下文；这样不会在首页或数据传输页展示一个没有分析对象的 AI 按钮。

### 日志与安全边界

只记录请求 ID、用户 ID、空间、目录 ID、消息长度、上下文条目数、耗时和错误分类。Pino 的已有序列化/脱敏机制之外，AI service 不把完整 prompt、回复、Authorization、配置对象或供应商原始响应写入日志。请求正文不在 HTTP 访问日志中输出。

## Risks / Trade-offs

- [Agnes 接口协议不确定] → 实现前用平台文档确认 Base URL、模型名、认证头和响应字段；把协议差异隔离在 service，加入 mocked provider 测试。
- [目录内容可能包含用户隐私] → 只发送当前已加载的必要元数据，限制长度并明确 UI 提示；不发送凭据、文件二进制和网页全文。
- [模型调用产生费用或被滥用] → 限制消息/上下文长度，服务端保留用户认证边界和可插入限流的位置；后续可增加按用户限流和额度统计。
- [第三方服务延迟影响体验] → 使用明确超时、加载状态和可重试错误；不阻塞目录列表的加载和编辑操作。
- [上下文不完整导致 AI 误判] → 在系统提示和界面中声明上下文仅代表当前已加载条目，并把目录路径和条目数量作为上下文元数据。
- [小屏面板遮挡页面] → 使用响应式面板，桌面采用右下浮层，窄屏采用接近全宽的底部/侧边面板，并保留关闭和滚动区域。

## Migration Plan

1. 在 `server-node` 配置 Agnes 所需的服务端环境变量，先使用测试 Key 或 mock provider 验证服务启动和接口错误路径。
2. 部署后端路由与前端构建，未配置 AI 变量时既有登录、收藏和目录功能仍正常，只有 AI 操作返回不可用提示。
3. 通过已登录用户在“鲸界”和“疯狂的厨房”目录分别验证上下文、连续追问、超时和敏感信息日志。
4. 回滚时移除或禁用 AI 路由及前端入口；不涉及数据库迁移，既有收藏数据不受影响。

## Open Questions

- Agnes 是否完整兼容 OpenAI Chat Completions，以及平台要求的实际 Base URL 和模型名称，需要实现前以官方 API 文档确认；这只影响 service 内部适配，不改变本规格的外部接口。
