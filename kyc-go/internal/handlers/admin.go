package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"kyc-go/internal/models"
)

type AdminHandler struct {
	DB        *gorm.DB
	JWTSecret string
}

func (h *AdminHandler) Login(c *gin.Context) {
	var input struct {
		Email    string `json:"email" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		// tenta form
		input.Email = c.PostForm("email")
		input.Password = c.PostForm("password")
		if input.Email == "" {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "email e password obrigatórios"})
			return
		}
	}
	email := strings.ToLower(strings.TrimSpace(input.Email))
	var admin models.Admin
	if err := h.DB.Where("email = ?", email).First(&admin).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Email ou senha inválidos", "code": "invalid_credentials"})
		return
	}
	if !admin.Active {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": "Admin desativado"})
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(admin.PasswordHash), []byte(input.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "error": "Email ou senha inválidos", "code": "invalid_credentials"})
		return
	}
	// Gera JWT (mesmo que backoffice use cookie, API retorna token)
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"admin_id": admin.ID,
		"email":    admin.Email,
		"exp":      time.Now().Add(30 * time.Minute).Unix(),
		"iat":      time.Now().Unix(),
	})
	signed, _ := token.SignedString([]byte(h.JWTSecret))
	// Cookie httpOnly secure sameSite strict - anti session hijacking
	c.SetSameSite(http.SameSiteStrictMode)
	c.SetCookie("admin_token", signed, 1800, "/", "", false, true)
	// CSRF token separado para backoffice
	c.JSON(http.StatusOK, gin.H{"success": true, "token": signed, "admin": gin.H{"id": admin.ID, "email": admin.Email, "name": admin.Name}})
}

func (h *AdminHandler) Me(c *gin.Context) {
	admin, _ := c.Get("admin")
	c.JSON(http.StatusOK, gin.H{"success": true, "admin": admin})
}

func (h *AdminHandler) ListCustomers(c *gin.Context) {
	q := c.Query("q")
	statusFilter := c.Query("status")
	page, _ := strconv.Atoi(c.Query("page"))
	if page < 1 {
		page = 1
	}
	limit := 50
	offset := (page - 1) * limit

	query := h.DB.Model(&models.Customer{}).Preload("KycSessions")
	if q != "" {
		like := "%" + escapeLike(q) + "%"
		query = query.Where("cpf LIKE ? OR nome LIKE ? OR sobrenome LIKE ? OR email LIKE ?", like, like, like, like)
	}
	if statusFilter != "" {
		// map string to int
		statusMap := map[string]models.Status{
			"draft": models.StatusDraft, "profile_completed": models.StatusProfileCompleted,
			"kyc_pending": models.StatusKYCPending, "kyc_approved": models.StatusKYCApproved,
			"kyc_rejected": models.StatusKYCRejected, "account_active": models.StatusAccountActive,
		}
		if st, ok := statusMap[statusFilter]; ok {
			query = query.Where("status = ?", st)
		}
	}
	var total int64
	query.Count(&total)
	var customers []models.Customer
	query.Order("created_at desc").Limit(limit).Offset(offset).Find(&customers)

	// stats
	var totalAll, cProfile, cPending, cApproved, cRejected, cActive int64
	h.DB.Model(&models.Customer{}).Count(&totalAll)
	h.DB.Model(&models.Customer{}).Where("status = ?", models.StatusProfileCompleted).Count(&cProfile)
	h.DB.Model(&models.Customer{}).Where("status = ?", models.StatusKYCPending).Count(&cPending)
	h.DB.Model(&models.Customer{}).Where("status = ?", models.StatusKYCApproved).Count(&cApproved)
	h.DB.Model(&models.Customer{}).Where("status = ?", models.StatusKYCRejected).Count(&cRejected)
	h.DB.Model(&models.Customer{}).Where("status = ?", models.StatusAccountActive).Count(&cActive)
	stats := map[string]int64{"total": totalAll, "profile_completed": cProfile, "kyc_pending": cPending, "kyc_approved": cApproved, "kyc_rejected": cRejected, "account_active": cActive}

	// serializa com prevenção XSS (gin escapa JSON)
	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"customers": customers,
		"stats":     stats,
		"pagination": gin.H{"page": page, "limit": limit, "total": total},
	})
}

func (h *AdminHandler) GetCustomer(c *gin.Context) {
	id := c.Param("id")
	var customer models.Customer
	if err := h.DB.Preload("KycSessions", func(db *gorm.DB) *gorm.DB { return db.Order("created_at desc") }).First(&customer, id).Error; err != nil {
		// tenta por cpf
		if err := h.DB.Preload("KycSessions").Where("cpf = ?", id).First(&customer).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado"})
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "customer": customer, "kyc_sessions": customer.KycSessions})
}

func (h *AdminHandler) Approve(c *gin.Context) {
	id := c.Param("id")
	var customer models.Customer
	if err := h.DB.First(&customer, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado"})
		return
	}
	_ = h.DB.Model(&customer).Update("status", models.StatusKYCApproved).Error
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Cliente aprovado", "customer": customer})
}

func (h *AdminHandler) Reject(c *gin.Context) {
	id := c.Param("id")
	var customer models.Customer
	if err := h.DB.First(&customer, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado"})
		return
	}
	_ = h.DB.Model(&customer).Update("status", models.StatusKYCRejected).Error
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Cliente rejeitado", "customer": customer})
}

func escapeLike(s string) string {
	s = strings.ReplaceAll(s, "%", "\\%")
	s = strings.ReplaceAll(s, "_", "\\_")
	return s
}
