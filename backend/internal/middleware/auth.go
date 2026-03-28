package middleware

import (
	"context"
	"net/http"
	"strings"

	"vaultspend/internal/token"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type ctxKey string

const UserIDKey ctxKey = "user_id"

// BearerJWT validates Authorization: Bearer <JWT> and attaches user id to request context.
func BearerJWT(secret []byte) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if h == "" || !strings.HasPrefix(strings.ToLower(h), "bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing bearer token"})
			return
		}
		raw := strings.TrimSpace(h[7:])
		uid, err := token.ParseAccessToken(secret, raw)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}
		ctx := context.WithValue(c.Request.Context(), UserIDKey, uid)
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}

func UserID(ctx context.Context) (uuid.UUID, bool) {
	v := ctx.Value(UserIDKey)
	if v == nil {
		return uuid.Nil, false
	}
	id, ok := v.(uuid.UUID)
	return id, ok
}
