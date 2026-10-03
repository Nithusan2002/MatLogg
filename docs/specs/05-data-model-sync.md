# MatLogg – Datamodell & Synkronisering

## Implementasjonsstatus (2026-10-01)

Modellskissene nedenfor er historiske/målbilder og er ikke en direkte beskrivelse
av dagens Swift- eller SQLite-skjema. Bruk `MatLogg/App/Models.swift`,
`MatLogg/Services/LocalStore.swift` (skjema v7), `supabase/migrations/` og
`synkkontrakt v1` som tekniske sannhetskilder. Synkkontrakten finnes i
[docs/sync-contract-v1.md](../sync-contract-v1.md).

Den lokale `User`-modellen lagrer ikke passordhash. Supabase Auth eier
kontoautentisering. Produkter bevarer `nutritionBasis` (per 100 g eller 100 ml)
og kilde; eldre data uten grunnlag tolkes som per 100 g. Feltnavn med `Per100g`
er beholdt for kompatibilitet og betyr ikke at væsker konverteres til gram.
Lokale produktbilder lagres som `localImageData`, ikke som `image_local_path`.

## 5.1 Core Entities (historiske modellskisser)

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
    source: String ("matvaretabellen" | "openfoodfacts" | "user" | "shared")
    
    // Historisk skisse: faktisk grunnlag er per 100 g eller 100 ml
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
    
    // Proveniens & verifisering
    nutrition_source: String ("matvaretabellen" | "openfoodfacts" | "user")
    image_source: String ("openfoodfacts" | "user" | "none")
    verification_status: String ("verified" | "unverified" | "suggested_match")
    confidence_score: Float? (0.0–1.0, optional)
    
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
    meal_type: String ("frokost" | "lunsj" | "middag" | "snacks", indexed)
    amount_g: Float (historisk feltnavn; eksakt numerisk mengde)
    amount_unit: String ("g" | "ml", manglende eldre verdi tolkes som "g")
    logged_date: Date (date-only)
    logged_time: DateTime (full timestamp)
    
    // Calculated (de-normalized for fast queries)
    calories: Float (amount * produktets dokumenterte per-100-grunnlag / 100; avrundes bare ved visning)
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

### **SavedMeal (Lagret måltid)**

```swift
struct SavedMeal {
    id: UUID
    owner_user_id: UUID // Kun lokal ruting; sendes ikke i wire-envelope
    name: String
    suggested_meal_type: String?
    items: [SavedMealItem]
    created_at: DateTime
    updated_at: DateTime
}

struct SavedMealItem {
    id: UUID
    product_id: UUID
    product_name: String
    amount_g: Float (historisk feltnavn; numerisk mengde)
    amount_unit: String ("g" | "ml", default "g")
    calories: Float
    protein_g: Float
    carbs_g: Float
    fat_g: Float
    nutrition_source: String
    sort_index: Int
}
```

Malen er et separat aggregat. Den bevarer næringsgrunnlaget brukeren godkjente,
mens bruk av malen oppretter nye ordinære logger. Lokal `saved_meals`-skriving
og `saved_meal.upsert`/`saved_meal.delete` skjer atomisk. Backend normaliserer
elementene og autoriserer aggregatet mot brukeren fra tokenet.

### **Favorites**

```swift
struct Favorite {
    id: UUID
    user_id: UUID (indexed)
    product_id: UUID (indexed, foreign key)
    created_at: DateTime
    status: String // pending, inFlight, acked, deadLetter, quarantined
}
```

`owner_user_id` må matche aktiv autentisert bruker før en hendelse kan velges
for opplasting. Legacy-hendelser uten sikker eier settes i `quarantined`; de
beholdes lokalt, men kan ikke synkroniseres eller retries.

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
    calories REAL,
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

## 5.3 Matching & cache-prinsipper (OFF → Matvaretabellen)

**Viktig:** Matvaretabellen brukes som næringskilde, ikke som GTIN/strekkode‑registry.

**Confidence score (0.0–1.0):**
- + for identisk navn (normalisert), samme kategori/matvaregruppe, merke, nøkkelord
- − for store avvik i energi per 100g, helt ulik kategori

**Terskler:**
- Automatisk kobling er deaktivert i MVP. Navnelikhet alene er ikke nok til å
  erstatte næringsinnhold på et strekkodeprodukt med en generisk råvare.
