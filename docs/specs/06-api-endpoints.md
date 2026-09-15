# MatLogg – API Spesifikasjon

## 6.1 API Arkitektur

**Base URL:** `https://api.matlogg.app/v1`  
**Protocol:** REST + JSON  
**Auth:** Bearer JWT (Authorization header)  
**Versioning:** URL-based (`/v1`, `/v2`, etc.)

---

## 6.2 Authentication Endpoints

### **POST /auth/register**

Registrer ny bruker

**Request:**
```json
{
  "email": "nithu@example.com",
  "password": "SecurePassword123!", // only for email provider
  "first_name": "Nithu",
  "last_name": "Doe",
  "auth_provider": "email" // or "apple", "google"
}
```

**Response (201 Created):**
```json
{
  "user_id": "user-uuid-here",
  "email": "nithu@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 86400,
  "refresh_token": "refresh-token-here",
  "message": "Registreringen vellykket"
}
```

**Error (400):**
```json
{
  "error": "email_taken",
  "message": "E-posten er allerede registrert"
}
```

---

### **POST /auth/login**

Innlogging (email/passord)

**Request:**
```json
{
  "email": "nithu@example.com",
  "password": "SecurePassword123!"
}
```

**Response (200 OK):**
```json
{
  "user_id": "user-uuid-here",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 86400,
  "refresh_token": "refresh-token-here"
}
```

**Attribusjon (påkrevd):**
- Matvaretabellen og Open Food Facts må krediteres iht. lisensvilkår.
- `nutrition_source` og `image_source` brukes i UI for å vise kilde i info‑sheet.

**Error (401):**
```json
{
  "error": "invalid_credentials",
  "message": "E-post eller passord er feil"
}
```

---

### **POST /auth/oauth**

OAuth-innlogging (Apple/Google)

**Request:**
```json
{
  "auth_provider": "apple", // or "google"
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "first_name": "Nithu",
  "last_name": "Doe"
}
```

**Response (200/201):**
```json
{
  "user_id": "user-uuid-here",
  "is_new_user": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 86400,
  "refresh_token": "refresh-token-here"
}
```

---

### **POST /auth/refresh**

Refresh access token

**Request:**
```json
{
  "refresh_token": "refresh-token-here"
}
```

**Response (200):**
```json
{
  "token": "new-jwt-token",
  "expires_in": 86400
}
```

---

## 6.3 Product Endpoints

### **GET /products/barcode/{ean}**

Oppslag av produkt via EAN-strekkode

**Parameters:**
```
GET /products/barcode/5900423000890
```

**Response (200 OK):**
```json
{
  "product_id": "product-uuid",
  "name": "Brød, Rostaboost",
  "brand": "Kneippehuset",
  "category": "Bakeri",
  "barcode_ean": "5900423000890",
  "source": "matvaretabellen",
  "nutrition_source": "matvaretabellen",
  "image_source": "openfoodfacts",
  "verification_status": "verified",
  "confidence_score": 0.92,
  "calories_per_100g": 240,
  "protein_g_per_100g": 8.0,
  "carbs_g_per_100g": 45.0,
  "fat_g_per_100g": 3.0,
  "sugar_g_per_100g": 2.5,
  "fiber_g_per_100g": 3.2,
  "sodium_mg_per_100g": 450,
  "image_url": "https://cdn.matlogg.app/products/product-uuid.jpg",
  "standard_portions": [
    { "name": "Skive", "weight_g": 35 },
    { "name": "Bolle", "weight_g": 65 }
  ],
  "is_verified": true,
  "created_at": "2025-01-01T00:00:00Z",
  "updated_at": "2025-01-21T10:30:00Z"
}
```

**Response (404 Not Found):**
```json
{
  "error": "product_not_found",
  "message": "Strekkoden finnes ikke i databasen"
}
```

---

### **GET /products/search**

Søk etter produkt (navn-basert)

**Parameters:**
```
GET /products/search?q=brød&limit=10
```

