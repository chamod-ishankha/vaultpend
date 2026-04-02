package finance

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"vaultspend/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Handlers struct {
	Pool *pgxpool.Pool
}

type categoryDTO struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	IconKey   *string   `json:"icon_key,omitempty"`
	Color     *string   `json:"color,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type expenseDTO struct {
	ID          string    `json:"id"`
	CategoryID  *string   `json:"category_id,omitempty"`
	Amount      float64   `json:"amount"`
	Currency    string    `json:"currency"`
	OccurredAt  time.Time `json:"occurred_at"`
	Note        *string   `json:"note,omitempty"`
	IsRecurring bool      `json:"is_recurring"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type subscriptionDTO struct {
	ID              string     `json:"id"`
	Name            string     `json:"name"`
	Amount          float64    `json:"amount"`
	Currency        string     `json:"currency"`
	Cycle           string     `json:"cycle"`
	NextBillingDate time.Time  `json:"next_billing_date"`
	IsTrial         bool       `json:"is_trial"`
	TrialEndsAt     *time.Time `json:"trial_ends_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type createCategoryReq struct {
	Name    string  `json:"name" binding:"required"`
	IconKey *string `json:"icon_key"`
	Color   *string `json:"color"`
}

type updateCategoryReq struct {
	Name    *string `json:"name"`
	IconKey *string `json:"icon_key"`
	Color   *string `json:"color"`
}

type createExpenseReq struct {
	CategoryID  *string   `json:"category_id"`
	Amount      float64   `json:"amount" binding:"required"`
	Currency    string    `json:"currency" binding:"required"`
	OccurredAt  time.Time `json:"occurred_at" binding:"required"`
	Note        *string   `json:"note"`
	IsRecurring bool      `json:"is_recurring"`
}

type updateExpenseReq struct {
	CategoryID  *string    `json:"category_id"`
	Amount      *float64   `json:"amount"`
	Currency    *string    `json:"currency"`
	OccurredAt  *time.Time `json:"occurred_at"`
	Note        *string    `json:"note"`
	IsRecurring *bool      `json:"is_recurring"`
}

type createSubscriptionReq struct {
	Name            string     `json:"name" binding:"required"`
	Amount          float64    `json:"amount" binding:"required"`
	Currency        string     `json:"currency" binding:"required"`
	Cycle           string     `json:"cycle" binding:"required"`
	NextBillingDate time.Time  `json:"next_billing_date" binding:"required"`
	IsTrial         bool       `json:"is_trial"`
	TrialEndsAt     *time.Time `json:"trial_ends_at"`
}

type updateSubscriptionReq struct {
	Name            *string    `json:"name"`
	Amount          *float64   `json:"amount"`
	Currency        *string    `json:"currency"`
	Cycle           *string    `json:"cycle"`
	NextBillingDate *time.Time `json:"next_billing_date"`
	IsTrial         *bool      `json:"is_trial"`
	TrialEndsAt     *time.Time `json:"trial_ends_at"`
}

func mustUserID(c *gin.Context) (uuid.UUID, bool) {
	uid, ok := middleware.UserID(c.Request.Context())
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return uuid.Nil, false
	}
	return uid, true
}

func parseIDParam(c *gin.Context, key string) (uuid.UUID, bool) {
	raw := strings.TrimSpace(c.Param(key))
	id, err := uuid.Parse(raw)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return uuid.Nil, false
	}
	return id, true
}

func normalizeCurrency(input string) (string, bool) {
	currency := strings.ToUpper(strings.TrimSpace(input))
	return currency, len(currency) == 3
}

func normalizeCycle(input string) (string, bool) {
	cycle := strings.TrimSpace(strings.ToLower(input))
	switch cycle {
	case "monthly", "annual", "custom":
		return cycle, true
	default:
		return "", false
	}
}

func (h *Handlers) ListCategories(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	rows, err := h.Pool.Query(c.Request.Context(), `
		SELECT id, name, icon_key, color, created_at, updated_at
		FROM categories
		WHERE user_id = $1
		ORDER BY name ASC
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	out := make([]categoryDTO, 0)
	for rows.Next() {
		var item categoryDTO
		var id uuid.UUID
		if err := rows.Scan(&id, &item.Name, &item.IconKey, &item.Color, &item.CreatedAt, &item.UpdatedAt); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		item.ID = id.String()
		out = append(out, item)
	}
	if rows.Err() != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"items": out})
}