- `>= 0.60` kan lagres som et internt forslag for senere, eksplisitt
  brukerbekreftelse, men endrer ikke produktets næringsgrunnlag.
- Uten eksplisitt bekreftelse beholdes Open Food Facts-data og kilde.

**Cache / latency:**
- Lokal cache: `ean -> productSnapshot`
- Open Food Facts-treff regnes som ferske i 30 dager. Ferske treff returneres
  lokalt uten nettverkskall.
- Stale‑while‑revalidate: eldre treff returneres umiddelbart og revalideres i
  bakgrunnen. Bare ett oppslag per EAN kan være aktivt samtidig.
- Ved mislykket bakgrunnsoppdatering beholdes siste kjente snapshot og nytt
  forsøk utsettes i 24 timer.
- Produkter med Matvaretabellen som næringskilde følger matchingens separate
  ferskhetsregel og skal ikke nedgraderes til Open Food Facts-næring av
  bakgrunnsoppdateringen.
- Ved OFF‑nedetid: fallback til cache + “prøv igjen”
- Brukeren kan be om oppdaterte data på produktkortet selv om treffet er ferskt.
  Manuelt forsøk kan omgå automatisk retry-pause, men ikke Open Food Facts sin
  ratebegrensning. `Retry-After` gjelder alle strekkodeoppslag i repositoryets
  levetid; uten angitt ventetid brukes 60 sekunder. Automatisk retry-pause og
  ratebegrensning holdes i minnet og nullstilles når app-prosessen avsluttes.
- Oppslag, cache og deduplisering eies av `BarcodeLookupRepository`. ViewModels
  eier skanne-/produktkorttilstand; views videresender brukerhandlinger.
- Katalogskriving skal aldri overskrive en privat produktrad, heller ikke ved
  samme ID. Brukerens private produkt prioriteres ved strekkodeoppslag.
- Oppdatering endrer ikke kalorier, makroer eller enhet i tidligere logger.
  MatLogg lagrer disse verdiene på loggen, uavhengig av katalogproduktet.
- Ved endret måleenhet beholdes produktkortets eksisterende grunnlag til kortet
  åpnes på nytt. Mengden tolkes aldri automatisk som en annen enhet.


---

## 5.3 Sync Architecture (Offline-First, Event-Sourcing)

### **Local-First Principle**

1. **Skriving:** Alle operasjoner skriver til lokal SQLite umiddelbar
2. **Queuing:** Operasjoner legges til `sync_events` tabell
3. **Synk:** Appen sender den aktive brukerens event-kø ved oppstart,
   foreground og registrert nettgjenoppretting; iOS garanterer ikke kjøring i
   bakgrunnen.
4. **Konflikt i v1:** Backend validerer eierskap og dedupliserer `eventId`, men
   løser ikke samtidige redigeringer fra flere enheter. Toveis konfliktløsning
   krever en senere kontrakt med serverrevisjon; device-tid brukes ikke som
   autoritativ tiebreaker.

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
• Thumbnail-komponenten bruker en separat URLCache (8 MB minne / 50 MB disk) og gjenbruker tilgjengelige bilder offline. Cache kan ryddes av systemet.
• TTL på 60 dager og produkt-ID-baserte filer er fortsatt planlagt.
• Fallback: placeholder icon

Size limit: 50 MB total cache
Eviction: LRU (least recently used)
```

### **Product Database Caching (Matvaretabellen)**

```
Bundled with the app:
• Normalized snapshot of 2 118 official Norwegian foods
• Stable identity from source="matvaretabellen" + Matvaretabellen food ID
• Searchable without network; optional missing nutrients remain null

