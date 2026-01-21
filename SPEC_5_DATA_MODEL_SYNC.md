# MatLogg – Datamodell & Synkronisering

## 5.1 Core Entities (Local SQLite)

### **Users**

```swift
struct User {
    id: UUID
    email: String (unique, indexed)
    auth_provider: String ("apple" | "google" | "email")
    auth_provider_id: String? (for OAuth)
    password_hash: String? (only for email)
    first_name: String
    last_name: String
    created_at: DateTime
    updated_at: DateTime
    last_login: DateTime?
    
    // Local sync markers
    is_synced: Bool = true
    sync_token: String? (for optimistic concurrency)
}
```

### **Goals**

```swift
struct Goal {
    id: UUID
    user_id: UUID (foreign key, indexed)
    goal_type: String ("weight_loss" | "maintain" | "gain")
    daily_calories: Int (1000–5000)
    protein_target_g: Float
    carbs_target_g: Float
    fat_target_g: Float?
    created_date: Date (date-only, no time)
    updated_at: DateTime
    
    // Local flags
    is_synced: Bool = true
    device_id: String (for conflict resolution)
}
```

### **Products**

```swift
struct Product {
    id: UUID
    name: String (indexed)
    brand: String?
    category: String? ("Bakeri", "Kjøtt", "Meieri", "Frukt", etc.)
    barcode_ean: String (indexed, unique per source)
    source: String ("matvaretabellen" | "user" | "shared")
    
    // Nutrition per 100g (always)
    calories_per_100g: Int
    protein_g_per_100g: Float
    carbs_g_per_100g: Float
    fat_g_per_100g: Float
    sugar_g_per_100g: Float?
    fiber_g_per_100g: Float?
    sodium_mg_per_100g: Int?
    
    // Metadata
    image_url: String?
    image_local_path: String? (cached)
    standard_portions: [Portion]? (JSON array or separate table)
    
    // For unverified products
    is_verified: Bool = false
    creator_user_id: UUID?
    moderation_status: String? ("pending" | "approved" | "rejected")
    created_at: DateTime
    updated_at: DateTime
    
    // Local sync
    is_synced: Bool = true
}
```

### **Portions (nested in Product or separate table)**

```swift
struct Portion {
    id: UUID
    product_id: UUID
    name: String ("Skive", "Bolle", "Glass", etc.)
    weight_g: Float
}
```

### **Logs (Loggings)**

```swift
struct Log {
    id: UUID
    user_id: UUID (indexed)
    product_id: UUID (indexed, foreign key)
    meal_type: String ("breakfast" | "lunch" | "dinner" | "snack", indexed)
    amount_g: Float (exact, no rounding)
    logged_date: Date (date-only)
    logged_time: DateTime (full timestamp)
    
    // Calculated (de-normalized for fast queries)
    calories: Int (amount_g * product.calories_per_100g / 100)
    protein_g: Float
    carbs_g: Float
    fat_g: Float
    
    // Metadata
    created_at: DateTime
    updated_at: DateTime
    synced_at: DateTime? (when sent to backend)
    
    // Local flags
    is_synced: Bool = false (set to true after backend ACK)
    is_deleted: Bool = false (soft-delete for sync)
    device_id: String
    
    // Indexes
    INDEX (user_id, logged_date) (for day-view queries)
    INDEX (user_id, meal_type, logged_date)
}
```

### **Favorites**

```swift
struct Favorite {
    id: UUID
    user_id: UUID (indexed)
    product_id: UUID (indexed, foreign key)
    created_at: DateTime
    is_synced: Bool = false
}
```

### **ScanHistory**

```swift
struct ScanHistory {
    id: UUID
    user_id: UUID (indexed)
    product_id: UUID (indexed)
    scanned_at: DateTime (indexed, descending)
    amount_last_used_g: Float? (optional, for UX)
}
```

### **Shares (Share Links)**

```swift
struct Share {
    id: UUID
    product_id: UUID (indexed)
    sharer_user_id: UUID (indexed)
    share_token: String (unique, indexed, 32-char random)
    created_at: DateTime
    expires_at: DateTime (default: now + 30 days)
    revoked_at: DateTime?
    clicks: Int = 0 (optional tracking)
    is_synced: Bool = false
}
```