func (h *Handlers) CreateCategory(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	var body createCategoryReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	body.Name = strings.TrimSpace(body.Name)
	if body.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name is required"})
		return
	}

	var item categoryDTO
	var id uuid.UUID
	err := h.Pool.QueryRow(c.Request.Context(), `
		INSERT INTO categories (user_id, name, icon_key, color)
		VALUES ($1, $2, $3, $4)
		RETURNING id, name, icon_key, color, created_at, updated_at
	`, uid, body.Name, body.IconKey, body.Color).Scan(
		&id, &item.Name, &item.IconKey, &item.Color, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			c.JSON(http.StatusConflict, gin.H{"error": "category name already exists"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	item.ID = id.String()
	c.JSON(http.StatusCreated, item)
}

func (h *Handlers) UpdateCategory(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}
	id, ok := parseIDParam(c, "id")
	if !ok {
		return
	}

	var body updateCategoryReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}

	var oldName string
	var oldIconKey *string
	var oldColor *string
	err := h.Pool.QueryRow(c.Request.Context(), `
		SELECT name, icon_key, color
		FROM categories
		WHERE id = $1 AND user_id = $2
	`, id, uid).Scan(&oldName, &oldIconKey, &oldColor)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	name := oldName
	if body.Name != nil {
		trimmed := strings.TrimSpace(*body.Name)
		if trimmed == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "name cannot be empty"})
			return
		}
		name = trimmed
	}

	iconKey := oldIconKey
	if body.IconKey != nil {
		iconKey = body.IconKey
	}

	color := oldColor
	if body.Color != nil {
		color = body.Color
	}

	var item categoryDTO
	err = h.Pool.QueryRow(c.Request.Context(), `
		UPDATE categories
		SET name = $1,
		    icon_key = $2,
		    color = $3,
		    updated_at = now()
		WHERE id = $4 AND user_id = $5
		RETURNING id, name, icon_key, color, created_at, updated_at
	`, name, iconKey, color, id, uid).Scan(
		&id, &item.Name, &item.IconKey, &item.Color, &item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			c.JSON(http.StatusConflict, gin.H{"error": "category name already exists"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	item.ID = id.String()
	c.JSON(http.StatusOK, item)
}

func (h *Handlers) DeleteCategory(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}
	id, ok := parseIDParam(c, "id")
	if !ok {
		return
	}

	cmd, err := h.Pool.Exec(c.Request.Context(), `
		DELETE FROM categories
		WHERE id = $1 AND user_id = $2
	`, id, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handlers) ListExpenses(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	rows, err := h.Pool.Query(c.Request.Context(), `
		SELECT id, category_id, amount::float8, currency, occurred_at, note, is_recurring, created_at, updated_at
		FROM transactions
		WHERE user_id = $1
		ORDER BY occurred_at DESC
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	out := make([]expenseDTO, 0)
	for rows.Next() {
		var item expenseDTO
		var id uuid.UUID
		var categoryID *uuid.UUID
		if err := rows.Scan(
			&id,
			&categoryID,
			&item.Amount,
			&item.Currency,
			&item.OccurredAt,
			&item.Note,
			&item.IsRecurring,
			&item.CreatedAt,
			&item.UpdatedAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		item.ID = id.String()
		if categoryID != nil {
			tmp := categoryID.String()
			item.CategoryID = &tmp
		}
		out = append(out, item)
	}
	if rows.Err() != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"items": out})
}

func (h *Handlers) CreateExpense(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	var body createExpenseReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	if body.Amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be > 0"})
		return
	}
	currency, ok := normalizeCurrency(body.Currency)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "currency must be 3 letters"})
		return
	}

	var categoryID *uuid.UUID
	if body.CategoryID != nil && strings.TrimSpace(*body.CategoryID) != "" {
		parsed, err := uuid.Parse(strings.TrimSpace(*body.CategoryID))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid category_id"})
			return
		}
		var exists bool
		if err := h.Pool.QueryRow(c.Request.Context(), `
			SELECT EXISTS(
				SELECT 1 FROM categories WHERE id = $1 AND user_id = $2
			)
		`, parsed, uid).Scan(&exists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		if !exists {
			c.JSON(http.StatusBadRequest, gin.H{"error": "category does not exist"})
			return
		}
		categoryID = &parsed
	}

	var item expenseDTO
	var id uuid.UUID
	var outCategoryID *uuid.UUID
	err := h.Pool.QueryRow(c.Request.Context(), `
		INSERT INTO transactions (
			user_id, category_id, amount, currency, occurred_at, note, is_recurring
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, category_id, amount::float8, currency, occurred_at, note, is_recurring, created_at, updated_at
	`, uid, categoryID, body.Amount, currency, body.OccurredAt, body.Note, body.IsRecurring).Scan(
		&id,
		&outCategoryID,
		&item.Amount,
		&item.Currency,
		&item.OccurredAt,
		&item.Note,
		&item.IsRecurring,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	item.ID = id.String()
	if outCategoryID != nil {
		tmp := outCategoryID.String()
		item.CategoryID = &tmp
	}
	c.JSON(http.StatusCreated, item)
}

func (h *Handlers) UpdateExpense(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}
	id, ok := parseIDParam(c, "id")
	if !ok {
		return
	}

	var body updateExpenseReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}

	var currentAmount float64
	var currentCurrency string
	var currentOccurredAt time.Time
	var currentNote *string
	var currentRecurring bool
	var currentCategoryID *uuid.UUID
	err := h.Pool.QueryRow(c.Request.Context(), `
		SELECT category_id, amount::float8, currency, occurred_at, note, is_recurring
		FROM transactions
		WHERE id = $1 AND user_id = $2
	`, id, uid).Scan(
		&currentCategoryID,
		&currentAmount,
		&currentCurrency,
		&currentOccurredAt,
		&currentNote,
		&currentRecurring,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	amount := currentAmount
	if body.Amount != nil {
		if *body.Amount <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be > 0"})
			return
		}
		amount = *body.Amount
	}

	currency := currentCurrency
	if body.Currency != nil {
		norm, ok := normalizeCurrency(*body.Currency)
		if !ok {
			c.JSON(http.StatusBadRequest, gin.H{"error": "currency must be 3 letters"})
			return
		}
		currency = norm
	}

	occurredAt := currentOccurredAt
	if body.OccurredAt != nil {
		occurredAt = *body.OccurredAt
	}

	note := currentNote
	if body.Note != nil {
		note = body.Note
	}

	recurring := currentRecurring
	if body.IsRecurring != nil {
		recurring = *body.IsRecurring
	}

	categoryID := currentCategoryID
	if body.CategoryID != nil {
		trimmed := strings.TrimSpace(*body.CategoryID)
		if trimmed == "" {
			categoryID = nil
		} else {
			parsed, err := uuid.Parse(trimmed)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid category_id"})
				return
			}
			var exists bool
			if err := h.Pool.QueryRow(c.Request.Context(), `
				SELECT EXISTS(
					SELECT 1 FROM categories WHERE id = $1 AND user_id = $2
				)
			`, parsed, uid).Scan(&exists); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
				return
			}
			if !exists {
				c.JSON(http.StatusBadRequest, gin.H{"error": "category does not exist"})
				return
			}
			categoryID = &parsed
		}
	}

	var item expenseDTO
	var outCategoryID *uuid.UUID
	err = h.Pool.QueryRow(c.Request.Context(), `
		UPDATE transactions
		SET category_id = $1,
			amount = $2,
			currency = $3,
			occurred_at = $4,
			note = $5,
			is_recurring = $6,
			updated_at = now()
		WHERE id = $7 AND user_id = $8
		RETURNING id, category_id, amount::float8, currency, occurred_at, note, is_recurring, created_at, updated_at
	`, categoryID, amount, currency, occurredAt, note, recurring, id, uid).Scan(
		&id,
		&outCategoryID,
		&item.Amount,
		&item.Currency,
		&item.OccurredAt,
		&item.Note,
		&item.IsRecurring,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	item.ID = id.String()
	if outCategoryID != nil {
		tmp := outCategoryID.String()
		item.CategoryID = &tmp
	}
	c.JSON(http.StatusOK, item)
}

func (h *Handlers) DeleteExpense(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}
	id, ok := parseIDParam(c, "id")
	if !ok {
		return
	}

	cmd, err := h.Pool.Exec(c.Request.Context(), `
		DELETE FROM transactions
		WHERE id = $1 AND user_id = $2
	`, id, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handlers) ListSubscriptions(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	rows, err := h.Pool.Query(c.Request.Context(), `
		SELECT id, name, amount::float8, currency, cycle, next_billing_date,
		       is_trial, trial_ends_at, created_at, updated_at
		FROM subscriptions
		WHERE user_id = $1
		ORDER BY next_billing_date ASC, name ASC
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	out := make([]subscriptionDTO, 0)
	for rows.Next() {
		var item subscriptionDTO
		var id uuid.UUID
		if err := rows.Scan(
			&id,
			&item.Name,
			&item.Amount,
			&item.Currency,
			&item.Cycle,
			&item.NextBillingDate,
			&item.IsTrial,
			&item.TrialEndsAt,
			&item.CreatedAt,
			&item.UpdatedAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		item.ID = id.String()
		out = append(out, item)
	}
	if rows.Err() != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"items": out})
}

func (h *Handlers) CreateSubscription(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	var body createSubscriptionReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}
	body.Name = strings.TrimSpace(body.Name)
	if body.Name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name is required"})
		return
	}
	if body.Amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be > 0"})
		return
	}
	currency, ok := normalizeCurrency(body.Currency)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "currency must be 3 letters"})
		return
	}
	cycle, ok := normalizeCycle(body.Cycle)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cycle must be monthly, annual, or custom"})
		return
	}

	var item subscriptionDTO
	var id uuid.UUID
	err := h.Pool.QueryRow(c.Request.Context(), `
		INSERT INTO subscriptions (
			user_id, name, amount, currency, cycle, next_billing_date, is_trial, trial_ends_at
		)
		VALUES ($1, $2, $3, $4, $5, $6::date, $7, $8::date)
		RETURNING id, name, amount::float8, currency, cycle, next_billing_date,
			       is_trial, trial_ends_at, created_at, updated_at
	`, uid, body.Name, body.Amount, currency, cycle, body.NextBillingDate, body.IsTrial, body.TrialEndsAt).Scan(
		&id,
		&item.Name,
		&item.Amount,
		&item.Currency,
		&item.Cycle,
		&item.NextBillingDate,
		&item.IsTrial,
		&item.TrialEndsAt,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	item.ID = id.String()
	c.JSON(http.StatusCreated, item)
}

