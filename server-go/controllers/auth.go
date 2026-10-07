package controllers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type AuthHandler struct { DB *pgxpool.Pool; Secret string }
type credentials struct { Username string `json:"username"`; Password string `json:"password"` }

func (h AuthHandler) Register(c *gin.Context) {
	var input credentials
	if c.ShouldBindJSON(&input) != nil || strings.TrimSpace(input.Username) == "" || input.Password == "" { c.JSON(400, gin.H{"message":"鐢ㄦ埛鍚嶅拰瀵嗙爜涓嶈兘涓虹┖"}); return }
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost); if err != nil { c.JSON(500, gin.H{"message":"鏈嶅姟鍣ㄥ唴閮ㄩ敊璇?}); return }
	var id int64
	err = h.DB.QueryRow(c.Request.Context(), `INSERT INTO users (username,password_hash) VALUES ($1,$2) RETURNING id`, strings.TrimSpace(input.Username), string(hash)).Scan(&id)
	if err != nil { c.JSON(409, gin.H{"message":"鐢ㄦ埛鍚嶅凡瀛樺湪"}); return }
	c.JSON(http.StatusCreated, gin.H{"user": gin.H{"id":id,"username":strings.TrimSpace(input.Username)}})
}

func (h AuthHandler) Login(c *gin.Context) {
	var input credentials
	if c.ShouldBindJSON(&input) != nil || input.Username == "" || input.Password == "" { c.JSON(400, gin.H{"message":"鐢ㄦ埛鍚嶅拰瀵嗙爜涓嶈兘涓虹┖"}); return }
	var id int64; var username, hash string
	err := h.DB.QueryRow(c.Request.Context(), `SELECT id,username,password_hash FROM users WHERE username=$1`, input.Username).Scan(&id,&username,&hash)
	if err != nil || bcrypt.CompareHashAndPassword([]byte(hash), []byte(input.Password)) != nil { c.JSON(401, gin.H{"message":"鐢ㄦ埛鍚嶆垨瀵嗙爜閿欒"}); return }
	token, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"sub":strconv.FormatInt(id,10),"username":username,"exp":time.Now().Add(7*24*time.Hour).Unix()}).SignedString([]byte(h.Secret)); if err != nil { c.JSON(500,gin.H{"message":"鏈嶅姟鍣ㄥ唴閮ㄩ敊璇?}); return }
	c.JSON(200, gin.H{"user":gin.H{"id":id,"username":username},"token":"Bearer "+token})
}
