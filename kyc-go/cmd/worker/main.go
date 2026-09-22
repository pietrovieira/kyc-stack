package main

import (
	"log"

	"github.com/hibiken/asynq"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"kyc-go/internal/config"
	"kyc-go/internal/facetec"
	"kyc-go/internal/models"
	"kyc-go/internal/worker"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	_ = models.AutoMigrate(db)

	opt, _ := redis.ParseURL(cfg.RedisURL)
	redisOpt := asynq.RedisClientOpt{Addr: opt.Addr, Password: opt.Password, DB: opt.DB}
	srv := asynq.NewServer(redisOpt, asynq.Config{
		Concurrency: 10,
		Queues: map[string]int{
			"kyc":     6,
			"default": 3,
			"critical": 1,
		},
	})

	mux := asynq.NewServeMux()
	proc := &worker.Processor{DB: db, FacetecService: facetec.New(cfg.FacetecServerURL)}
	mux.HandleFunc(worker.TypeCustomerProfile, proc.HandleCustomerProfile)
	mux.HandleFunc(worker.TypeKYCProcessing, proc.HandleKYCProcessing)

	log.Printf("Banco Obsidian Worker listening (queues: kyc, default) -> %s", cfg.FacetecServerURL)
	if err := srv.Run(mux); err != nil {
		log.Fatalf("worker: %v", err)
	}
}