**Response (200):**
```json
{
  "results": [
    {
      "product_id": "uuid1",
      "name": "Brød, Rostaboost",
      "brand": "Kneippehuset",
      "calories_per_100g": 240,
      "barcode_ean": "5900423000890"
    },
    {
      "product_id": "uuid2",
      "name": "Brød, Grovt",
      "brand": "Kneippehuset",
      "calories_per_100g": 220,
      "barcode_ean": "5900423000891"
    }
  ],
  "total": 2
}
```

---

### **POST /products**

Opprett nytt produkt (bruker-generert)

**Request (authenticated):**
```json
{
  "name": "Kjøttboller, IKEA",
  "brand": "IKEA",
  "category": "Kjøtt",
  "barcode_ean": "4002269123456",
  "calories_per_100g": 240,
  "protein_g_per_100g": 12.0,
  "carbs_g_per_100g": 8.0,
  "fat_g_per_100g": 15.0,
  "sugar_g_per_100g": 1.5,
  "fiber_g_per_100g": 0.0,
  "sodium_mg_per_100g": 600,
  "image_url": "https://example.com/image.jpg"
}
```

**Response (201 Created):**
```json
{
  "product_id": "product-uuid",
  "name": "Kjøttboller, IKEA",
  "is_verified": false,
  "moderation_status": "pending",
  "created_at": "2025-01-21T12:00:00Z",
  "message": "Produktet er opprettet og venter på godkjenning"
}
```

---

### **PATCH /products/{product_id}**

Oppdater produkt (steg 2 detaljer)

**Request (authenticated):**
```json
{
  "sugar_g_per_100g": 1.5,
  "fiber_g_per_100g": 0.5,
  "standard_portions": [
    { "name": "Porsjon", "weight_g": 100 }
  ],
  "image_url": "https://cdn.matlogg.app/updated.jpg"
}
```

**Response (200):**
```json
{
  "product_id": "product-uuid",
  "updated_fields": ["sugar_g_per_100g", "standard_portions"],
  "message": "Produktet er oppdatert"
}
```

---

## 6.4 Logging Endpoints

### **POST /logs**

Opprett logg-innslag

**Request (authenticated):**
```json
{
  "product_id": "product-uuid",
  "amount_g": 150.5,
  "meal_type": "lunch",
  "logged_date": "2025-01-21",
  "logged_time": "2025-01-21T12:30:00Z"
}
```

**Response (201 Created):**
```json
{
  "log_id": "log-uuid",
  "product_id": "product-uuid",
  "amount_g": 150.5,
  "calories": 360,
  "protein_g": 12.0,
  "carbs_g": 67.5,
  "fat_g": 4.5,
  "synced_at": "2025-01-21T12:30:05Z",
  "message": "Logg opprettet"
}
```

---

### **GET /logs**

Hent logger for dag

**Parameters:**
```
GET /logs?date=2025-01-21&meal_type=lunch
```

**Response (200):**
```json
{
  "logs": [
    {
      "log_id": "log-uuid-1",
      "product": {
        "product_id": "product-uuid",
        "name": "Brød, Rostaboost"
      },
      "amount_g": 150,
      "calories": 360,
      "meal_type": "lunch",
      "logged_time": "2025-01-21T12:30:00Z"
    }
  ],
  "daily_totals": {
    "calories": 1250,
    "protein_g": 40,
    "carbs_g": 200,
    "fat_g": 30
  }
}
```

---

### **DELETE /logs/{log_id}**

Slett logg-innslag

**Response (200):**
```json
{
  "log_id": "log-uuid",
  "message": "Logg slettet"
}
```

---

## 6.5 Goals Endpoints

### **POST /goals**

Sett kalorimål og makromål

**Request (authenticated):**
```json
{
  "goal_type": "weight_loss",
  "daily_calories": 2000,
  "protein_target_g": 150,
  "carbs_target_g": 250,
  "fat_target_g": 65
}
```

