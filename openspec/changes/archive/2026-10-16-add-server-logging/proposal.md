# Proposal

## Why

当前 `server-node` 主要使用 `console.log` 和 `console.error` 输出日志，缺少统一的结构化格式、请求级关联信息和明确的生产保留策略，导致排查历史请求、接口错误和慢请求困难。现在引入标准化日志能力，可以在不绑定具体日志平台的前提下，为本地开发、单机部署和后续集中式日志采集提供一致基础。

## What Changes

- 引入 `pino` 作为应用结构化日志库。
- 引入 `pino-http` 记录 HTTP 请求、响应状态和请求耗时，并提供请求级 logger。
- 引入 `pino-pretty` 仅用于开发环境的人类可读输出，生产环境输出 JSON 到标准输出。
- 统一服务启动、数据库迁移和 Express 错误处理中间件的日志记录方式，移除业务运行路径中的直接 `console.log`/`console.error`。
- 为日志增加服务名、运行环境、日志级别、时间、请求 ID 和错误堆栈等可检索字段。
- 明确禁止记录密码、JWT、Authorization 请求头、文件二进制内容和文字内容正文等敏感数据。
- 更新 Node 服务依赖、运行配置、测试和文档，说明通过终端、PM2、Docker 或日志采集器查看历史日志的方式。

## Capabilities

### New Capabilities

- `server-logging`: 为 Node 服务提供结构化应用日志、HTTP 请求日志、错误关联和敏感信息保护能力。

### Modified Capabilities

无。

## Impact

- 代码：`source/server-node/server.js`、Express 应用初始化、错误处理中间件和数据库迁移脚本。
- 依赖：`pino`、`pino-http`、`pino-pretty`。
- 配置：日志级别、运行环境和服务名称等环境变量或默认配置。
- 测试：需要验证请求日志、错误日志、日志级别过滤和敏感字段不出现在输出中。
- 部署：生产日志默认输出到 stdout，由 PM2、Docker、systemd/journald 或 Fluent Bit/Filebeat 等运行环境负责保存、轮转和转发；本变更不直接绑定 ELK。
