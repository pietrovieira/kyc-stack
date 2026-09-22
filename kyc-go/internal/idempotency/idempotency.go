package idempotency

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kyc-go/internal/models"
)

func CheckAndStore(c *gin.Context, db *gorm.DB, key string, requestBody string, customerID *uint, responseCode int, responseBody interface{}) (bool, interface{}) {
	if key == "" {
		return false, nil
	}
	bodyHash := sha256Hex(requestBody)
	var existing models.IdempotencyKey
	if err := db.Where("key = ?", key).First(&existing).Error; err == nil {
		if existing.RequestBodyHash != bodyHash {
			c.AbortWithStatusJSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "Idempotency-Key já usada com payload diferente", "code": "idempotency_conflict"})
			return true, nil
		}
		var parsed interface{}
		_ = json.Unmarshal([]byte(existing.ResponseBody), &parsed)
		c.AbortWithStatusJSON(existing.ResponseCode, parsed)
		return true, nil
	}
	// cria novo
	b, _ := json.Marshal(responseBody)
	ik := models.IdempotencyKey{
		Key:             key,
		CustomerID:      customerID,
		RequestMethod:   c.Request.Method,
		RequestPath:     c.Request.URL.Path,
		RequestBodyHash: bodyHash,
		ResponseCode:    responseCode,
		ResponseBody:    string(b),
	}
	_ = db.Create(&ik).Error
	return false, nil
}

func Lookup(c *gin.Context, db *gorm.DB, key string, requestBody string) (bool, bool) {
	// retorna (found, conflict)
	if key == "" {
		return false, false
	}
	bodyHash := sha256Hex(requestBody)
	var existing models.IdempotencyKey
	err := db.Where("key = ?", key).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, false
	}
	if err != nil {
		return false, false
	}
	if existing.RequestBodyHash != bodyHash {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "Idempotency-Key já usada com payload diferente", "code": "idempotency_conflict"})
		c.Abort()
		return true, true
	}
	var parsed interface{}
	_ = json.Unmarshal([]byte(existing.ResponseBody), &parsed)
	c.JSON(existing.ResponseCode, parsed)
	c.Abort()
	return true, false
}

func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}
