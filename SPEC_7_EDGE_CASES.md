# MatLogg – Edge Cases & Exception Handling

## 7.1 Network & Connectivity Edge Cases

### **EC-1: Sudden Offline During Logging**

**Scenario:**
```
User taps "Legg til" on produktkort
Nettverkskabel trekkes ut midt i POST request
```

**Handling:**
1. URLSession timeout (30 sekunder default)
2. Request er added to sync_events queue (is_synced=0)
3. Log entry er allerede inserted lokalt (optimistic write)
4. UI shows: "Lagring pågår... vil synkronisere når nett er tilbake"
5. When network returns: auto-sync retry

**Recovery:**
- Eksponentiel backoff: 1s → 2s → 4s → 8s (max 5 attempts)
- If all retries fail: user prompted to retry manually
- Log blir ikke duplikert (event_id = idempotency key)

---

### **EC-2: Server Returns 500 Error During Sync**

**Scenario:**
```
Backend server has temporary outage
Sync sends 10 events, server returns 500
```

**Handling:**
1. Client receives 500 error
2. Event queue NOT marked as synced
3. Exponential backoff triggered
4. After 5 failed attempts, event moved to "manual review" queue
5. User gets notification: "Synk-feil. Vil du prøve igjen?"

**Recovery:**
- Manual retry button in Settings
- Or auto-retry after 1 hour
- No data loss (events are persistent)

---

### **EC-3: Partial Sync Success**

**Scenario:**
```
Sync sends 5 events
Events 1,2,3 succeed; events 4,5 fail (product not found)
```

**Response:**
```json
{
  "success": false,
  "synced_events": [
    { "event_id": "e1", "status": "ok" },
    { "event_id": "e2", "status": "ok" },
    { "event_id": "e3", "status": "ok" }
  ],
  "errors": [
    { "event_id": "e4", "status": "error", "reason": "product_not_found" },
    { "event_id": "e5", "status": "error", "reason": "product_not_found" }
  ]
}
```

**Handling:**
1. Events 1,2,3: marked as synced (is_synced=1)
2. Events 4,5: remain in queue (is_synced=0)
3. UI shows: "✓ 3 synkronisert, 2 feil"
4. Failed events: flagged for manual review or automatic retry

---

### **EC-4: Concurrent Requests from Multiple Devices**

**Scenario:**
```
Device A: Logs "Brød 150g" at 12:30
Device B: Logs "Brød 150g" at 12:30 (same time, different devices)
Both sync simultaneously
```

**Conflict Resolution:**
1. Backend receives both events
2. Both have same user_id, product_id, timestamp
3. Tiebreaker: device_id + server_timestamp
4. First write wins (other is flagged as duplicate)
5. Response: "Duplicate detected; using server version"
6. Both devices sync to same canonical state

---

## 7.2 Data Validation Edge Cases

### **EC-5: Amount = 0g**

**Scenario:**
```
User enters 0g in mengde-field and taps "Legg til"
```

**Handling:**
1. Client-side validation: prevents submission
2. Field shows red border: "Min. 1g"
3. [Legg til] button disabled
4. If somehow bypassed (API call): backend rejects with 422

---

### **EC-6: Amount > 10 kg**

**Scenario:**
```
User enters 15000g (15 kg) of bread
```

**Handling:**
1. Numerisk input capped at 10000g (validation)
2. If user persists: warning dialog
   - "Dette er mer enn 10 kg. Er du sikker?"
   - [Nei, endre] [Ja, fortsett]
3. Backend also validates (last line of defense)

---

### **EC-7: Product Creation with Invalid Macros**

**Scenario:**
```
User creates product:
- 100g
- Protein: 50g
- Carbs: 50g
- Fat: 50g
Total: 150g (physically impossible)
```

**Handling:**
1. Client-side warning: "Makronæringsstoffene kan ikke være mer enn 100g per 100g"
2. User can choose: [Endre] [Fortsett (bruker vil markeres som mistenkt)]
3. Backend logs: "unverified_product_high_macro_warning"
4. Moderation: flagged for review

---

### **EC-8: Kcal Calculation Mismatch**

**Scenario:**
```
User sets: P=10g, C=50g, F=10g (total = 70g macro)
Kcal = (10*4 + 50*4 + 10*9) = 530 kcal

But user entered: 240 kcal (too low)
```

**Handling:**
1. Client calculates expected kcal: (P*4 + C*4 + F*9) / 100
2. If discrepancy > 10%: warning
3. "Du skrev 240 kcal, men makroer tilsvarer ~530 kcal. Hvilket er riktig?"
4. No hard block; user proceeds at own risk

---

## 7.3 Barcode & Product Search Edge Cases

### **EC-9: Duplicate Barcodes (Different Products)**

