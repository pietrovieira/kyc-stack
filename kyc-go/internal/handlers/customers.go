package handlers

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hibiken/asynq"
	"gorm.io/gorm"

	"kyc-go/internal/models"
	"kyc-go/internal/worker"
)

type CustomerHandler struct {
	DB          *gorm.DB
	AsynqClient *asynq.Client
}

type createCustomerInput struct {
	Customer struct {
		CPF            string  `json:"cpf" binding:"required"`
		Nome           string  `json:"nome" binding:"required"`
		Sobrenome      string  `json:"sobrenome" binding:"required"`
		DataNascimento string  `json:"data_nascimento" binding:"required"`
		Email          *string `json:"email"`
		Telefone       *string `json:"telefone"`
		Logradouro     string  `json:"logradouro" binding:"required"`
		Numero         string  `json:"numero" binding:"required"`
		Complemento    *string `json:"complemento"`
		Bairro         string  `json:"bairro" binding:"required"`
		Cidade         string  `json:"cidade" binding:"required"`
		Estado         string  `json:"estado" binding:"required"`
		CEP            string  `json:"cep" binding:"required"`
		Pais           *string `json:"pais"`
	} `json:"customer" binding:"required"`
}

func (h *CustomerHandler) Create(c *gin.Context) {
	rawBody, _ := c.GetRawData()
	c.Request.Body = io.NopCloser(bytes.NewBuffer(rawBody)) // rewind for binding

	var input createCustomerInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": err.Error(), "code": "validation_error"})
		return
	}
	cpf := onlyDigits(input.Customer.CPF)
	if !isValidCPF(cpf) {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "CPF deve ter 11 dígitos", "code": "validation_error"})
		return
	}
	cep := normalizeCEP(input.Customer.CEP)
	if !isValidCEP(cep) {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "CEP inválido", "code": "validation_error"})
		return
	}
	// Idempotency via CPF: se já existe, verifica mesmo perfil
	var existing models.Customer
	if err := h.DB.Where("cpf = ?", cpf).First(&existing).Error; err == nil {
		if sameProfile(existing, input) {
			c.JSON(http.StatusOK, serializeCustomer(existing))
			return
		}
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": "CPF já cadastrado", "code": "cpf_duplicate", "customer": serializeCustomer(existing)})
		return
	}
	// Idempotency-Key header check
	idemKey := c.GetHeader("Idempotency-Key")
	if idemKey != "" {
		bodyHash := sha256Hex(string(rawBody))
		var ik models.IdempotencyKey
		if err := h.DB.Where("key = ?", idemKey).First(&ik).Error; err == nil {
			if ik.RequestBodyHash != bodyHash {
				c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "Idempotency-Key já usada com payload diferente", "code": "idempotency_conflict"})
				return
			}
			var parsed interface{}
			_ = json.Unmarshal([]byte(ik.ResponseBody), &parsed)
			c.JSON(ik.ResponseCode, parsed)
			return
		}
	}

	// Valida data_nascimento e idade >=18
	dob, err := time.Parse("2006-01-02", input.Customer.DataNascimento)
	if err != nil {
		// tenta DD/MM/YYYY
		dob, err = time.Parse("02/01/2006", input.Customer.DataNascimento)
		if err != nil {
			c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "data_nascimento deve ser YYYY-MM-DD", "code": "validation_error"})
			return
		}
	}
	if time.Since(dob).Hours()/24/365 < 18 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "cliente deve ser maior de 18 anos", "code": "validation_error"})
		return
	}
	if time.Since(dob).Hours()/24/365 > 120 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "data inválida", "code": "validation_error"})
		return
	}
	if len(input.Customer.Estado) != 2 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "estado deve ter 2 letras", "code": "validation_error"})
		return
	}
	pais := "Brasil"
	if input.Customer.Pais != nil && *input.Customer.Pais != "" {
		pais = *input.Customer.Pais
	}
	// XSS: sanitize - GORM + JSON já escapa, mas valida comprimento
	if len(input.Customer.Nome) < 2 || len(input.Customer.Nome) > 100 || len(input.Customer.Sobrenome) < 2 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "nome/sobrenome inválido", "code": "validation_error"})
		return
	}

	customer := models.Customer{
		CPF:                   cpf,
		Nome:                  strings.TrimSpace(input.Customer.Nome),
		Sobrenome:             strings.TrimSpace(input.Customer.Sobrenome),
		DataNascimento:        dob,
		Email:                 blankToNil(input.Customer.Email),
		Telefone:              blankToNil(input.Customer.Telefone),
		Logradouro:            strings.TrimSpace(input.Customer.Logradouro),
		Numero:                strings.TrimSpace(input.Customer.Numero),
		Complemento:           blankToNil(input.Customer.Complemento),
		Bairro:                strings.TrimSpace(input.Customer.Bairro),
		Cidade:                strings.TrimSpace(input.Customer.Cidade),
		Estado:                strings.ToUpper(strings.TrimSpace(input.Customer.Estado)),
		CEP:                   cep,
		Pais:                  pais,
		Status:                models.StatusProfileCompleted,
		ExternalDatabaseRefID: cpf,
	}
	if err := h.DB.Create(&customer).Error; err != nil {
		// trata unique violation (race)
		if isUniqueViolation(err) {
			var dup models.Customer
			_ = h.DB.Where("cpf = ?", cpf).First(&dup).Error
			c.JSON(http.StatusConflict, gin.H{"success": false, "error": "CPF já cadastrado (race)", "code": "cpf_duplicate"})
			return
		}
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": err.Error(), "code": "validation_error"})
		return
	}
	// Background job síncrono para app? Sempre async
	if h.AsynqClient != nil {
		task, _ := worker.NewCustomerProfileTask(customer.ID)
		_, _ = h.AsynqClient.Enqueue(task)
	}

	resp := serializeCustomer(customer)
	resp["message"] = "Perfil criado - prossiga para KYC de documentos"
	body, _ := json.Marshal(resp)
	if idemKey != "" {
		_ = h.DB.Create(&models.IdempotencyKey{
			Key:             idemKey,
			RequestMethod:   c.Request.Method,
			RequestPath:     c.Request.URL.Path,
			RequestBodyHash: sha256Hex(string(rawBody)),
			ResponseCode:    http.StatusCreated,
			ResponseBody:    string(body),
			CustomerID:      &customer.ID,
		}).Error
	}
	c.Data(http.StatusCreated, "application/json", body)
}

