package token

import (
	"errors"
	"time"

	jwtlib "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Claims struct {
	UserID uuid.UUID `json:"sub"`
	jwtlib.RegisteredClaims
}

func SignAccessToken(secret []byte, userID uuid.UUID, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwtlib.RegisteredClaims{
			ExpiresAt: jwtlib.NewNumericDate(now.Add(ttl)),
			IssuedAt:  jwtlib.NewNumericDate(now),
			Subject:   userID.String(),
		},
	}
	t := jwtlib.NewWithClaims(jwtlib.SigningMethodHS256, &claims)
	return t.SignedString(secret)
}

func ParseAccessToken(secret []byte, tokenString string) (uuid.UUID, error) {
	t, err := jwtlib.ParseWithClaims(tokenString, &Claims{}, func(t *jwtlib.Token) (any, error) {
		if _, ok := t.Method.(*jwtlib.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return secret, nil
	})
	if err != nil {
		return uuid.Nil, err
	}
	claims, ok := t.Claims.(*Claims)
	if !ok || !t.Valid {
		return uuid.Nil, errors.New("invalid token")
	}
	return claims.UserID, nil
}
