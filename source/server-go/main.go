package main

import (
	"context"
	"log"

	"github.com/wwjing/server-go/config"
	"github.com/wwjing/server-go/database"
	"github.com/wwjing/server-go/routes"
)

func main() {
	cfg := config.Load()
	ctx := context.Background()

	db, err := database.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if err := db.Ping(ctx); err != nil {
		log.Fatal(err)
	}

	r := routes.NewRouter(db, cfg)
	log.Printf("WWJ Go server is running at http://%s:%s", cfg.Host, cfg.Port)
	if err := r.Run(cfg.Host + ":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}
