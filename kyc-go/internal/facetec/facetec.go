package facetec

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Service struct {
	BaseURL string
	Client  *http.Client
}

func New(baseURL string) *Service {
	return &Service{
		BaseURL: baseURL,
		Client:  &http.Client{Timeout: 15 * time.Second},
	}
}

type ProcessRequest struct {
	RequestBlob           string `json:"requestBlob"`
	ExternalDatabaseRefID string `json:"externalDatabaseRefID"`
	SessionType           string `json:"sessionType,omitempty"`
}

type ProcessResponse struct {
	Success        bool   `json:"success"`
	LivenessProven bool   `json:"livenessProven"`
	MatchLevel     int    `json:"matchLevel"`
	DocumentData   string `json:"documentData"`
	FaceMap        string `json:"faceMap"`
	ErrorMessage   string `json:"errorMessage"`
	Raw            map[string]interface{}
}

func (s *Service) Process(requestBlob, refID string) (*ProcessResponse, error) {
	payload := map[string]string{
		"requestBlob":           requestBlob,
		"externalDatabaseRefID": refID,
	}
	b, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", s.BaseURL+"/process-request", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("facetec server %d: %s", resp.StatusCode, string(body))
	}
	var m map[string]interface{}
	_ = json.Unmarshal(body, &m)
	return &ProcessResponse{
		Success:        boolVal(m, "success"),
		LivenessProven: boolVal(m, "livenessProven"),
		MatchLevel:     intVal(m, "matchLevel"),
		DocumentData:   strVal(m, "documentData"),
		FaceMap:        strVal(m, "faceMap"),
		ErrorMessage:   strVal(m, "errorMessage"),
		Raw:            m,
	}, nil
}

func (s *Service) Status() (bool, error) {
	resp, err := s.Client.Get(s.BaseURL + "/status")
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	return resp.StatusCode == 200, nil
}

func boolVal(m map[string]interface{}, k string) bool {
	if v, ok := m[k]; ok {
		if b, ok := v.(bool); ok {
			return b
		}
	}
	return false
}
func intVal(m map[string]interface{}, k string) int {
	if v, ok := m[k]; ok {
		switch x := v.(type) {
		case float64:
			return int(x)
		case int:
			return x
		}
	}
	return 0
}
func strVal(m map[string]interface{}, k string) string {
	if v, ok := m[k]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