Updates:
• Snapshot is reviewed and regenerated with an app release, normally annually
• Existing logs retain their stored nutrition snapshot
```

---

## 5.9 Data Retention & Privacy

**Statusavklaring 2. oktober 2026:** Blokken nedenfor er et eldre målbilde,
ikke dokumentasjon av dagens adferd. Aktiv lokal lagring er SQLite.
Serverinbox beholdes til purge i undersøkt Supabase-migrasjon; ett års
serverlagring og automatisk kassering av usynkede hendelser er ikke verifisert.
Usynkede hendelser skal ikke kasseres på grunnlag av denne teksten.
Fjerning av eier-ID fra produktbidrag er ikke dokumentert anonymisering.
Se [datakart og kontrollstatus](../privacy-data-inventory.md) før endringer i
sletting, eksport eller lagringstid.

**Lokal eksport 3. oktober 2026:** JSON-eksporten har `export_schema_version: 2`
og beholder eksisterende felt. Tillegg er `owned_products` (med base64-bilder),
`goal_history`, `scan_history`, `profile_preferences`, `product_drafts` og
`catalog_submissions`. Alle tillegg filtreres på profileier; rå katalogcache og
andre profilers data inngår ikke. Mål/produkter/skannhistorikk har ISO 8601-datoer;
utkast og innsendinger beholder lagret JSON-format. Profilpreferanser angir
`encoding` (`json` eller `base64`). Eksportfilen skrives med iOS Complete Data
Protection og fjernes gjennom eksisterende delingsopprydding. Dette er ikke
en endring i synkkontrakten eller en ferdig godkjenning av GDPR-rettighetsflyten.

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

### Lokale bilder ved manuell produktregistrering

`Product.localImageData` er valgfri JPEG-data i produktets lokale JSON-rad.
Bildet tegnes på nytt uten original fotometadata, med lengste side maksimalt
512 piksler, og lagres atomisk sammen med produktet og synkhendelsen.
Feltet er ikke med i `ProductSyncPayload`; ingen bildeopplasting eller
synkkontraktsendring inngår. Eksisterende produkter uten feltet kan fortsatt
leses. Sletting av produktets lokale rad fjerner også bildet.

### Valgfritt lokalt måltidsbilde

`SavedMeal.localImageData` er valgfri JPEG i eksisterende lokal JSON-rad.
Bildet lagres atomisk med malen og slettes med malen/profildata. Eldre rader
uten feltet støttes. Feltet utelates fra `SavedMealSyncPayload`; synkkontrakt v1
og backend er uendret. Se [lagrede måltider](../saved-meals.md) for importgrenser.

## Historisk porsjonsvalg (2026-10-02)

`FoodLog` og `SavedMealItem` har valgfritt `portionSelection` med porsjons-ID,
label, antall, mengde per porsjon, enhet, kilde og type. Eksisterende total og
næringssnapshot brukes fortsatt til summering. Gamle logger uten metadata
åpnes som direkte gram/ml; metadata utledes ikke fra dagens produktdata.
Redigering, angre og kopiering bevarer historisk grunnlag. Skalering endrer
antall i samme forhold som mengden. Bytte til direkte mengde fjerner valget.
Lokal JSON-lagring trenger ingen ny SQL-kolonne. Synkformat og null-/legacy-
semantikk er beskrevet i `docs/sync-contract-v1.md`.

## Manuelt næringsgrunnlag (2026-10-03)

Manuelle produkter har eksplisitt `nutritionBasis` og valgfri lokal
`manualNutritionInput` med originalverdier, grunnlag, mengde, enhet og navn.
Porsjoner krever dokumentert brukeroppgitt størrelse i g/ml og lagres som
`ServingOption` med brukerkilde. Beregningsverdier normaliseres uten avrunding
før lagring; gram og ml konverteres ikke. Tilleggsmetadata inngår i lokal produkt-JSON og additivt i `product.upsert`.
Eldre produkter uten metadata dekodes fortsatt. Serveren lagrer metadata sammen med produktet.

### OFF-bearbeidingsinformasjon (2026-10-03)

`Product.processingInfo` er valgfri katalogmetadata med `novaGroup` (1–4),
rå markører med type/kilde-ID og ingrediensliste (nb → no → originaltekst).
Lagres i eksisterende produkt-JSON; eldre JSON uten feltet er kompatibel.
Ingen endring i synkhendelser eller serverkontrakt. Estimerte næringsverdier
og lokalt beregnet NOVA inngår ikke.

`Product.nutriScoreInfo` er valgfri OFF-katalogmetadata: karakter A–E og
original beregningsversjon når tilgjengelig. Feltet lagres i eksisterende
produkt-JSON og bevares ved produktkopiering. Eldre JSON er kompatibel;
ingen database- eller synkkontraktsendring.