**Response (201):**
```json
{
  "goal_id": "goal-uuid",
  "daily_calories": 2000,
  "protein_target_g": 150,
  "carbs_target_g": 250,
  "fat_target_g": 65,
  "created_at": "2025-01-21T00:00:00Z"
}
```

---

### **GET /goals**

Hent gjeldende mål

**Response (200):**
```json
{
  "goal_id": "goal-uuid",
  "goal_type": "weight_loss",
  "daily_calories": 2000,
  "protein_target_g": 150,
  "carbs_target_g": 250,
  "fat_target_g": 65,
  "created_date": "2025-01-21"
}
```

---

### **PATCH /goals/{goal_id}**

Oppdater mål

**Request:**
```json
{
  "daily_calories": 2200
}
```

**Response (200):**
```json
{
  "goal_id": "goal-uuid",
  "daily_calories": 2200,
  "message": "Mål oppdatert"
}
```

---

## 6.6 Favorites Endpoints

### **POST /favorites**

Legg til favoritt

**Request (authenticated):**
```json
{
  "product_id": "product-uuid"
}
```

**Response (201):**
```json
{
  "favorite_id": "favorite-uuid",
  "product_id": "product-uuid",
  "created_at": "2025-01-21T12:00:00Z"
}
```

---

### **DELETE /favorites/{favorite_id}**

Fjern fra favoritter

**Response (200):**
```json
{
  "message": "Fjernet fra favoritter"
}
```

---

### **GET /favorites**

Hent alle favoritter

**Response (200):**
```json
{
  "favorites": [
    {
      "favorite_id": "fav-uuid-1",
      "product": {
        "product_id": "product-uuid",
        "name": "Brød, Rostaboost",
        "calories_per_100g": 240
      }
    }
  ]
}
```

---

## 6.7 Sync Endpoint

### **POST /sync**

Synkroniser offline-events til backend

**Request (authenticated):**
```json
{
  "device_id": "device-identifier",
  "device_timestamp": "2025-01-21T12:45:00Z",
  "events": [
    {
      "event_id": "event-uuid-1",
      "event_type": "log_create",
      "entity_id": "log-uuid",
      "timestamp": "2025-01-21T12:30:00Z",
      "payload": {
        "product_id": "product-uuid",
        "amount_g": 150,
        "meal_type": "lunch",
        "logged_date": "2025-01-21"
      }
    },
    {
      "event_id": "event-uuid-2",
      "event_type": "favorite_add",
      "entity_id": "favorite-uuid",
      "timestamp": "2025-01-21T12:31:00Z",
      "payload": {
        "product_id": "product-uuid-2"
      }
    }
  ]
}
```

**Response (200):**
```json
{
  "success": true,
  "synced_events": [
    {
      "event_id": "event-uuid-1",
      "status": "ok",
      "server_id": "log-uuid"
    },
    {
      "event_id": "event-uuid-2",
      "status": "ok",
      "server_id": "favorite-uuid"
    }
  ],
  "errors": [],
  "server_state": {
    "user_calories_today": 1250,
    "user_goals": {
      "daily_calories": 2000
    }
  }
}
```

**Error Handling (400):**
```json
{
  "success": false,
  "synced_events": [],
  "errors": [
    {
      "event_id": "event-uuid-3",
      "status": "error",
      "reason": "product_not_found",
      "message": "Produktet finnes ikke"
    }
  ]
}
```

---

## 6.8 Shares Endpoints

### **POST /shares**

Opprett delingslink for produkt

**Request (authenticated):**
```json
{
  "product_id": "product-uuid",
  "ttl_days": 30
}
```

**Response (201):**
```json
{
  "share_id": "share-uuid",
  "share_token": "7k9mL2pQ4xR8vW1dE6jN3cF5hB0tY9sZ",
  "share_link": "https://matlogg.app/share/7k9mL2pQ4xR8vW1dE6jN3cF5hB0tY9sZ",
  "deep_link": "matlogg://share/7k9mL2pQ4xR8vW1dE6jN3cF5hB0tY9sZ",
  "created_at": "2025-01-21T12:00:00Z",
  "expires_at": "2025-02-20T12:00:00Z"
}
```

