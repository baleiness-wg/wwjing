package controllers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

type FavoriteHandler struct {
	DB *pgxpool.Pool
}

func (h FavoriteHandler) List(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "鐧诲綍宸插け鏁?})
		return
	}
	folder := c.Query("folderId")
	rows, err := h.DB.Query(c.Request.Context(), `
		SELECT id, title, description, source_url, next_action, category, status, folder_id
		FROM favorite_details
		WHERE user_id = $1 AND ($2 = '' OR folder_id = $2::bigint)
		ORDER BY created_at DESC`, uid, folder)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "鏈嶅姟鍣ㄥ唴閮ㄩ敊璇?})
		return
	}
	defer rows.Close()

	result := make([]gin.H, 0)
	for rows.Next() {
		var id int64
		var title, description, sourceURL, nextAction, category, status string
		var folderID *int64
		if err := rows.Scan(&id, &title, &description, &sourceURL, &nextAction, &category, &status, &folderID); err != nil {
			continue
		}
		result = append(result, gin.H{
			"id":          id,
			"title":       title,
			"description": description,
			"sourceUrl":   sourceURL,
			"nextAction":  nextAction,
			"category":    category,
			"status":      status,
			"folderId":    folderID,
		})
	}
	c.JSON(http.StatusOK, gin.H{"favoriteDetails": result})
}

func (h FavoriteHandler) Create(c *gin.Context) {
	uid, ok := userID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "鐧诲綍宸插け鏁?})
		return
	}
	var input struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		SourceURL   string `json:"sourceUrl"`
		NextAction  string `json:"nextAction"`
		Category    string `json:"category"`
		FolderID    *int64 `json:"folderId"`
	}
	if c.ShouldBindJSON(&input) != nil || strings.TrimSpace(input.Title) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "鏍囬鎴栭摼鎺ヤ笉鑳戒负绌?})
		return
	}
	if input.Category == "" {
		input.Category = "text"
	}

	var id int64
	var status string
	err := h.DB.QueryRow(c.Request.Context(), `
		INSERT INTO favorite_details
		(user_id, title, description, source_url, next_action, category, folder_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, status`, uid, strings.TrimSpace(input.Title), input.Description,
		input.SourceURL, input.NextAction, input.Category, input.FolderID).Scan(&id, &status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "鏈嶅姟鍣ㄥ唴閮ㄩ敊璇?})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"favoriteDetail": gin.H{
		"id": id, "title": strings.TrimSpace(input.Title), "description": input.Description,
		"sourceUrl": input.SourceURL, "nextAction": input.NextAction, "category": input.Category,
		"status": status, "folderId": input.FolderID,
	}})
}