func (h *CustomerHandler) Show(c *gin.Context) {
	cpf := onlyDigits(c.Param("id"))
	var customer models.Customer
	if err := h.DB.Where("cpf = ?", cpf).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado", "code": "not_found"})
		return
	}
	c.JSON(http.StatusOK, serializeCustomer(customer))
}

func (h *CustomerHandler) Update(c *gin.Context) {
	cpf := onlyDigits(c.Param("id"))
	var customer models.Customer
	if err := h.DB.Where("cpf = ?", cpf).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado"})
		return
	}
	if customer.Status == models.StatusKYCApproved || customer.Status == models.StatusAccountActive {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "error": "Cadastro já aprovado - não pode editar", "code": "locked"})
		return
	}
	var input createCustomerInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": err.Error()})
		return
	}
	updates := map[string]interface{}{}
	if input.Customer.Nome != "" {
		updates["nome"] = input.Customer.Nome
	}
	if input.Customer.Sobrenome != "" {
		updates["sobrenome"] = input.Customer.Sobrenome
	}
	if input.Customer.Logradouro != "" {
		updates["logradouro"] = input.Customer.Logradouro
	}
	if input.Customer.Numero != "" {
		updates["numero"] = input.Customer.Numero
	}
	if input.Customer.Bairro != "" {
		updates["bairro"] = input.Customer.Bairro
	}
	if input.Customer.Cidade != "" {
		updates["cidade"] = input.Customer.Cidade
	}
	if input.Customer.Estado != "" {
		updates["estado"] = strings.ToUpper(input.Customer.Estado)
	}
	if input.Customer.CEP != "" {
		updates["cep"] = normalizeCEP(input.Customer.CEP)
	}
	if len(updates) > 0 {
		_ = h.DB.Model(&customer).Updates(updates).Error
		_ = h.DB.First(&customer, customer.ID).Error
	}
	c.JSON(http.StatusOK, serializeCustomer(customer))
}

