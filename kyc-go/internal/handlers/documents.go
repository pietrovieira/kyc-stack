package handlers

import (
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"kyc-go/internal/models"
)

// DocumentHandler faz upload multipart de documentos e salva em pasta local
// organizada por CPF e tipo de documento.
//
// Layout: UPLOAD_DIR/{cpf}/{tipo}/{uuid}.{ext}
//   - {cpf}  -> somente dígitos (sanitizado)
//   - {tipo} -> rg | cnh | selfie (whitelist)
//   - nome   -> UUID para evitar path traversal e colisão
type DocumentHandler struct {
	DB        *gorm.DB
	UploadDir string
}

var (
	allowedDocTypes = map[string]bool{"rg": true, "cnh": true, "selfie": true}
	allowedExts     = map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".pdf": true}
)

const maxUploadSize = 15 << 20 // 15MB

func (h *DocumentHandler) Upload(c *gin.Context) {
	cpf := onlyDigits(c.Param("id"))
	if !isValidCPF(cpf) {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "CPF inválido", "code": "validation_error"})
		return
	}
	// Garante que o customer existe (evita órfãos)
	var customer models.Customer
	if err := h.DB.Where("cpf = ?", cpf).First(&customer).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "cliente não encontrado", "code": "not_found"})
		return
	}

	docType := strings.ToLower(strings.TrimSpace(c.PostForm("type")))
	if docType == "" {
		docType = "rg"
	}
	if !allowedDocTypes[docType] {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "tipo de documento inválido", "code": "validation_error"})
		return
	}

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "campo 'file' obrigatório (multipart/form-data)", "code": "validation_error"})
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !allowedExts[ext] {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "extensão não permitida", "code": "validation_error"})
		return
	}
	if header.Size > maxUploadSize {
		c.JSON(http.StatusRequestEntityTooLarge, gin.H{"success": false, "error": "arquivo excede 15MB", "code": "file_too_large"})
		return
	}

	dir := filepath.Join(h.UploadDir, cpf, docType)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "falha ao criar diretório", "code": "storage_error"})
		return
	}
	filename := uuid.NewString() + ext
	fullPath := filepath.Join(dir, filename)
	dst, err := os.Create(fullPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "falha ao salvar arquivo", "code": "storage_error"})
		return
	}
	defer dst.Close()
	if _, err := io.Copy(dst, file); err != nil {
		_ = os.Remove(fullPath)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "falha ao gravar arquivo", "code": "storage_error"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success":   true,
		"message":   "Documento enviado",
		"cpf":       cpf,
		"type":      docType,
		"filename":  filename,
		"size":      header.Size,
		"storedAt":  fmt.Sprintf("uploads/%s/%s/%s", cpf, docType, filename),
	})
}

// SaveMultipartToFile é um helper reutilizável para salvar um arquivo já lido.
func SaveMultipartToFile(baseDir, cpf, docType, ext string, f multipart.File) (string, error) {
	if !regexp.MustCompile(`^\.[a-z0-9]+$`).MatchString(ext) {
		return "", fmt.Errorf("extensão inválida")
	}
	dir := filepath.Join(baseDir, cpf, docType)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	name := uuid.NewString() + ext
	dst, err := os.Create(filepath.Join(dir, name))
	if err != nil {
		return "", err
	}
	defer dst.Close()
	if _, err := io.Copy(dst, f); err != nil {
		return "", err
	}
	return filepath.Join(dir, name), nil
}
