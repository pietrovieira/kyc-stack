package worker

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"

	"github.com/hibiken/asynq"
	"gorm.io/gorm"

	"kyc-go/internal/facetec"
	"kyc-go/internal/models"
)

const (
	TypeCustomerProfile = "customer:profile"
	TypeKYCProcessing   = "kyc:processing"
)

type CustomerProfilePayload struct {
	CustomerID uint `json:"customer_id"`
}

type KYCProcessingPayload struct {
	KycSessionID uint   `json:"kyc_session_id"`
	RequestBlob  string `json:"request_blob"`
	DocumentType string `json:"document_type"`
}

func NewCustomerProfileTask(customerID uint) (*asynq.Task, error) {
	payload, _ := json.Marshal(CustomerProfilePayload{CustomerID: customerID})
	return asynq.NewTask(TypeCustomerProfile, payload), nil
}

func NewKYCProcessingTask(kycID uint, blob, docType string) (*asynq.Task, error) {
	payload, _ := json.Marshal(KYCProcessingPayload{KycSessionID: kycID, RequestBlob: blob, DocumentType: docType})
	return asynq.NewTask(TypeKYCProcessing, payload, asynq.MaxRetry(3)), nil
}

type Processor struct {
	DB             *gorm.DB
	FacetecService *facetec.Service
}

func (p *Processor) HandleCustomerProfile(ctx context.Context, t *asynq.Task) error {
	var payload CustomerProfilePayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return err
	}
	log.Printf("[worker] CustomerProfile %d", payload.CustomerID)
	// Simula enriquecimento, anti-fraude, etc. Por enquanto só loga.
	return nil
}

func (p *Processor) HandleKYCProcessing(ctx context.Context, t *asynq.Task) error {
	var payload KYCProcessingPayload
	if err := json.Unmarshal(t.Payload(), &payload); err != nil {
		return err
	}
	log.Printf("[worker] KYCProcessing session=%d doc=%s", payload.KycSessionID, payload.DocumentType)
	var kyc models.KycSession
	if err := p.DB.First(&kyc, payload.KycSessionID).Error; err != nil {
		return err
	}
	var customer *models.Customer
	if kyc.CustomerID != nil {
		var c models.Customer
		if err := p.DB.First(&c, *kyc.CustomerID).Error; err == nil {
			customer = &c
		}
	}
	// Tenta FaceTec real, fallback simulação determinística
	var resp *facetec.ProcessResponse
	var err error
	if p.FacetecService != nil {
		resp, err = p.FacetecService.Process(payload.RequestBlob, kyc.ExternalDatabaseRefID)
	}
	if err != nil || resp == nil {
		log.Printf("[worker] FaceTec offline (%v) - simulação", err)
		// Simulação 80% aprova: hash do blob %5 !=0
		h := sha256.Sum256([]byte(payload.RequestBlob))
		hexStr := hex.EncodeToString(h[:])
		approved := hexStr[0]%5 != 0
		match := 1
		if approved {
			match = 4
		}
		resp = &facetec.ProcessResponse{
			Success:        approved,
			LivenessProven: approved,
			MatchLevel:     match,
			DocumentData:   fmt.Sprintf(`{"documentType":"%s","simulated":true}`, payload.DocumentType),
			Raw:            map[string]interface{}{"success": approved, "livenessProven": approved, "matchLevel": match, "simulated": true},
		}
	}
	// Atualiza KycSession
	status := models.KycFailed
	if resp.Success {
		status = models.KycSuccess
	}
	liveness := resp.LivenessProven
	match := resp.MatchLevel
	success := resp.Success
	docData := resp.DocumentData
	facetecJSON, _ := json.Marshal(resp.Raw)
	errMsg := resp.ErrorMessage
	updates := map[string]interface{}{
		"status":           status,
		"liveness_proven":  liveness,
		"match_level":      match,
		"document_data":    docData,
		"success":          success,
		"facetec_response": string(facetecJSON),
		"error_message":    errMsg,
	}
	if err := p.DB.Model(&kyc).Updates(updates).Error; err != nil {
		return err
	}
	// Atualiza Customer
	if customer != nil {
		newStatus := models.StatusKYCRejected
		if resp.Success {
			newStatus = models.StatusKYCApproved
		}
		_ = p.DB.Model(customer).Update("status", newStatus).Error
		log.Printf("[worker] KYC %d -> customer %s status %s", kyc.ID, customer.CPF, newStatus.String())
	}
	return nil
}