func (h *CustomerHandler) KYC(c *gin.Context) {
	cpf := onlyDigits(c.Param("id"))
	rawBody, _ := c.GetRawData()
	c.Request.Body = io.NopCloser(bytes.NewBuffer(rawBody))
	var customer models.Customer
	if err := h.DB.Where("cpf = ?", cpf).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado"})
		return
	}
	if !customer.CanSubmitKYC() {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "Status atual não permite KYC: " + customer.Status.String(), "code": "invalid_status"})
		return
	}
	var body map[string]interface{}
	_ = json.Unmarshal(rawBody, &body)
	// tenta pegar requestBlob de várias chaves
	requestBlob := ""
	if v, ok := body["requestBlob"]; ok {
		requestBlob, _ = v.(string)
	}
	if requestBlob == "" {
		if v, ok := body["request_blob"]; ok {
			requestBlob, _ = v.(string)
		}
	}
	// aceita form-data
	if requestBlob == "" {
		requestBlob = c.PostForm("requestBlob")
	}
	if requestBlob == "" {
		// último fallback: lê params
		requestBlob = c.GetString("requestBlob")
	}
	if requestBlob == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "requestBlob obrigatório (FaceTec Device SDK)"})
		return
	}
	documentType := "rg"
	if v, ok := body["documentType"]; ok {
		if s, ok := v.(string); ok && s != "" {
			documentType = s
		}
	}
	if v := c.PostForm("documentType"); v != "" {
		documentType = v
	}
	idemKey := c.GetHeader("Idempotency-Key")
	if idemKey == "" {
		idemKey = uuid.NewString()
		// se não enviar, geramos mas não exigimos idempotência
	}
	// verifica idempotency se já existe
	if idemKey != "" {
		bodyHash := sha256Hex(string(rawBody))
		var existing models.IdempotencyKey
		if err := h.DB.Where("key = ?", idemKey).First(&existing).Error; err == nil {
			if existing.RequestBodyHash != bodyHash {
				c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "Idempotency-Key já usada com payload diferente"})
				return
			}
			var parsed interface{}
			_ = json.Unmarshal([]byte(existing.ResponseBody), &parsed)
			c.JSON(existing.ResponseCode, parsed)
			return
		}
	}
	// atualiza status para pending
	_ = h.DB.Model(&customer).Update("status", models.StatusKYCPending).Error
	// cria KycSession
	digest := sha256Hex(requestBlob)
	kyc := models.KycSession{
		CustomerID:            &customer.ID,
		ExternalDatabaseRefID: customer.CPF,
		SessionType:           models.KycPhotoIDMatch,
		Status:                models.KycPending,
		RequestBlobDigest:     digest,
		IdempotencyKey:        &idemKey,
	}
	if err := h.DB.Create(&kyc).Error; err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": err.Error()})
		return
	}
	// dispara job async
	if h.AsynqClient != nil {
		task, _ := worker.NewKYCProcessingTask(kyc.ID, requestBlob, documentType)
		_, _ = h.AsynqClient.Enqueue(task)
	}
	// recarrega customer
	_ = h.DB.First(&customer, customer.ID).Error
	resp := map[string]interface{}{
		"success":      true,
		"message":      "KYC recebido - processamento em background",
		"customer":     serializeCustomer(customer)["customer"],
		"kycSessionId": kyc.ID,
		"status":       customer.Status.String(),
	}
	// só armazena idempotency se veio header original
	origKey := c.GetHeader("Idempotency-Key")
	if origKey != "" {
		b, _ := json.Marshal(resp)
		_ = h.DB.Create(&models.IdempotencyKey{
			Key:             origKey,
			RequestMethod:   c.Request.Method,
			RequestPath:     c.Request.URL.Path,
			RequestBodyHash: sha256Hex(string(rawBody)),
			ResponseCode:    http.StatusAccepted,
			ResponseBody:    string(b),
			CustomerID:      &customer.ID,
		}).Error
	}
	c.JSON(http.StatusAccepted, resp)
}

