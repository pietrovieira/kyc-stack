package models

import (
	"time"

	"gorm.io/gorm"
)

type Status int

const (
	StatusDraft            Status = 0
	StatusProfileCompleted Status = 1
	StatusKYCPending       Status = 2
	StatusKYCApproved      Status = 3
	StatusKYCRejected      Status = 4
	StatusAccountActive    Status = 5
)

func (s Status) String() string {
	switch s {
	case StatusDraft:
		return "draft"
	case StatusProfileCompleted:
		return "profile_completed"
	case StatusKYCPending:
		return "kyc_pending"
	case StatusKYCApproved:
		return "kyc_approved"
	case StatusKYCRejected:
		return "kyc_rejected"
	case StatusAccountActive:
		return "account_active"
	default:
		return "draft"
	}
}

type Customer struct {
	ID                     uint      `gorm:"primaryKey" json:"id"`
	CPF                    string    `gorm:"uniqueIndex;size:11;not null" json:"cpf"`
	Nome                   string    `gorm:"size:100;not null" json:"nome"`
	Sobrenome              string    `gorm:"size:100;not null" json:"sobrenome"`
	DataNascimento         time.Time `gorm:"not null" json:"data_nascimento"`
	Email                  *string   `gorm:"uniqueIndex;size:255" json:"email,omitempty"`
	Telefone               *string   `gorm:"size:20" json:"telefone,omitempty"`
	Logradouro             string    `gorm:"not null" json:"logradouro"`
	Numero                 string    `gorm:"not null" json:"numero"`
	Complemento            *string   `gorm:"size:255" json:"complemento,omitempty"`
	Bairro                 string    `gorm:"not null" json:"bairro"`
	Cidade                 string    `gorm:"not null" json:"cidade"`
	Estado                 string    `gorm:"size:2;not null" json:"estado"`
	CEP                    string    `gorm:"not null" json:"cep"`
	Pais                   string    `gorm:"not null;default:Brasil" json:"pais"`
	Status                 Status    `gorm:"not null;default:0;index" json:"status"`
	ExternalDatabaseRefID  string    `gorm:"uniqueIndex;not null" json:"external_database_ref_id"`
	CreatedAt              time.Time `json:"created_at"`
	UpdatedAt              time.Time `json:"updated_at"`
	KycSessions            []KycSession    `gorm:"foreignKey:CustomerID" json:"kyc_sessions,omitempty"`
	IdempotencyKeys        []IdempotencyKey `gorm:"foreignKey:CustomerID" json:"-"`
}

func (c *Customer) FullName() string { return c.Nome + " " + c.Sobrenome }
func (c *Customer) EnderecoCompleto() string {
	parts := c.Logradouro + ", " + c.Numero
	if c.Complemento != nil && *c.Complemento != "" {
		parts += " - " + *c.Complemento
	}
	parts += " - " + c.Bairro + " - " + c.Cidade + "/" + c.Estado + " - CEP " + c.CEP + " - " + c.Pais
	return parts
}
func (c *Customer) CanSubmitKYC() bool {
	return c.Status == StatusProfileCompleted || c.Status == StatusKYCPending || c.Status == StatusKYCRejected
}

type KycSessionType int

const (
	KycLiveness    KycSessionType = 0
	KycEnrollment  KycSessionType = 1
	KycVerification KycSessionType = 2
	KycPhotoIDMatch KycSessionType = 3
	KycIDScanOnly  KycSessionType = 4
)

type KycStatus int

const (
	KycPending KycStatus = 0
	KycSuccess KycStatus = 1
	KycFailed  KycStatus = 2
)

type KycSession struct {
	ID                     uint            `gorm:"primaryKey" json:"id"`
	CustomerID             *uint           `gorm:"index" json:"customer_id,omitempty"`
	ExternalDatabaseRefID  string          `gorm:"index" json:"external_database_ref_id"`
	SessionType            KycSessionType  `gorm:"not null;default:0" json:"session_type"`
	Status                 KycStatus       `gorm:"not null;default:0" json:"status"`
	RequestBlobDigest      string          `gorm:"size:64" json:"request_blob_digest,omitempty"`
	IdempotencyKey         *string         `gorm:"uniqueIndex;size:64" json:"idempotency_key,omitempty"`
	LivenessProven         *bool           `json:"liveness_proven,omitempty"`
	MatchLevel             *int            `json:"match_level,omitempty"`
	DocumentData           *string         `gorm:"type:text" json:"document_data,omitempty"`
	Success                *bool           `json:"success,omitempty"`
	FacetecResponse        *string         `gorm:"type:text" json:"facetec_response,omitempty"`
	ErrorMessage           *string         `gorm:"type:text" json:"error_message,omitempty"`
	CreatedAt              time.Time       `json:"created_at"`
	UpdatedAt              time.Time       `json:"updated_at"`
}

type IdempotencyKey struct {
	ID               uint      `gorm:"primaryKey" json:"id"`
	Key              string    `gorm:"uniqueIndex;size:64;not null" json:"key"`
	CustomerID       *uint     `gorm:"index" json:"customer_id,omitempty"`
	RequestMethod    string    `gorm:"size:10" json:"request_method"`
	RequestPath      string    `gorm:"size:512" json:"request_path"`
	RequestBodyHash  string    `gorm:"size:64" json:"request_body_hash"`
	ResponseCode     int       `json:"response_code"`
	ResponseBody     string    `gorm:"type:text" json:"response_body"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type Admin struct {
	ID            uint      `gorm:"primaryKey" json:"id"`
	Email         string    `gorm:"uniqueIndex;not null" json:"email"`
	Name          *string   `json:"name,omitempty"`
	PasswordHash  string    `gorm:"not null" json:"-"`
	Active        bool      `gorm:"default:true" json:"active"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// Para gorm migrator
func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&Customer{}, &KycSession{}, &IdempotencyKey{}, &Admin{})
}
