package main

import (
	"log"
	"os"
	"strings"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/hibiken/asynq"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"kyc-go/internal/config"
	"kyc-go/internal/facetec"
	"kyc-go/internal/handlers"
	hmacMW "kyc-go/internal/hmac"
	"kyc-go/internal/middleware"
	"kyc-go/internal/models"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	gin.SetMode(gin.ReleaseMode)
	if cfg.Env == "development" {
		gin.SetMode(gin.DebugMode)
	}

	// DB
	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("db connect: %v", err)
	}
	if err := models.AutoMigrate(db); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	seedAdmin(db, cfg)

	// Redis
	opt, _ := redis.ParseURL(cfg.RedisURL)
	rdb := redis.NewClient(opt)

	// Asynq client for background jobs (só app async)
	var asynqClient *asynq.Client
	if opt != nil {
		redisOpt := asynq.RedisClientOpt{Addr: opt.Addr, Password: opt.Password, DB: opt.DB}
		asynqClient = asynq.NewClient(redisOpt)
		defer asynqClient.Close()
	}

	facetecSvc := facetec.New(cfg.FacetecServerURL)

	r := gin.New()
	r.Use(middleware.Recovery())
	r.Use(middleware.SecurityHeaders())
	r.Use(gin.Logger())

	// CORS - libera localhost em qualquer porta (Flutter Web roda em porta aleatória 4xxxx) + origins configuradas
	origins := strings.Split(cfg.KYCAppOrigin, ",")
	allowedMap := map[string]bool{}
	for _, o := range origins {
		allowedMap[strings.TrimSpace(o)] = true
	}
	corsCfg := cors.Config{
		AllowOriginFunc: func(origin string) bool {
			if allowedMap[origin] || allowedMap["*"] {
				return true
			}
			// libera qualquer localhost/127.0.0.1 com porta dinâmica (Flutter Web, Vite, etc)
			if strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:") {
				return true
			}
			// wildcard http://localhost:* da config
			for o := range allowedMap {
				if strings.Contains(o, "*") && strings.HasPrefix(origin, strings.ReplaceAll(o, "*", "")) {
					return true
				}
			}
			return false
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-API-Key", "X-Timestamp", "X-Nonce", "X-Signature", "Idempotency-Key"},
		ExposeHeaders:    []string{"Authorization"},
		AllowCredentials: true,
	}
	r.Use(cors.New(corsCfg))

	// Health
	r.GET("/up", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	r.GET("/health", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok", "service": "kyc-go-api"}) })

	// Handlers
	customerH := &handlers.CustomerHandler{DB: db, AsynqClient: asynqClient}
	adminH := &handlers.AdminHandler{DB: db, JWTSecret: cfg.JWTSecret}
	facetecH := &handlers.FacetecHandler{DB: db, Service: facetecSvc}
	documentH := &handlers.DocumentHandler{DB: db, UploadDir: cfg.UploadDir}
	cepH := &handlers.CepHandler{BaseURL: cfg.CepAPIBaseURL}

	// Admin (backoffice) - SEM HMAC, com JWT/Cookie + CSRF, síncrono
	admin := r.Group("/api/admin")
	{
		admin.POST("/login", adminH.Login)
		// protegidas
		protected := admin.Group("")
		protected.Use(AuthMiddleware(cfg.JWTSecret, db))
		{
			protected.GET("/me", adminH.Me)
			protected.GET("/customers", adminH.ListCustomers)
			protected.GET("/customers/:id", adminH.GetCustomer)
			protected.POST("/customers/:id/approve", adminH.Approve)
			protected.POST("/customers/:id/reject", adminH.Reject)
		}
	}
	// Também expõe admin via /admin/* para compatibilidade Next.js proxy
	r.POST("/admin/login", adminH.Login)

	// API v1 - só app com HMAC (segurança ponta a ponta)
	v1 := r.Group("/api/v1")
	v1.Use(hmacMW.Middleware(cfg.APIHMACSecret, cfg.APIHMACKeyID, rdb))
	{
		v1.POST("/customers", customerH.Create)
		v1.GET("/customers/:id", customerH.Show)
		v1.PATCH("/customers/:id", customerH.Update)
		v1.POST("/customers/:id/kyc", customerH.KYC)
		v1.GET("/customers/:id/status", customerH.Status)
		v1.POST("/customers/:id/documents", documentH.Upload)

		v1.GET("/cep/:cep", cepH.Lookup)

		v1.GET("/facetec/config", facetecH.Config)
		v1.GET("/facetec/status", facetecH.Status)
		v1.POST("/facetec/process", facetecH.Process)
	}

	// Legado /api/* sem HMAC? Mantém para compatibilidade mas com HMAC também
	legacy := r.Group("/api")
	legacy.Use(hmacMW.Middleware(cfg.APIHMACSecret, cfg.APIHMACKeyID, rdb))
	{
		legacy.GET("/facetec/config", facetecH.Config)
		legacy.GET("/facetec/status", facetecH.Status)
	}

	port := cfg.Port
	if port == "" {
		port = "8080"
	}
	// porta interna 8080, mas docker mapeia 3000:8080 para compatibilidade
	if os.Getenv("PORT") == "" {
		port = "8080"
	}
	log.Printf("Banco Obsidian Go API listening on :%s env=%s", port, cfg.Env)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}

func seedAdmin(db *gorm.DB, cfg *config.Config) {
	var count int64
	db.Model(&models.Admin{}).Count(&count)
	if count > 0 {
		return
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte(cfg.AdminPassword), bcrypt.DefaultCost)
	name := "Admin Obsidian"
	admin := models.Admin{Email: cfg.AdminEmail, Name: &name, PasswordHash: string(hash), Active: true}
	_ = db.Create(&admin).Error
	log.Printf("seed admin %s", cfg.AdminEmail)
}

// AuthMiddleware valida JWT via Cookie ou Authorization header
func AuthMiddleware(secret string, db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenStr := ""
		if ck, err := c.Cookie("admin_token"); err == nil {
			tokenStr = ck
		}
		if tokenStr == "" {
			h := c.GetHeader("Authorization")
			if strings.HasPrefix(h, "Bearer ") {
				tokenStr = strings.TrimPrefix(h, "Bearer ")
			}
		}
		if tokenStr == "" {
			c.AbortWithStatusJSON(401, gin.H{"success": false, "error": "Não autenticado", "code": "unauthorized"})
			return
		}
		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(401, gin.H{"success": false, "error": "Token inválido", "code": "invalid_token"})
			return
		}
		adminIDFloat, ok := claims["admin_id"].(float64)
		if !ok {
			c.AbortWithStatusJSON(401, gin.H{"success": false, "error": "Token inválido"})
			return
		}
		adminID := uint(adminIDFloat)
		var admin models.Admin
		if err := db.First(&admin, adminID).Error; err != nil || !admin.Active {
			c.AbortWithStatusJSON(401, gin.H{"success": false, "error": "Admin não encontrado"})
			return
		}
		c.Set("admin", admin)
		c.Set("admin_id", admin.ID)
		c.Next()
	}
}
