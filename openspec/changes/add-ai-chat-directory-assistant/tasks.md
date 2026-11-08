# Tasks

## 1. Agnes 配置与服务端 AI 边界

- [x] 1.1 确认 Agnes 官方 API 的 Base URL、模型名称、认证头、请求/响应格式和超时能力，并在 `source/server-node/.env.example` 与服务端配置中增加 `AI_API_KEY`、`AI_BASE_URL`、`AI_MODEL`、`AI_TIMEOUT_MS`；用无 Key 启动检查确认既有服务仍可启动且不输出凭据。
- [x] 1.2 在 `source/server-node` 增加 Agnes 适配依赖或受控 HTTP 客户端，创建独立 AI service，完成配置校验、消息格式转换、超时取消、回复提取和供应商错误归一化；用 mock provider 单元测试覆盖成功、配置缺失、超时和无效响应。
- [x] 1.3 创建认证的 `/api/ai/chat` 路由与控制器，校验空间、目录上下文、消息和历史消息的类型、长度及数量，复用现有 JWT 中间件并返回稳定的成功/错误 JSON；用 Node API 测试验证 401、400、AI_NOT_CONFIGURED、AI_TIMEOUT 和正常回复。
- [x] 1.4 在 AI service 的 prompt/context 构造边界实施字段白名单、条目数量上限、单字段长度上限和总上下文上限，明确声明上下文仅代表当前已加载收藏；用敏感字段和超容量测试确认不会把 JWT、API Key、请求头、文件二进制或完整正文传给 mock provider。
- [x] 1.5 将 AI 请求的结构化日志接入现有 Pino logger，仅记录请求 ID、用户/目录元数据、消息长度、条目数、耗时和错误类别；用日志断言确认 API Key、Authorization、完整消息、prompt 和 AI 回复不出现在日志中。
- [x] 1.6 更新 `source/server-node/README.http` 与 README，记录 `/api/ai/chat` 的认证、请求/响应示例、错误码、环境变量和 Agnes 配置说明，并验证示例不包含真实 Key 且请求字段与路由实现一致。

## 2. Web API 与聊天交互

- [x] 2.1 新增 `source/web/src/api/ai.js`，封装认证 AI Chat 请求、目录上下文和错误处理；用前端 API 测试确认请求携带现有 Bearer token、不会读取或暴露 AI Key，并正确解析成功与失败响应。
- [x] 2.2 创建可复用的 `AiChatPanel.vue` 及必要样式，支持悬浮按钮、响应式面板、消息列表、输入框、发送中状态、失败重试和关闭；用组件测试或可执行的浏览器测试验证桌面/PAD 窄屏下按钮可见、面板可滚动且重复提交被阻止。
- [x] 2.3 在 `BookmarksView.vue` 将当前 `currentSpace`、`activeFolderId`、`activeTitle`、`folderPath`、已加载 `items` 和收藏数量转换为受限目录上下文并传递给聊天组件；用页面测试验证切换空间/目录后新会话使用新上下文，且当前目录无收藏时仍能打开并提示上下文为空。
- [x] 2.4 实现连续对话状态管理，按顺序追加用户消息和 AI 回复，失败时保留原始问题并允许重试，关闭/重新打开时按设计清空或重新初始化会话；用前端测试覆盖首问、连续追问、失败重试和目录切换。
- [x] 2.5 按现有 Element Plus 和页面视觉规则补充悬浮按钮、聊天面板、空状态、加载状态和错误提示的中文文案与无障碍标签；运行 Web 构建并验证不产生页面级横向滚动，既有收藏夹操作仍可用。

## 3. 集成验证与发布准备

- [x] 3.1 使用 mock Agnes 服务完成端到端验证：登录 Web、进入两个收藏空间和不同目录、打开 AI Chat、发送问题、连续追问、模拟超时/供应商错误，并确认上下文范围和错误提示符合规格。
- [x] 3.2 运行 `source/server-node` 的完整测试、`source/web` 的完整测试和生产构建，检查 AI 相关日志与构建产物不包含 API Key、`.env` 内容或真实测试凭据。
- [x] 3.3 更新对应模块的 `build.json` 与必要的版本记录，确认服务端 README.http、Web 文档和配置示例已同步，并记录实际使用的 LLM 模型名称和构建时间。

## Workflow follow-up

- 实现并验证所有任务后，复核任务状态和变更 diff。
- 确认 Agnes 真实配置已通过部署环境注入后，再使用 `/opsx-archive add-ai-chat-directory-assistant` 归档变更。
