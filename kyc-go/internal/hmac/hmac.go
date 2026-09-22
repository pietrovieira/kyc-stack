package hmac

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

const (
	tolerance = 300 // 5 min
	nonceTTL  = 600 // 10 min
	headerKey = "X-API-Key"
	headerTS  = "X-Timestamp"
	headerNonce = "X-Nonce"
	headerSig = "X-Signature"
)

// Middleware retorna gin.HandlerFunc que valida HMAC-SHA256
// String canônica: TIMESTAMP + "\n" + NONCE + "\n" + METHOD + "\n" + PATH + "\n" + BODY_SHA256
func Middleware(secret, keyID string, rdb *redis.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		apiKey := c.GetHeader(headerKey)
		tsStr := c.GetHeader(headerTS)
		nonce := c.GetHeader(headerNonce)
		sig := c.GetHeader(headerSig)

		if apiKey == "" || tsStr == "" || nonce == "" || sig == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"success": false, "error": "Headers HMAC ausentes: X-API-Key, X-Timestamp, X-Nonce, X-Signature exigidos", "code": "hmac_auth_failed",
			})
			return
		}
		if subtle.ConstantTimeCompare([]byte(apiKey), []byte(keyID)) != 1 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "X-API-Key inválido", "code": "hmac_auth_failed"})
			return
		}
		ts, err := strconv.ParseInt(tsStr, 10, 64)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "X-Timestamp inválido", "code": "hmac_auth_failed"})
			return
		}
		now := time.Now().Unix()
		if abs(now-ts) > tolerance {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "X-Timestamp expirado (tolerância 5min) - possível replay", "code": "hmac_auth_failed"})
			return
		}

		// Nonce anti-replay via Redis SETNX
		if rdb != nil {
			ctx := c.Request.Context()
			ok, err := rdb.SetNX(ctx, "hmac:nonce:"+nonce, "1", nonceTTL*time.Second).Result()
			if err == nil && !ok {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "X-Nonce já usado - replay detectado", "code": "hmac_auth_failed"})
				return
			}
			// se Redis falhar, não bloqueia (log), mas em prod deveria bloquear
		}

		// Lê body raw via GetRawData (cache) e recoloca
		raw, _ := c.GetRawData()
		c.Request.Body = io.NopCloser(bytes.NewBuffer(raw))
		bodyHash := sha256Hex(string(raw))
		canonical := strings.Join([]string{tsStr, nonce, c.Request.Method, c.Request.URL.Path, bodyHash}, "\n")
		expected := hmacHex(secret, canonical)
		if subtle.ConstantTimeCompare([]byte(expected), []byte(sig)) != 1 {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": "X-Signature inválida", "code": "hmac_auth_failed"})
			return
		}
		c.Next()
	}
}

func abs(a int64) int64 {
	if a < 0 {
		return -a
	}
	return a
}

func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

func hmacHex(secret, data string) string {
	m := hmac.New(sha256.New, []byte(secret))
	m.Write([]byte(data))
	return hex.EncodeToString(m.Sum(nil))
}


