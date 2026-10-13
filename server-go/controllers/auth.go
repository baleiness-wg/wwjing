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

// AuthHandler 负责处理注册和登录请求。
type AuthHandler struct {
	DB     *pgxpool.Pool // PostgreSQL 连接池。
	Secret string        // 用于签名 JWT 的密钥。
}

// Credentials 表示注册和登录时接收的 JSON 数据。
type Credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// Register 处理用户注册请求。
func (h AuthHandler) Register(c *gin.Context) {
	var input Credentials

	// 将请求体中的 JSON 解析到 input 变量中。
	bindError := c.ShouldBindJSON(&input)
	username := strings.TrimSpace(input.Username)
	if bindError != nil || username == "" || input.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "username and password are required",
		})
		return
	}

	// 密码不能直接保存到数据库，必须先进行哈希处理。
	passwordHash, err := bcrypt.GenerateFromPassword(
		[]byte(input.Password),
		bcrypt.DefaultCost,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "internal server error",
		})
		return
	}

	// 插入用户记录，并返回数据库自动生成的用户 ID。
	var userID int64
	err = h.DB.QueryRow(
		c.Request.Context(),
		`INSERT INTO users (username, password_hash)
		 VALUES ($1, $2)
		 RETURNING id`,
		username,
		string(passwordHash),
	).Scan(&userID)
	if err != nil {
		// 常见原因是用户名已经存在。
		c.JSON(http.StatusConflict, gin.H{
			"message": "username already exists",
		})
		return
	}

	// 注册成功后返回用户基本信息，不返回密码。
	c.JSON(http.StatusCreated, gin.H{
		"user": gin.H{
			"id":       userID,
			"username": username,
		},
	})
}

// Login 处理用户登录请求，并签发 JWT 令牌。
func (h AuthHandler) Login(c *gin.Context) {
	var input Credentials

	// 解析请求中的用户名和密码。
	bindError := c.ShouldBindJSON(&input)
	usernameInput := strings.TrimSpace(input.Username)
	if bindError != nil || usernameInput == "" || input.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "username and password are required",
		})
		return
	}

	// 根据用户名查询用户记录。
	var userID int64
	var username string
	var passwordHash string
	err := h.DB.QueryRow(
		c.Request.Context(),
		`SELECT id, username, password_hash
		 FROM users
		 WHERE username = $1`,
		usernameInput,
	).Scan(&userID, &username, &passwordHash)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"message": "invalid username or password",
		})
		return
	}

	// 将用户输入的密码与数据库中的哈希值进行比较。
	compareError := bcrypt.CompareHashAndPassword(
		[]byte(passwordHash),
		[]byte(input.Password),
	)
	if compareError != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"message": "invalid username or password",
		})
		return
	}

	// JWT 中保存用户 ID、用户名和过期时间。
	claims := jwt.MapClaims{
		"sub":      strconv.FormatInt(userID, 10),
		"username": username,
		"exp":      time.Now().Add(7 * 24 * time.Hour).Unix(),
	}
	token, err := jwt.NewWithClaims(
		jwt.SigningMethodHS256,
		claims,
	).SignedString([]byte(h.Secret))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"message": "internal server error",
		})
		return
	}

	// 登录成功，返回用户信息和 Bearer 格式的令牌。
	c.JSON(http.StatusOK, gin.H{
		"user": gin.H{
			"id":       userID,
			"username": username,
		},
		"token": "Bearer " + token,
	})
}