func (h *CustomerHandler) Status(c *gin.Context) {
	cpf := onlyDigits(c.Param("id"))
	var customer models.Customer
	if err := h.DB.Where("cpf = ?", cpf).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado"})
		return
	}
	var last models.KycSession
	_ = h.DB.Where("customer_id = ?", customer.ID).Order("created_at desc").First(&last).Error
	var kyc interface{}
	if last.ID != 0 {
		kyc = gin.H{"id": last.ID, "status": last.Status, "livenessProven": last.LivenessProven, "success": last.Success, "matchLevel": last.MatchLevel, "createdAt": last.CreatedAt}
	}
	c.JSON(http.StatusOK, gin.H{"customer": serializeCustomer(customer), "kyc": kyc})
}

// helpers

func serializeCustomer(c models.Customer) map[string]interface{} {
	return map[string]interface{}{
		"success": true,
		"customer": map[string]interface{}{
			"id":                    c.ID,
			"cpf":                   c.CPF,
			"nome":                  c.Nome,
			"sobrenome":             c.Sobrenome,
			"fullName":              c.FullName(),
			"dataNascimento":        c.DataNascimento.Format("2006-01-02"),
			"email":                 c.Email,
			"telefone":              c.Telefone,
			"endereco": map[string]interface{}{
				"logradouro":  c.Logradouro,
				"numero":      c.Numero,
				"complemento": c.Complemento,
				"bairro":      c.Bairro,
				"cidade":      c.Cidade,
				"estado":      c.Estado,
				"cep":         c.CEP,
				"pais":        c.Pais,
				"completo":    c.EnderecoCompleto(),
			},
			"status":                 c.Status.String(),
			"externalDatabaseRefID": c.ExternalDatabaseRefID,
			"createdAt":              c.CreatedAt,
			"updatedAt":              c.UpdatedAt,
		},
		"id":                    c.ID,
		"cpf":                   c.CPF,
		"nome":                  c.Nome,
		"sobrenome":             c.Sobrenome,
		"fullName":              c.FullName(),
		"dataNascimento":        c.DataNascimento,
		"status":                c.Status.String(),
		"externalDatabaseRefID": c.ExternalDatabaseRefID,
		"createdAt":             c.CreatedAt,
	}
}

func sameProfile(existing models.Customer, input createCustomerInput) bool {
	fields := map[string]string{
		"nome":       existing.Nome,
		"sobrenome":  existing.Sobrenome,
		"logradouro": existing.Logradouro,
		"numero":     existing.Numero,
		"bairro":     existing.Bairro,
		"cidade":     existing.Cidade,
		"estado":     existing.Estado,
		"cep":        existing.CEP,
	}
	check := map[string]string{
		"nome":       input.Customer.Nome,
		"sobrenome":  input.Customer.Sobrenome,
		"logradouro": input.Customer.Logradouro,
		"numero":     input.Customer.Numero,
		"bairro":     input.Customer.Bairro,
		"cidade":     input.Customer.Cidade,
		"estado":     strings.ToUpper(input.Customer.Estado),
		"cep":        normalizeCEP(input.Customer.CEP),
	}
	for k, v := range check {
		if v != "" && fields[k] != v {
			return false
		}
	}
	return true
}

func onlyDigits(s string) string {
	re := regexp.MustCompile(`\D`)
	return re.ReplaceAllString(s, "")
}
func normalizeCEP(s string) string {
	d := onlyDigits(s)
	if len(d) == 8 {
		return d[:5] + "-" + d[5:]
	}
	return s
}
func isValidCPF(s string) bool { return len(s) == 11 && regexp.MustCompile(`^\d{11}$`).MatchString(s) }
func isValidCEP(s string) bool { return regexp.MustCompile(`^\d{5}-\d{3}$`).MatchString(s) }
func isUniqueViolation(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "duplicate") || strings.Contains(msg, "unique") || strings.Contains(msg, "23505")
}
func blankToNil(s *string) *string {
	if s == nil {
		return nil
	}
	t := strings.TrimSpace(*s)
	if t == "" {
		return nil
	}
	return &t
}
func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}


