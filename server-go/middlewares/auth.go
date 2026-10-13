package middlewares

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// Auth 验证请求中的 JWT，并将用户 ID 放入 Gin 上下文。
func Auth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 前端需要通过 Authorization 请求头发送令牌：
		// Authorization: Bearer <token>
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"message": "invalid or missing Bearer token",
			})
			return
		}

		tokenString := strings.TrimPrefix(header, "Bearer ")
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
			// 只允许 HMAC 类型的签名算法，防止使用其他算法绕过验证。
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrTokenSignatureInvalid
			}

			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"message": "invalid or missing Bearer token",
			})
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"message": "invalid or missing Bearer token",
			})
			return
		}

		// sub 是 JWT 标准字段，这里保存的是用户 ID。
		c.Set("userID", claims["sub"])
		c.Next()
	}
}
