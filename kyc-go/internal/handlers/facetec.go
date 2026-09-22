package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"kyc-go/internal/facetec"
)

type FacetecHandler struct {
	DB      *gorm.DB
	Service *facetec.Service
}

func (h *FacetecHandler) Config(c *gin.Context) {
	// Retorna config pública para Device SDK - sem segredos
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"config": gin.H{
			"serverUrl":              h.Service.BaseURL,
			"facetecServerAvailable": true,
		},
	})
}

func (h *FacetecHandler) Status(c *gin.Context) {
	ok, err := h.Service.Status()
	if err != nil || !ok {
		c.JSON(http.StatusServiceUnavailable, gin.H{"success": false, "error": "FaceTec Server offline", "available": false})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "available": true})
}

func (h *FacetecHandler) Process(c *gin.Context) {
	var input struct {
		RequestBlob           string `json:"requestBlob" binding:"required"`
		ExternalDatabaseRefID string `json:"externalDatabaseRefID" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}
	resp, err := h.Service.Process(input.RequestBlob, input.ExternalDatabaseRefID)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "error": err.Error(), "code": "facetec_error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "facetec": resp.Raw})
}
