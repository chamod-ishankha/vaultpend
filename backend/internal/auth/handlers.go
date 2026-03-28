package auth

import (
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"vaultspend/internal/middleware"
	"vaultspend/internal/token"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

var emailRe = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)

type Handlers struct {
	Pool      *pgxpool.Pool
	JWTSecret []byte
	JWTExpiry time.Duration
}

type registerReq struct {
	Email             string `json:"email" binding:"required"`
	Password          string `json:"password" binding:"required"`
	PreferredCurrency string `json:"preferred_currency"`
}

type loginReq struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type tokenResp struct {
	AccessToken string  `json:"access_token"`
	TokenType   string  `json:"token_type"`
	ExpiresIn   int64   `json:"expires_in"`
	User        userDTO `json:"user"`
}

type userDTO struct {
	ID                string `json:"id"`
	Email             string `json:"email"`
	PreferredCurrency string `json:"preferred_currency"`
}

func (h *Handlers) Register(c *gin.Context) {
	var body registerReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	body.Email = strings.TrimSpace(strings.ToLower(body.Email))
	if !emailRe.MatchString(body.Email) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid email"})
		return
	}
	if len(body.Password) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password must be at least 8 characters"})
		return
	}
	pc := strings.ToUpper(strings.TrimSpace(body.PreferredCurrency))
	if pc == "" {
		pc = "USD"
	}
	if len(pc) != 3 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "preferred_currency must be 3 letters"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	var id uuid.UUID
	err = h.Pool.QueryRow(c.Request.Context(), `
		INSERT INTO users (email, password_hash, preferred_currency)
		VALUES ($1, $2, $3)
		ON CONFLICT (email) DO NOTHING
		RETURNING id
	`, body.Email, string(hash), pc).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	h.writeToken(c, http.StatusCreated, id, body.Email, pc)
}

func (h *Handlers) Login(c *gin.Context) {
	var body loginReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	body.Email = strings.TrimSpace(strings.ToLower(body.Email))

	var id uuid.UUID
	var hash string
	var pc string
	err := h.Pool.QueryRow(c.Request.Context(), `
		SELECT id, password_hash, preferred_currency FROM users WHERE email = $1
	`, body.Email).Scan(&id, &hash, &pc)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(body.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	h.writeToken(c, http.StatusOK, id, body.Email, pc)
}

func (h *Handlers) writeToken(c *gin.Context, status int, id uuid.UUID, email, pc string) {
	signed, err := token.SignAccessToken(h.JWTSecret, id, h.JWTExpiry)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	c.JSON(status, tokenResp{
		AccessToken: signed,
		TokenType:   "Bearer",
		ExpiresIn:   int64(h.JWTExpiry.Seconds()),
		User: userDTO{
			ID:                id.String(),
			Email:             email,
			PreferredCurrency: pc,
		},
	})
}

func (h *Handlers) Me(c *gin.Context) {
	uid, ok := middleware.UserID(c.Request.Context())
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	var email, pc string
	err := h.Pool.QueryRow(c.Request.Context(), `
		SELECT email, preferred_currency FROM users WHERE id = $1
	`, uid).Scan(&email, &pc)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.JSON(http.StatusOK, userDTO{
		ID:                uid.String(),
		Email:             email,
		PreferredCurrency: pc,
	})
}
