package controllers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FolderHandler 负责处理收藏夹相关请求。
type FolderHandler struct {
	DB *pgxpool.Pool
}

// userID 从 Gin 上下文中读取当前登录用户的 ID。
func userID(c *gin.Context) (string, bool) {
	value, exists := c.Get("userID")
	if !exists {
		return "", false
	}

	id, isString := value.(string)
	if !isString {
		return "", false
	}

	return id, true
}

// List 返回当前用户创建的所有收藏夹。
func (h FolderHandler) List(c *gin.Context) {
	currentUserID, exists := userID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"message": "unauthorized",
		})
		return
	}

	// 查询收藏夹，并统计每个收藏夹中的内容数量。
	rows, err := h.DB.Query(
		c.Request.Context(),
		`SELECT f.id, f.name, COUNT(d.id)::int
		 FROM folders f
		 LEFT JOIN favorite_details d ON d.folder_id = f.id
		 WHERE f.user_id = $1
		 GROUP BY f.id
		 ORDER BY f.created_at`,
		currentUserID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "internal server error",
		})
		return
	}
	defer rows.Close()

	folders := make([]gin.H, 0)
	for rows.Next() {
		var folderID int64
		var folderName string
		var itemCount int

		scanError := rows.Scan(&folderID, &folderName, &itemCount)
		if scanError != nil {
			continue
		}

		folders = append(folders, gin.H{
			"id":        folderID,
			"name":      folderName,
			"itemCount": itemCount,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"folders": folders,
	})
}

// Create 创建一个新的收藏夹。
func (h FolderHandler) Create(c *gin.Context) {
	currentUserID, exists := userID(c)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"message": "unauthorized",
		})
		return
	}

	// 定义接收请求 JSON 的结构体。
	var input struct {
		Name string `json:"name"`
	}

	bindError := c.ShouldBindJSON(&input)
	folderName := strings.TrimSpace(input.Name)
	if bindError != nil || folderName == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "folder name is required",
		})
		return
	}

	// 插入数据库，并获得新收藏夹的 ID。
	var folderID int64
	err := h.DB.QueryRow(
		c.Request.Context(),
		`INSERT INTO folders (user_id, name)
		 VALUES ($1, $2)
		 RETURNING id`,
		currentUserID,
		folderName,
	).Scan(&folderID)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{
			"message": "folder already exists",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"folder": gin.H{
			"id":        folderID,
			"name":      folderName,
			"itemCount": 0,
		},
	})
}
