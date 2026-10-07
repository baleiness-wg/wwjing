package routes

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/wwjing/server-go/config"
	"github.com/wwjing/server-go/controllers"
	"github.com/wwjing/server-go/middlewares"
)

func NewRouter(db *pgxpool.Pool, cfg config.Config) *gin.Engine {
	r := gin.Default()
	r.Use(cors.New(cors.Config{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders: []string{"Origin", "Content-Type", "Authorization"},
	}))

	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "wwjing-server-go"})
	})

	auth := controllers.AuthHandler{DB: db, Secret: cfg.JWTSecretKey}
	folders := controllers.FolderHandler{DB: db}
	favorites := controllers.FavoriteHandler{DB: db}
	r.POST("/api/auth/register", auth.Register)
	r.POST("/api/auth/login", auth.Login)
	protected := r.Group("/api", middlewares.Auth(cfg.JWTSecretKey))
	protected.GET("/folders", folders.List)
	protected.POST("/folders", folders.Create)
	protected.GET("/favorite-details", favorites.List)
	protected.POST("/favorite-details", favorites.Create)

	return r
}