### **Events (Local Queue)**

```swift
struct SyncEvent {
    id: UUID
    user_id: UUID
    event_type: String (
        "log_create",
        "log_delete",
        "product_create",
        "favorite_add",
        "favorite_remove",
        "goal_update",
        "share_create"
    )
    entity_id: UUID (log_id, product_id, etc.)
    payload: String (JSON)
    created_at: DateTime
    sent_at: DateTime?
    last_error: String?
    retry_count: Int = 0
    is_synced: Bool = false
}
```

---

## 5.2 Database Schema (SQLite)

```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    auth_provider TEXT NOT NULL,
    auth_provider_id TEXT,
    password_hash TEXT,
    first_name TEXT,
    last_name TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_login TEXT,
    is_synced BOOLEAN DEFAULT 1,
    sync_token TEXT
);

CREATE TABLE goals (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    goal_type TEXT NOT NULL,
    daily_calories INTEGER NOT NULL,
    protein_target_g REAL,
    carbs_target_g REAL,
    fat_target_g REAL,
    created_date TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_synced BOOLEAN DEFAULT 0,
    device_id TEXT,
    UNIQUE(user_id, created_date)
);

CREATE TABLE products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    brand TEXT,
    category TEXT,
    barcode_ean TEXT UNIQUE,
    source TEXT NOT NULL DEFAULT 'user',
    calories_per_100g INTEGER NOT NULL,
    protein_g_per_100g REAL NOT NULL,
    carbs_g_per_100g REAL NOT NULL,
    fat_g_per_100g REAL NOT NULL,
    sugar_g_per_100g REAL,
    fiber_g_per_100g REAL,
    sodium_mg_per_100g INTEGER,
    image_url TEXT,
    image_local_path TEXT,
    standard_portions TEXT, -- JSON
    is_verified BOOLEAN DEFAULT 0,
    creator_user_id TEXT REFERENCES users(id),
    moderation_status TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    is_synced BOOLEAN DEFAULT 0
);
CREATE INDEX idx_products_barcode ON products(barcode_ean);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_source ON products(source);

CREATE TABLE logs (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    product_id TEXT NOT NULL REFERENCES products(id),
    meal_type TEXT NOT NULL,
    amount_g REAL NOT NULL,
    logged_date TEXT NOT NULL, -- YYYY-MM-DD
    logged_time TEXT NOT NULL, -- ISO8601
    calories INTEGER,
    protein_g REAL,
    carbs_g REAL,
    fat_g REAL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    synced_at TEXT,
    is_synced BOOLEAN DEFAULT 0,
    is_deleted BOOLEAN DEFAULT 0,
    device_id TEXT
);
CREATE INDEX idx_logs_user_date ON logs(user_id, logged_date);
CREATE INDEX idx_logs_user_meal_date ON logs(user_id, meal_type, logged_date);
CREATE INDEX idx_logs_synced ON logs(is_synced);

CREATE TABLE favorites (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    product_id TEXT NOT NULL REFERENCES products(id),
    created_at TEXT NOT NULL,
    is_synced BOOLEAN DEFAULT 0,
    UNIQUE(user_id, product_id)
);
CREATE INDEX idx_favorites_user ON favorites(user_id);

CREATE TABLE scan_history (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    product_id TEXT NOT NULL REFERENCES products(id),
    scanned_at TEXT NOT NULL,
    amount_last_used_g REAL,
    UNIQUE(user_id, product_id)
);
CREATE INDEX idx_scan_history_user_date ON scan_history(user_id, scanned_at DESC);

CREATE TABLE shares (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES products(id),
    sharer_user_id TEXT NOT NULL REFERENCES users(id),
    share_token TEXT UNIQUE NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    clicks INTEGER DEFAULT 0,
    is_synced BOOLEAN DEFAULT 0
);
CREATE INDEX idx_shares_token ON shares(share_token);

CREATE TABLE sync_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    event_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    payload TEXT NOT NULL, -- JSON
    created_at TEXT NOT NULL,
    sent_at TEXT,
    last_error TEXT,
    retry_count INTEGER DEFAULT 0,
    is_synced BOOLEAN DEFAULT 0
);
CREATE INDEX idx_sync_events_user_synced ON sync_events(user_id, is_synced);
```