---

### **GET /shares/{share_token}**

Hent produkt via delingslink

**Response (200):**
```json
{
  "share_id": "share-uuid",
  "product": {
    "product_id": "product-uuid",
    "name": "Brød, Rostaboost",
    "brand": "Kneippehuset",
    "calories_per_100g": 240,
    "protein_g_per_100g": 8.0,
    "carbs_g_per_100g": 45.0,
    "fat_g_per_100g": 3.0,
    "image_url": "https://cdn.matlogg.app/products/product-uuid.jpg"
  },
  "sharer_name": "Nithu",
  "created_at": "2025-01-21T12:00:00Z",
  "expires_at": "2025-02-20T12:00:00Z"
}
```

**Response (410 Gone - Expired/Revoked):**
```json
{
  "error": "share_expired_or_revoked",
  "message": "Delingslinken er utløpt eller kansellert"
}
```

---

### **DELETE /shares/{share_id}**

Tilbakekall delingslink

**Request (authenticated):**
```
DELETE /shares/share-uuid
```

**Response (200):**
```json
{
  "share_id": "share-uuid",
  "message": "Delingslinken er tilbakekalt"
}
```

---

## 6.9 User Endpoints

### **GET /user**

Hent brukerinfo

**Response (200):**
```json
{
  "user_id": "user-uuid",
  "email": "nithu@example.com",
  "first_name": "Nithu",
  "last_name": "Doe",
  "auth_provider": "email",
  "created_at": "2025-01-01T00:00:00Z"
}
```

---

### **PATCH /user**

Oppdater brukerprofil

**Request:**
```json
{
  "first_name": "Nithu",
  "last_name": "Updated"
}
```

**Response (200):**
```json
{
  "user_id": "user-uuid",
  "first_name": "Nithu",
  "last_name": "Updated",
  "message": "Profil oppdatert"
}
```

---

### **POST /user/change-password**

Endre passord

**Request:**
```json
{
  "old_password": "OldPassword123!",
  "new_password": "NewPassword456!"
}
```

**Response (200):**
```json
{
  "message": "Passord endret vellykket"
}
```

---

### **DELETE /user**

Slett brukerkonto

**Request:**
```
DELETE /user
```

**Response (200):**
```json
{
  "message": "Kontoen er markert for sletting. Den vil bli permanent slettet etter 30 dager."
}
```

---

## 6.10 Error Codes & Status

| Status | Code | Meaning |
|--------|------|---------|
| 200 | OK | Suksess |
| 201 | Created | Ressurs opprettet |
| 204 | No Content | Suksess, no body |
| 400 | Bad Request | Ugyldig input |
| 401 | Unauthorized | Mangler/ugyldig token |
| 403 | Forbidden | Bruker har ikke tilgang |
| 404 | Not Found | Ressurs finnes ikke |
| 410 | Gone | Share expired/revoked |
| 422 | Unprocessable | Validering feilet |
| 429 | Too Many Requests | Rate limit overskrevet |
| 500 | Server Error | Intern feil |
| 503 | Unavailable | Backend nede |

---

## 6.11 Rate Limiting

```
Per bruker per time:
• /products/barcode/* : 300 requests
• /products/search : 100 requests
• /sync : 60 requests
• /logs : 500 requests

Response header:
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 298
X-RateLimit-Reset: 1705870800
```

---

## 6.12 CORS & Security

```
CORS:
• Allowed Origins: https://matlogg.app, https://*.matlogg.app
• Allowed Methods: GET, POST, PATCH, DELETE, OPTIONS
• Allowed Headers: Authorization, Content-Type, X-Device-ID
• Credentials: true

SSL/TLS:
• HTTPS only
• Minimum TLS 1.2
• HSTS enabled (max-age=31536000)

CSRF Protection:
• Not required for API (JWT-based, no cookie auth)
• Mobile app: X-Device-ID header validation

API Keys:
• Not used in MVP (JWT only)
• Rate limiting per user_id from token
```