**Scenario:**
```
EAN 5900423000890:
- Backend: "Brød, Rostaboost"
- User: same EAN, creates "Brød, Different Brand"
```

**Handling:**
1. User creation shows warning: "This EAN already exists"
2. Options: [Bruk eksisterende] [Opprett ny (duplikat)]
3. If user persists: product marked as duplicate_barcode in moderation
4. Later: moderation merges or deletes

---

### **EC-10: Barcode Scanner Detects Same Code Twice Quickly**

**Scenario:**
```
User scans "5900423000890"
Kamera detects again within 100ms
```

**Handling:**
1. Debounce logic (ignore duplicates <500ms)
2. Haptic only fires once
3. Single API request (not two)

---

### **EC-11: Invalid/Malformed Barcode**

**Scenario:**
```
Camera detects: "123ABC" (not EAN-13)
```

**Handling:**
1. Regex validation: EAN must be 13 digits
2. Invalid format: show warning "Strekkoden var ikke gyldig"
3. User can retry or search manually

---

### **EC-12: Search Returns No Results**

**Scenario:**
```
User searches: "xyz1234qwerty"
No products match
```

**Handling:**
1. Search result: empty state
   "Ingen produkter funnet. Vil du opprett det?"
   [Ja, opprett] [Nei, søk igjen]
2. If [Ja]: Go to create product form

---

## 7.4 Authentication & Authorization Edge Cases

### **EC-13: Token Expires During Session**

**Scenario:**
```
User: logged in, token valid for 24h
After 25h: user taps [Legg til]
Token has expired
```

**Handling:**
1. API returns 401 Unauthorized
2. App attempts refresh-token exchange
3. If refresh succeeds: retry original request
4. If refresh fails: user logged out, redirect to login
5. Toast: "Din sesjon har utløpt. Logg inn på nytt."

---

### **EC-14: User Logs In on Device A, Logs In on Device B Simultaneously**

**Scenario:**
```
Device A: POST /auth/login at 12:30:00Z
Device B: POST /auth/login at 12:30:01Z (1 second later)
Both same user
```

**Handling:**
1. Both login succeed
2. Both get separate JWT tokens
3. Both devices can operate independently
4. Sync conflicts resolved at log-entry level (not token level)
5. No session invalidation (multi-device support)

---

### **EC-15: User Deletes Account, Then Tries to Login**

**Scenario:**
```
User initiates account deletion
Account marked: deleted_at = now, but not yet hard-deleted
30 min later: user tries to login with same email
```

**Handling:**
1. Backend checks: user.deleted_at is not null
2. Returns 410 Gone / 403 Forbidden
3. Message: "Kontoen er markert for sletting"
4. Options: [Reactivate] or proceed with deletion

---

## 7.5 Sharing & Link Edge Cases

### **EC-16: Share Link Expires While Browser Tab is Open**

**Scenario:**
```
User shares link: matlogg://share/abc123
Link expires (TTL=30 days)
User still has tab open, clicks [Åpne i MatLogg]
```

**Handling:**
1. Deep link activated
2. App makes request: GET /api/v1/shares/abc123
3. Backend returns 410 Gone
4. App shows: "Delingslinken er utløpt eller kansellert"
5. [Lukk] button

---

### **EC-17: Share Link Revoked By Sharer**

**Scenario:**
```
User A: shares product with link
User B: opens link, starts import
User A: cancels share (revokes token)
```

**Handling:**
1. User B: GET /shares/{token} → 410 Gone
2. If import was in progress: abort
3. Message: "Denne delingslinken ble kansellert"

---

### **EC-18: Sharer Deletes the Product**

**Scenario:**
```
User A: shares "Custom Product"
User A: deletes product from their DB
User B: tries to import
```

**Handling:**
1. Share link still valid (separate entity)
2. GET /shares/{token} returns product data (cached)
3. User B can import as copy
4. No error

---

## 7.6 Offline Mode Edge Cases

### **EC-19: Offline, Scanner Query Fails, Fallback to Manual Search**

**Scenario:**
```
Offline mode
User taps [Søk manuelt]
Searches for "brød"
```

**Handling:**
1. Query local DB only: LIKE 'brød%'
2. Returns local products matching
3. Results sorted by frequency (most used first)
4. Tap result → produktkort (100g prefill)

---

### **EC-20: Sync Queue Accumulates >100 Events**

**Scenario:**
```
User offline for 3 days
Logs 200+ entries
Network returns
```

**Handling:**
1. Batch sync: split into chunks of 50 events
2. Multiple POST requests to /sync
3. Progress indicator: "Synkroniserer... 50/200"
4. If one batch fails: pause, retry later
5. UI: "Synk pågår" banner

---

## 7.7 UI State & Navigation Edge Cases

### **EC-21: User Presses Home Button Mid-Logging**