---

## 5.3 Sync Architecture (Offline-First, Event-Sourcing)

### **Local-First Principle**

1. **Skriving:** Alle operasjoner skriver til lokal SQLite umiddelbar
2. **Queuing:** Operasjoner legges til `sync_events` tabell
3. **Synk:** Background-task sender event-kø til backend
4. **Conflict:** Bakendvaliderer; hvis konflikt, bruker device-timestamp som tiebreaker

### **Sync Event Loop**

```
┌────────────────────────────────────────────────────────────┐
│ 1. USER LOGGING (Local)                                    │
│    • Tapper [Legg til] på produktkort                       │
│    • App.loggProduct(product, amount, meal)                 │
│    └─→ INSERT into logs (is_synced=0)                       │
│    └─→ INSERT into sync_events:                             │
│        { event_type: "log_create", entity_id: log.id, ... } │
│    └─→ UI updates (optimistic)                              │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ 2. BACKGROUND SYNC (Async)                                 │
│    • URLSession backgroundConfiguration                     │
│    • Trigger: App enters foreground, or on timer (>30s idle)│
│    • Query: SELECT * FROM sync_events WHERE is_synced=0    │
│    └─→ Batch events into payload                            │
│    └─→ POST /api/v1/sync                                    │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ 3. BACKEND PROCESSING                                      │
│    • Validate JWT token                                     │
│    • For each event:                                        │
│      - Validate payload                                     │
│      - Persist to PostgreSQL                                │
│      - Check conflicts (timestamp comparison)               │
│    • Return ACK + server-state                              │
└────────────────────────────────────────────────────────────┘
                         ↓
┌────────────────────────────────────────────────────────────┐
│ 4. LOCAL UPDATE (on response)                              │
│    • For each successfully synced event:                    │
│      UPDATE logs SET is_synced=1, synced_at=now            │
│      UPDATE sync_events SET is_synced=1, sent_at=now       │
│    • If error: retry with exponential backoff               │
│    • Display: "✓ Synkronisert 3 hendelser"                  │
└────────────────────────────────────────────────────────────┘
```

### **Sync Payload Format**

```json
{
  "user_id": "user-uuid-here",
  "device_id": "device-identifier",
  "device_timestamp": "2025-01-21T12:34:56Z",
  "events": [
    {
      "event_id": "event-uuid",
      "event_type": "log_create",
      "entity_id": "log-uuid",
      "timestamp": "2025-01-21T12:30:00Z",
      "payload": {
        "product_id": "product-uuid",
        "amount_g": 150.5,
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
        "product_id": "product-uuid"
      }
    }
  ]
}
```

### **Backend Response**

```json
{
  "success": true,
  "synced_events": [
    {
      "event_id": "event-uuid",
      "status": "ok",
      "server_id": "server-generated-id"
    }
  ],
  "errors": [],
  "server_state": {
    "user_calories_today": 1250,
    "user_goals": { "daily_calories": 2000 },
    "last_sync_token": "token-for-next-sync"
  }
}
```

---

## 5.4 Conflict Resolution

### **Scenario: Same log edited on 2 devices**

**Device A** (Offline):
```
12:30 - Log brød (150g)
is_synced=0, device_id="A"
```

**Device B** (Online):
```
12:30 - Log brød (150g) 
is_synced=1, device_id="B", synced_at=12:31
```

**Resolution:**
1. Device A comes online, sends event
2. Backend sees: device_id="A", timestamp=12:30, log.id exists
3. Backend checks: existing log from device_id="B", timestamp=12:30
4. Tiebreaker: **Last write wins** (or server keeps canonical version)
5. Device A receives: "This entry was already synced from another device. Using server version."
6. Local DB updates: amount_g = 150, synced_at = server_time

---

## 5.5 Unverified Product Sync

