package config

import (
	"os"
	"strings"
)

type Config struct {
	Env                string
	Port               string
	DatabaseURL        string
	RedisURL           string
	APIHMACSecret      string
	APIHMACKeyID       string
	JWTSecret          string
	FacetecServerURL   string
	FacetecDeviceKeyID string
	FacetecProdKey     string
	KYCAppOrigin       string
	AdminEmail         string
	AdminPassword      string
	UploadDir          string
	CepAPIBaseURL      string
}

func Load() *Config {
	return &Config{
		Env:                getEnv("APP_ENV", "development"),
		Port:               getEnv("PORT", "8080"),
		DatabaseURL:        getEnv("DATABASE_URL", "postgres://kyc:kyc@postgres:5432/kyc?sslmode=disable"),
		RedisURL:           getEnv("REDIS_URL", "redis://redis:6379/0"),
		APIHMACSecret:      getEnv("API_HMAC_SECRET", "obsidian_hmac_secret_2026_change_me_32bytes!"),
		APIHMACKeyID:       getEnv("API_HMAC_KEY_ID", "obsidian_app"),
		JWTSecret:          getEnv("JWT_SECRET", "obsidian_jwt_secret_2026_change_me_64bytes_hex!_dev_only"),
		FacetecServerURL:   getEnv("FACETEC_SERVER_URL", "http://facetec-server:8080"),
		FacetecDeviceKeyID: getEnv("FACETEC_DEVICE_KEY_IDENTIFIER", ""),
		FacetecProdKey:     getEnv("FACETEC_PRODUCTION_KEY", ""),
		KYCAppOrigin:       getEnv("KYC_APP_ORIGIN", "http://localhost:3001,http://localhost:5173,http://localhost:*"),
		AdminEmail:         strings.ToLower(getEnv("ADMIN_SEED_EMAIL", "admin@obsidian.com")),
		AdminPassword:      getEnv("ADMIN_SEED_PASSWORD", "Obsidian123!"),
		UploadDir:          getEnv("UPLOAD_DIR", "/app/uploads"),
		CepAPIBaseURL:      getEnv("CEP_API_BASE_URL", "https://viacep.com.br/ws"),
	}
}

func getEnv(k, fallback string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fallback
}
