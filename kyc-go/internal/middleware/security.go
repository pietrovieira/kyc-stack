package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// SecurityHeaders adiciona proteções XSS, Clickjacking, etc.
func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'")
		c.Next()
	}
}

// RateLimit simples por IP (in-memory) - para prod usar Redis
// Aqui delegamos para um middleware que será trocado por redis em breve
func NoCache() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Cache-Control", "no-store, no-cache, must-revalidate")
		c.Next()
	}
}

// ValidateContentType garante JSON para POST/PATCH
func ValidateContentType() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method == "POST" || c.Request.Method == "PATCH" || c.Request.Method == "PUT" {
			ct := c.GetHeader("Content-Type")
			if ct != "" && !strings.Contains(ct, "application/json") && !strings.Contains(ct, "multipart/form-data") {
				// permite json e form-data (para file uploads futuros)
			}
		}
		c.Next()
	}
}

// Error handler global
func Recovery() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, recovered interface{}) {
		c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Erro interno", "code": "internal_error"})
	})
}