```
Flow: Bruker skanner ukjent strekkode, oppretter produkt lokalt

1. LOCAL:
   Product record created:
   • is_verified = false
   • creator_user_id = current_user
   • moderation_status = "pending"
   • is_synced = false

2. EVENT QUEUE:
   SyncEvent created:
   • event_type = "product_create"
   • payload = full product data

3. FIRST SYNC:
   • POST /api/v1/sync
   • Backend receives: creates record in moderation_queue
   • Response: product_id assigned (server-side)
   • Local DB: UPDATE product SET id = server_id, is_synced=1

4. BACKEND MODERATION:
   • Admin reviews product
   • Status updated: "approved" or "rejected"
   • Flag: push notification to creator (future feature)

5. NEXT SYNC (pull):
   • App pulls moderation updates
   • Local product updated: moderation_status, is_verified
   • If rejected: warning shown to user
```

---

## 5.6 Share Link Token & Expiry

```
Share Creation:
• Product ID: abc123
• Sharer User: user456
• Token: generate_random(32) → "7k9mL2pQ4xR8vW1dE6jN3cF5hB0tY9sZ"
• Created: 2025-01-21T12:00:00Z
• Expires: 2025-02-20T12:00:00Z (30 days later)

Share Lookup (via deep link):
GET /api/v1/shares/7k9mL2pQ4xR8vW1dE6jN3cF5hB0tY9sZ

Response:
{
  "share_id": "share-uuid",
  "product": { ... },
  "sharer_name": "Nithu",
  "created_at": "2025-01-21T12:00:00Z",
  "expires_at": "2025-02-20T12:00:00Z"
}

If expired or revoked:
HTTP 410 Gone
{ "error": "Share link expired or revoked" }
```

---

## 5.7 Query Examples (SQLite)

### **Day View (Home Logg-liste)**

```sql
SELECT 
  meal_type,
  product.name,
  logs.amount_g,
  logs.calories,
  logs.id
FROM logs
JOIN products ON logs.product_id = products.id
WHERE logs.user_id = ? AND logs.logged_date = DATE('now')
ORDER BY logs.logged_time ASC;
```

### **Daily Totals (Status Ring)**

```sql
SELECT 
  SUM(logs.calories) as total_calories,
  SUM(logs.protein_g) as total_protein,
  SUM(logs.carbs_g) as total_carbs,
  SUM(logs.fat_g) as total_fat
FROM logs
WHERE logs.user_id = ? AND logs.logged_date = DATE('now') AND is_deleted = 0;
```

### **Scan History (Last 15)**

```sql
SELECT 
  products.*,
  scan_history.scanned_at
FROM scan_history
JOIN products ON scan_history.product_id = products.id
WHERE scan_history.user_id = ?
ORDER BY scan_history.scanned_at DESC
LIMIT 15;
```

### **Favorites with Recent Usage**

```sql
SELECT 
  products.*,
  (SELECT MAX(scanned_at) FROM scan_history 
   WHERE product_id = products.id AND user_id = ?) as last_used
FROM favorites
JOIN products ON favorites.product_id = products.id
WHERE favorites.user_id = ?
ORDER BY last_used DESC NULLS LAST;
```

---

## 5.8 Caching Strategy

### **Local Image Caching**

```
Documents/MatLogg/cache/products/

Structure:
cache/products/{product_id}.jpg
cache/products/{product_id}_thumb.jpg

Strategy:
• Download on first view (if image_url provided)
• Store locally with TTL (60 days)
• Fallback: placeholder icon

Size limit: 50 MB total cache
Eviction: LRU (least recently used)
```

### **Product Database Caching (Matvaretabellen)**

```
Seeded on first app launch:
• ~500 common Norwegian products (CSV import)
• Stored in SQLite with source="matvaretabellen"
• Never deleted, always available offline

Updates:
• Periodic fetch from Matvaretabellen API (monthly)
• Merge with local DB (update existing, insert new)
```

---

## 5.9 Data Retention & Privacy

```
User Data Deletion (GDPR):
1. User initiates: Settings → [Slett konto]
2. Local:
   • SQLite wipe (all tables)
   • Keychain clear (auth token)
   • Cache clear
3. Backend (async job):
   • Mark user as deleted (soft-delete initially)
   • After 30 days: permanent deletion (hard-delete)
   • Share links revoked
   • Logs anonymized

Log Retention:
• Local: indefinite (or user-configurable)
• Backend: 1 year default (user can request earlier deletion)

Sync Event Retention:
• Local: deleted after successful sync (after 1 month if never synced)
• Backend: none (processed and discarded)
```

