package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	HTTPAddr       string
	DatabaseURL    string
	JWTSecret      []byte
	JWTExpiry      time.Duration
}

func Load() (*Config, error) {
	httpAddr := os.Getenv("HTTP_ADDR")
	if httpAddr == "" {
		httpAddr = ":8080"
	}

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}
	if len(secret) < 32 {
		return nil, fmt.Errorf("JWT_SECRET must be at least 32 characters")
	}

	hours := 24
	if v := os.Getenv("JWT_EXPIRY_HOURS"); v != "" {
		var err error
		hours, err = strconv.Atoi(v)
		if err != nil || hours < 1 {
			return nil, fmt.Errorf("JWT_EXPIRY_HOURS must be a positive integer")
		}
	}

	return &Config{
		HTTPAddr:    httpAddr,
		DatabaseURL: dsn,
		JWTSecret:   []byte(secret),
		JWTExpiry:   time.Duration(hours) * time.Hour,
	}, nil
}