func (h *Handlers) UpdateSubscription(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}
	id, ok := parseIDParam(c, "id")
	if !ok {
		return
	}

	var body updateSubscriptionReq
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}

	var current subscriptionDTO
	err := h.Pool.QueryRow(c.Request.Context(), `
		SELECT name, amount::float8, currency, cycle, next_billing_date,
		       is_trial, trial_ends_at, created_at, updated_at
		FROM subscriptions
		WHERE id = $1 AND user_id = $2
	`, id, uid).Scan(
		&current.Name,
		&current.Amount,
		&current.Currency,
		&current.Cycle,
		&current.NextBillingDate,
		&current.IsTrial,
		&current.TrialEndsAt,
		&current.CreatedAt,
		&current.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	name := current.Name
	if body.Name != nil {
		trimmed := strings.TrimSpace(*body.Name)
		if trimmed == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "name cannot be empty"})
			return
		}
		name = trimmed
	}

	amount := current.Amount
	if body.Amount != nil {
		if *body.Amount <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be > 0"})
			return
		}
		amount = *body.Amount
	}

	currency := current.Currency
	if body.Currency != nil {
		norm, ok := normalizeCurrency(*body.Currency)
		if !ok {
			c.JSON(http.StatusBadRequest, gin.H{"error": "currency must be 3 letters"})
			return
		}
		currency = norm
	}

	cycle := current.Cycle
	if body.Cycle != nil {
		norm, ok := normalizeCycle(*body.Cycle)
		if !ok {
			c.JSON(http.StatusBadRequest, gin.H{"error": "cycle must be monthly, annual, or custom"})
			return
		}
		cycle = norm
	}

	nextBilling := current.NextBillingDate
	if body.NextBillingDate != nil {
		nextBilling = *body.NextBillingDate
	}

	isTrial := current.IsTrial
	if body.IsTrial != nil {
		isTrial = *body.IsTrial
	}

	trialEndsAt := current.TrialEndsAt
	if body.TrialEndsAt != nil {
		trialEndsAt = body.TrialEndsAt
	}
	if !isTrial {
		trialEndsAt = nil
	}

	var item subscriptionDTO
	err = h.Pool.QueryRow(c.Request.Context(), `
		UPDATE subscriptions
		SET name = $1,
			amount = $2,
			currency = $3,
			cycle = $4,
			next_billing_date = $5::date,
			is_trial = $6,
			trial_ends_at = $7::date,
			updated_at = now()
		WHERE id = $8 AND user_id = $9
		RETURNING id, name, amount::float8, currency, cycle, next_billing_date,
			       is_trial, trial_ends_at, created_at, updated_at
	`, name, amount, currency, cycle, nextBilling, isTrial, trialEndsAt, id, uid).Scan(
		&id,
		&item.Name,
		&item.Amount,
		&item.Currency,
		&item.Cycle,
		&item.NextBillingDate,
		&item.IsTrial,
		&item.TrialEndsAt,
		&item.CreatedAt,
		&item.UpdatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	item.ID = id.String()
	c.JSON(http.StatusOK, item)
}

func (h *Handlers) DeleteSubscription(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}
	id, ok := parseIDParam(c, "id")
	if !ok {
		return
	}

	cmd, err := h.Pool.Exec(c.Request.Context(), `
		DELETE FROM subscriptions
		WHERE id = $1 AND user_id = $2
	`, id, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handlers) SyncStatus(c *gin.Context) {
	uid, ok := mustUserID(c)
	if !ok {
		return
	}

	type section struct {
		Count         int64      `json:"count"`
		LastUpdatedAt *time.Time `json:"last_updated_at"`
	}

	readSection := func(table string) (section, error) {
		var s section
		query := `SELECT COUNT(*), MAX(updated_at) FROM ` + table + ` WHERE user_id = $1`
		err := h.Pool.QueryRow(c.Request.Context(), query, uid).Scan(&s.Count, &s.LastUpdatedAt)
		return s, err
	}

	categories, err := readSection("categories")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	expenses, err := readSection("transactions")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	subscriptions, err := readSection("subscriptions")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"categories":    categories,
		"expenses":      expenses,
		"subscriptions": subscriptions,
	})
}
