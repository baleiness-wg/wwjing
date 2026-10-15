# Design

## Context

当前 `source/server-node` 是 CommonJS Express 服务，日志主要来自 `server.js`、统一错误处理中间件和数据库迁移脚本中的 `console.log`/`console.error`。服务已有认证、文件上传和 PostgreSQL 访问能力，因此日志设计必须支持请求关联、异常堆栈和敏感信息控制，同时不能把密码、令牌或文件内容写入日志。

## Goals / Non-Goals

**Goals:**

- 使用 `pino` 生成结构化应用日志。
- 使用 `pino-http` 统一记录 HTTP 请求、响应状态和处理耗时。
- 开发环境提供可读的终端输出，生产环境保持机器可解析的 JSON 输出。
- 通过请求级 logger 让控制器、服务和错误处理中间件共享请求关联标识。
- 让日志输出兼容 systemd/journald、PM2、Docker 及未来的 Filebeat/Fluent Bit 采集。
- 通过配置控制日志级别、服务名称和运行环境，并建立字段脱敏边界。

**Non-Goals:**

- 本次不部署 Elasticsearch、Kibana、Loki、Filebeat 或 Fluent Bit。
- 本次不让 Node 进程直接向 Elasticsearch 或 Kafka 发送日志。
- 本次不建立业务审计日志数据库，也不记录完整请求体、响应体或文件内容。
- 本次不替换现有业务错误响应格式，不改变接口状态码和认证行为。

## Decisions

### 使用 Pino 作为应用日志实现

选择 `pino` 而不是 `winston` 或直接复用 MDK 的 `@mdk/helpers.log2`。Pino 原生输出结构化 JSON，适合 API 服务和 stdout 采集；Winston 的多 transport 能力更偏传统应用文件日志；MDK logger 与 MDK 运行时注入机制耦合，不适合作为独立 Express 服务的基础依赖。

### 使用 pino-http 统一处理 HTTP 请求日志

在 Express 路由之前注册 HTTP 日志中间件，使成功和失败请求都能记录方法、路径、状态码、耗时和请求关联标识。业务处理代码使用请求级 `req.log`，避免自行生成第二套请求日志格式。

### 开发环境与生产环境使用不同展示方式

开发环境通过 `pino-pretty` 格式化输出，便于直接阅读；生产环境不做 pretty 格式化，直接输出 JSON 到 stdout/stderr。这样日志内容保持结构化，部署环境可以负责持久化、轮转和转发。

### 应用只负责生成日志，部署环境负责保存历史日志

服务不直接管理日志文件、压缩和保留周期。单机部署可使用 systemd/journald 或 PM2 保存 stdout；容器部署使用 Docker 日志机制；未来需要集中查询时再由 Filebeat/Fluent Bit 采集。这样日志平台不可用时不会把远程网络请求耦合进业务请求路径。

### 统一错误处理中记录错误对象

错误处理中间件使用结构化错误字段记录错误名称、消息、堆栈、请求关联标识和请求基本信息，然后维持现有客户端响应。已知认证、参数和文件大小错误使用适当日志级别，避免把所有预期客户端错误都当成服务崩溃。

### 敏感字段采用显式白名单

日志字段只记录诊断所需的元数据，例如用户 ID、路由、文件名、媒体类型和文件大小；密码、Authorization、JWT、数据库凭据、完整文字内容和文件二进制不进入日志。请求体和响应体默认不记录，避免遗漏新增敏感字段。

## Risks / Trade-offs

- [Risk] JSON 日志比纯文本占用更多空间。 -> [Mitigation] 生产环境使用 `info` 默认级别，`debug` 仅按配置开启，并由 systemd、PM2 或容器日志策略限制保留量。
- [Risk] 请求日志可能泄露 URL 查询参数中的敏感信息。 -> [Mitigation] 记录规范化路径或对 URL 中的认证参数进行脱敏，不直接记录完整请求头和请求体。
- [Risk] stdout 日志依赖部署环境的持久化配置。 -> [Mitigation] 在部署文档和运行配置中明确 systemd/journald、PM2 或 Docker 的保留周期和历史查询命令。
- [Risk] 直接替换 console 调用可能遗漏启动或迁移异常。 -> [Mitigation] 将日志接入点列为独立任务，并通过启动、迁移、请求和异常测试验证输出。
- [Risk] 日志等级和字段在后续服务扩展中不一致。 -> [Mitigation] 提供统一 logger 模块和字段约定，业务模块不自行创建 logger 实例。

## Migration Plan

1. 增加 Pino 相关依赖和统一 logger 配置，默认从环境变量读取运行环境、服务名和日志级别。
2. 在 Express 应用入口接入 HTTP 请求日志，并保留现有中间件顺序和错误响应行为。
3. 将服务启动、数据库迁移和统一错误处理迁移到结构化 logger，检查其余运行时 `console` 调用。
4. 增加日志字段、请求关联、异常堆栈和敏感数据不泄漏的测试。
5. 在服务 README 中说明开发环境查看方式，以及单机部署使用 systemd/journald 或 PM2 查询历史日志的方式。
6. 回滚时移除日志中间件和 logger 引用，恢复原有控制台输出；Pino 依赖和配置可随代码版本回退，不涉及数据库迁移。

## Open Questions

无。集中式日志平台和具体生产进程管理器可以在部署阶段单独决定，不改变本次日志 API、字段和 stdout 输出设计。