**Scenario:**
```
User on produktkort, has set mengde=150g
Presses Home button (minimizes app)
3 minutes later: returns to app
```

**Handling:**
1. App state preserved (AppState saved to UserDefaults)
2. User returns to produktkort
3. Mengde still = 150g
4. No data loss

---

### **EC-22: Rapid Tab Switching**

**Scenario:**
```
User: on Home tab
Taps Settings tab
Immediately taps Home tab again (within 100ms)
```

**Handling:**
1. ViewModels don't reload (cached)
2. Smooth transition
3. No duplicate API calls (memoization)

---

### **EC-23: User Closes Camera While Scanning**

**Scenario:**
```
User in camera view
Taps ✕ (Close) while API request is pending
```

**Handling:**
1. In-flight request: cancel token issued
2. Camera closes immediately
3. User returned to Home
4. No partial state left

---

## 7.8 Database & Storage Edge Cases

### **EC-24: SQLite Database Corruption**

**Scenario:**
```
Device storage failure
SQLite database file corrupted
```

**Handling:**
1. App launch: database open fails
2. Error detected: "Database error"
3. Options:
   - [Restore from backup] (if iCloud sync enabled)
   - [Reset app data]
4. If neither: alert user to contact support

---

### **EC-25: Storage Full (Disk Space)**

**Scenario:**
```
Device has <50 MB free
User tries to take product photo (upload)
```

**Handling:**
1. Image compression: quality reduced to fit
2. If still too large: show error "Ikke nok lagringsplass"
3. User can retry or skip photo

---

## 7.9 Calculation & Rounding Edge Cases

### **EC-26: Floating Point Rounding**

**Scenario:**
```
Product: 240 kcal per 100g
User: 33.33g
Calculated: 240 * 33.33 / 100 = 79.992 kcal
```

**Handling:**
1. Stored as exact value: 79.992
2. Display: rounded to 1 decimal or integer
3. Daily total: sum of exact values (not rounded sum)
4. Example: 79.992 + 80.008 = 160.0 (exact)

---

### **EC-27: Macro Percentage Rounding**

**Scenario:**
```
Protein: 150.7g
Daily target: 150g
Percent: 150.7 / 150 = 100.47%
Display: "100.5%" or "100%"?
```

**Handling:**
1. Calculation: exact (150.7/150 = 1.00467)
2. Display: rounded to nearest 1% or 0.1%
3. Progress ring: based on exact value
4. No rounding in backend calculations (preserves precision)

---

## 7.10 Performance & Timeout Edge Cases

### **EC-28: API Response Too Slow (>30s)**

**Scenario:**
```
User scans barcode
Backend is slow (processing queue backed up)
Request pending for 30 seconds
```

**Handling:**
1. URLSession timeout fires after 30s
2. Error displayed: "Søket tok for lang tid. Prøv igjen?"
3. User can:
   - [Prøv igjen]
   - [Søk manuelt]
   - [Avbryt]

---

### **EC-29: Very Large Product Database (Matvaretabellen)**

**Scenario:**
```
Database has 50,000 products
User searches "brød"
Returns 2,000+ results
```

**Handling:**
1. Query limited to: LIMIT 100 (only first 100 results)
2. Sort by relevance + frequency
3. Pagination: user can load more (lazy load)
4. Search refined: user types more to filter

---

## 7.11 Notification & Haptics Edge Cases

### **EC-30: User Disables All Haptics**

**Scenario:**
```
Settings: Haptics = OFF
User scans barcode
```

**Handling:**
1. No haptic feedback (all generators skipped)
2. Lyd: still plays (separate toggle)
3. Visual feedback: still shown (progress animations, etc)

---

### **EC-31: Device Doesn't Support Haptics**

**Scenario:**
```
Older iPhone (iPhone 6s, no haptic engine)
User scans barcode
```

**Handling:**
1. App detects: device not haptic-capable
2. Attempts skipped gracefully
3. Fallback: sound + visual only
4. No errors thrown

---

## 7.12 Special Character & Encoding Edge Cases

### **EC-32: Product Name with Special Characters**

**Scenario:**
```
User creates: "Smørbrød, Kverner's Østfold"
Contains: Norwegian characters (ø, æ, å)
```

**Handling:**
1. Input validation: UTF-8 encoding required
2. Storage: UTF-8 in SQLite
3. API: JSON UTF-8 encoded
4. Display: renders correctly on iOS
5. Search: supports Norwegian characters (not accent-insensitive)

---

### **EC-33: Very Long Product Name**

**Scenario:**
```
User enters: "Brød, super delicious artisanal sourdough baked with traditional methods and organic flour from local farm"
(>500 characters)
```

**Handling:**
1. Input field: max 255 characters
2. Validation: truncated or error shown
3. Backend: VARCHAR(255) enforced
4. UI: overflow handling (text wrap or ellipsis)

