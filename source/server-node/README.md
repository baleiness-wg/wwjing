# WWJ Node Server

## Commands

```powershell
npm install
npm run db:migrate
npm test
npm start
```

The authenticated transfer endpoints are documented in `README.http`.
They store one current text or file payload per user and replace it on the next save.

## Logging

The server uses `pino` for structured application logs and `pino-http` for HTTP request logs.

```text
NODE_ENV=development  # readable terminal output through pino-pretty
NODE_ENV=production   # JSON output to stdout
LOG_LEVEL=debug       # development default
LOG_LEVEL=info        # recommended production level
SERVICE_NAME=wwjing-server
```

Application logs do not write files or call Elasticsearch directly. The process manager or deployment platform owns retention and rotation:

- Development: run `npm run dev` and read formatted logs in the terminal.
- PM2: use `pm2 logs wwjing-server`; configure `pm2-logrotate` for historical logs.
- Docker: use `docker logs -f <container>` and configure the Docker logging driver rotation.
- systemd: use `journalctl -u wwjing-server --since "7 days ago"` to inspect older logs.
- Centralized logging: forward JSON stdout with Filebeat, Fluent Bit, or an equivalent collector.

## AI Chat

The authenticated `POST /api/ai/chat` endpoint sends the current Web bookmark context to an Agnes AI endpoint configured on the server. The browser never receives `AI_API_KEY`.

```text
AI_API_KEY=replace-with-agnes-api-key
AI_BASE_URL=https://apihub.agnes-ai.com/v1
AI_MODEL=agnes-2.5-flash
AI_TIMEOUT_MS=30000
```

The adapter calls the OpenAI-compatible `POST {AI_BASE_URL}/chat/completions` endpoint with `Authorization: Bearer <AI_API_KEY>`. The service limits message/history/context size and returns `AI_NOT_CONFIGURED`, `AI_INVALID_INPUT`, `AI_TIMEOUT`, or `AI_PROVIDER_ERROR` without exposing provider credentials.

Request logs include a request ID, method, path, status code, and response time. Passwords, tokens, Authorization headers, request bodies, file bytes, and saved text content are not logged.
