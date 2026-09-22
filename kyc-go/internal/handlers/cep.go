package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// CepHandler consulta o endereço por CEP na API ViaCEP (ou serviço compatível).
type CepHandler struct {
	Client  *http.Client
	BaseURL string
}

type viaCepResponse struct {
	CEP         string `json:"cep"`
	Logradouro  string `json:"logradouro"`
	Complemento string `json:"complemento"`
	Bairro      string `json:"bairro"`
	Localidade  string `json:"localidade"`
	UF          string `json:"uf"`
	Erro        bool   `json:"erro"`
}

func (h *CepHandler) Lookup(c *gin.Context) {
	cep := onlyDigits(c.Param("cep"))
	if len(cep) != 8 {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"success": false, "error": "CEP deve ter 8 dígitos", "code": "validation_error"})
		return
	}

	base := strings.TrimRight(h.BaseURL, "/")
	if base == "" {
		base = "https://viacep.com.br/ws"
	}
	client := h.Client
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}

	url := fmt.Sprintf("%s/%s/json/", base, cep)
	resp, err := client.Get(url)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "error": "falha ao consultar serviço de CEP", "code": "cep_lookup_failed"})
		return
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "error": "falha ao ler resposta do serviço de CEP", "code": "cep_lookup_failed"})
		return
	}
	if resp.StatusCode != http.StatusOK {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "error": "serviço de CEP indisponível", "code": "cep_lookup_failed"})
		return
	}

	var v viaCepResponse
	if err := json.Unmarshal(body, &v); err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "error": "resposta inválida do serviço de CEP", "code": "cep_lookup_failed"})
		return
	}
	if v.Erro || v.CEP == "" {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "CEP não encontrado", "code": "cep_not_found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"cep":         normalizeCEP(v.CEP),
		"logradouro":  v.Logradouro,
		"complemento": v.Complemento,
		"bairro":      v.Bairro,
		"cidade":      v.Localidade,
		"estado":      strings.ToUpper(v.UF),
	})
}
