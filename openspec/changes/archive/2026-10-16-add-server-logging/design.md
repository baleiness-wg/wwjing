# Design

## Context

当前 `source/server-node` 使用 CommonJS、Express 5 和 Node 原生启动脚本，应用日志主要分散在 `server.js`、数据库迁移脚本和错误处理中间件中的 `console.log`/`console.error`。服务已有统一的 Express 应用入口、JWT 认证中间件和集中错误处理中间件，适合在应用入口接入请求日志，并在边界位置统一使用应用 logger。具体行为约束见 `specs/server-logging/spec.md`。

## Goals / Non-Goals

**Goals:**

- 建立一个独立的 CommonJS logger 模块，统一应用日志配置和字段。
- 使用 `pino-http` 在 Express 入口记录请求完成状态、耗时和请求 ID，并将请求级 logger 暴露给控制器和中间件。
- 开发环境使用 `pino-pretty` 输出易读文本，生产环境保持 JSON 标准输出。
- 将启动、迁移和错误处理日志迁移到统一 logger，同时保持既有 HTTP 错误响应和进程退出行为。
- 通过序列化器、字段选择和显式日志调用避免密码、Authorization、JWT、文件正文和文字正文进入日志。
- 让 PM2、Docker、systemd/journald 或后续日志采集器能够直接接收 stdout，而不在应用中实现远程 Elastic/Kibana 客户端。

**Non-Goals:**

- 不在本变更中部署或配置 Elasticsearch、Kibana、Loki、Filebeat、Fluent Bit、PM2 或 systemd。
- 不实现应用自管理的日志文件、日志压缩和日志轮转。
- 不引入完整的分布式链路追踪、指标采集或 OpenTelemetry SDK。
- 不改变现有 API 路由、认证规则、错误响应格式或业务数据存储逻辑。

## Decisions

### 使用 Pino 作为核心 logger

使用 `pino` 生成结构化日志，默认字段包含 ISO 时间、日志级别、服务名称、运行环境和消息。服务名称和日志级别通过配置读取，并提供合理默认值。

选择 Pino 而不是 Winston 的原因是当前服务是新建的 Express API，生产输出目标是 stdout 和结构化日志采集。Winston 的多 transport 和应用内文件日志能力更强，但会引入不必要的输出管理；Pino 更适合先由运行平台负责保存和轮转。

### 使用 pino-http 作为 HTTP 日志边界

在 `app.js` 的 CORS、JSON body parser 和业务路由之间接入 `pino-http`，使所有 API 请求共享请求 ID和请求级 `req.log`。使用请求和响应序列化器限制输出字段，不记录请求头、请求体和响应体，避免认证凭据和用户内容泄露。

错误处理中间件继续保留现有响应分支，但改为使用 `req.log.error`（无请求上下文时使用应用 logger）记录 `err` 和必要的请求信息。请求完成日志由 `pino-http` 统一输出，避免同一请求产生重复的手工访问日志。

### 开发环境和生产环境使用不同输出格式

通过 `NODE_ENV` 和 `LOG_LEVEL` 控制运行行为：开发环境可加载 `pino-pretty` 输出可读文本，生产环境不加载 pretty transport，直接输出 JSON 到 stdout。应用不直接写日志文件，也不直接请求 Elasticsearch；日志保存、轮转和转发由部署环境负责。

### 采用结构化字段而不是拼接字符串

业务日志使用 `logger.info({ field: value }, "message")` 形式。允许记录用户 ID、请求 ID、文件名、MIME 类型、文件大小和结果状态等必要元数据，但禁止把密码、token、Authorization、文件 Buffer、文字正文放入字段或消息。对错误使用 `{ err }` 以保留类型、消息和堆栈。

### 数据库迁移脚本使用独立 logger

`src/db/migrate.js` 作为独立命令运行，复用 logger 配置记录迁移成功和失败。迁移失败仍设置 `process.exitCode = 1`，连接池清理和事务回滚行为保持不变。迁移文件名可以作为结构化字段，不将 SQL 内容写入日志。

## Risks / Trade-offs

- [Risk] 生产环境不再由应用直接写本地日志文件，单机部署若未配置 stdout 持久化可能无法查询历史日志。 -> [Mitigation] 在 README 中明确 PM2、Docker、systemd/journald 的保存和查询方式，并将 stdout 持久化作为部署配置责任。
- [Risk] `pino-pretty` 配置错误可能导致开发环境启动失败。 -> [Mitigation] 将其作为开发依赖或明确的开发 transport，并增加 logger 初始化测试覆盖开发和生产两种模式。
- [Risk] 自动 HTTP 日志可能记录请求 URL 中的敏感查询参数。 -> [Mitigation] 使用 URL 序列化策略清理或避免记录 query 中的敏感字段；认证信息只允许通过 Authorization header 传递且不序列化请求头。
- [Risk] 错误对象序列化可能包含第三方错误对象的额外字段。 -> [Mitigation] 只使用 Pino 的错误序列化能力记录 `err`，不记录整个 request、body、response 或数据库连接配置。
- [Risk] 请求日志和错误日志可能对同一失败请求产生两条记录。 -> [Mitigation] 请求完成信息只由 `pino-http` 输出，错误处理中间件只输出诊断错误日志；通过测试确认两类日志职责不同。

## Migration Plan

1. 在 Node 服务中加入日志依赖和统一 logger 模块，先保留现有启动、错误和迁移行为作为对照。
2. 在 Express 入口接入请求日志，再迁移服务启动、错误处理中间件和迁移脚本中的直接控制台输出。
3. 增加日志字段、级别过滤、敏感信息保护和 HTTP 状态记录测试，并运行现有测试套件。
4. 更新服务 README 和环境变量示例，说明开发终端查看、生产 stdout、PM2/Docker/systemd 保存历史日志的职责边界。
5. 回滚时移除 logger 中间件和依赖，恢复原有控制台输出；不涉及数据库结构和 API 迁移。

## Open Questions

无。日志平台和进程管理器可以在部署阶段独立选择，不影响本变更的应用侧日志契约。
