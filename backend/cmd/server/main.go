package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"vaultspend/internal/auth"
	"vaultspend/internal/config"
	"vaultspend/internal/db"
	"vaultspend/internal/finance"
	"vaultspend/internal/middleware"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx := context.Background()
	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("database ping: %v", err)
	}

	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	h := &auth.Handlers{
		Pool:      pool,
		JWTSecret: cfg.JWTSecret,
		JWTExpiry: cfg.JWTExpiry,
	}
	fh := &finance.Handlers{Pool: pool}

	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Accept", "Authorization", "Content-Type", "X-Request-ID"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	v1 := r.Group("/v1")
	{
		v1.POST("/auth/register", h.Register)
		v1.POST("/auth/login", h.Login)

		authed := v1.Group("")
		authed.Use(middleware.BearerJWT(cfg.JWTSecret))
		authed.GET("/me", h.Me)
		authed.GET("/sync/status", fh.SyncStatus)

		authed.GET("/categories", fh.ListCategories)
		authed.POST("/categories", fh.CreateCategory)
		authed.PATCH("/categories/:id", fh.UpdateCategory)
		authed.DELETE("/categories/:id", fh.DeleteCategory)

		authed.GET("/expenses", fh.ListExpenses)
		authed.POST("/expenses", fh.CreateExpense)
		authed.PATCH("/expenses/:id", fh.UpdateExpense)
		authed.DELETE("/expenses/:id", fh.DeleteExpense)

		authed.GET("/subscriptions", fh.ListSubscriptions)
		authed.POST("/subscriptions", fh.CreateSubscription)
		authed.PATCH("/subscriptions/:id", fh.UpdateSubscription)
		authed.DELETE("/subscriptions/:id", fh.DeleteSubscription)
	}

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("listening on %s (gin)", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}
