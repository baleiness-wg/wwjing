package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Host         string
	Port         string
	DatabaseURL  string
	JWTSecretKey string
}

func Load() Config {
	_ = godotenv.Load()
	return Config{
		Host:         env("HOST", "0.0.0.0"),
		Port:         env("PORT", "3000"),
		DatabaseURL:  env("DATABASE_URL", "postgres://postgres:123456@127.0.0.1:5432/postgres?sslmode=disable"),
		JWTSecretKey: env("JWT_SECRET_KEY", "wwjing-development-secret"),
	}
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
