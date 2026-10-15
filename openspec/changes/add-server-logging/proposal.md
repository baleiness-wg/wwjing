# Proposal

## Why

当前 `source/server-node` 仅使用 `console.log` 和 `console.error` 输出日志，缺少统一的日志级别、请求关联信息、结构化字段和可持续查询方案。现在引入标准化日志能力，可以让开发环境直接查看请求和错误，让单机生产环境通过进程管理器或系统日志保留历史记录，并为后续接入集中式日志平台保留兼容性。

## What Changes

- 引入 `pino` 作为应用日志包，统一记录 `trace`、`debug`、`info`、`warn`、`error` 和 `fatal` 级别日志。
- 引入 `pino-http` 记录 HTTP 请求方法、路径、状态码、响应耗时和请求关联标识。
- 开发环境支持使用 `pino-pretty` 输出便于阅读的日志；生产环境输出结构化 JSON 到 stdout/stderr。
- 将服务启动、数据库迁移、统一错误处理和 HTTP 请求日志纳入统一日志接口，逐步替换直接调用 `console.log`/`console.error` 的服务运行日志。
- 规定日志字段和敏感信息脱敏边界，不记录密码、JWT、Authorization 请求头、完整文字内容和文件二进制内容。
- 明确历史日志由部署环境负责持久化：单机部署可使用 systemd/journald 或 PM2 日志轮转，容器部署使用 stdout 日志采集；日志包本身不直接负责对接 Elasticsearch。

## Capabilities

### New Capabilities

- `server-logging`: 为 Node 服务提供结构化应用日志、HTTP 请求日志、错误关联和可查询的历史日志输出能力。

### Modified Capabilities

无。

## Impact

- 服务代码：`source/server-node/server.js`、`src/app.js`、错误处理中间件、数据库迁移脚本及其他运行时日志调用点。
- 依赖配置：`source/server-node/package.json` 和锁文件新增 `pino`、`pino-http`，开发环境新增 `pino-pretty`。
- 运行配置：增加日志级别、服务名和运行环境等可配置项，并约定 stdout/stderr 输出方式。
- 测试：增加日志字段、请求日志、错误日志和敏感信息不泄漏的验证。
- 运维：补充单机历史日志查看和保留方式；不在本次变更中部署 ELK、Loki 或其他集中式日志平台。
