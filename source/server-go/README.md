# WWJing Go Server

Gin-based API server using PostgreSQL through `pgxpool`.

## Structure

```text
main.go                application entrypoint
config/                environment configuration
database/              PostgreSQL connection pool
controllers/           HTTP handlers
middlewares/           authentication middleware
routes/                Gin router
```

## Local Development

```powershell
Copy-Item .env.example .env
go mod tidy
go run .
```

For the current server database, set `DATABASE_URL` in `.env` to:

```env
DATABASE_URL=postgres://wwjing_user:111111@123.57.160.236:5432/wwjing?sslmode=disable
```

The Go server listens on port `3000` by default. The legacy Node server should use another port when both are run together.

## API

```text
GET  /api/health
POST /api/auth/register
POST /api/auth/login
GET  /api/folders
POST /api/folders
GET  /api/favorite-details
POST /api/favorite-details
```

The authenticated endpoints use the same `Authorization: Bearer <token>` format as the Node server.
