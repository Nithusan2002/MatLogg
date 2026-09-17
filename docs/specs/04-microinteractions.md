# MatLogg – Mikrointeraksjoner & UX Details

> **Dokumentstatus:** Detaljert og delvis planlagt interaksjonsunderlag.
> [`../design-and-user-flow.md`](../design-and-user-flow.md) og
> [`../design-system.md`](../design-system.md) er normative ved konflikt. Lyd,
> animasjon og haptikk nedenfor regnes ikke som implementert uten støtte i kode
> og [`../current-state.md`](../current-state.md).

## 4.1 Haptics & Sound Design

### **Haptic Feedback Patterns**

| Event | Haptic Pattern | Duration | Condition |
|-------|-----------------|----------|-----------|
| **Strekkode detektert** | 3× short taps (UIImpactFeedbackStyle.light) | 300ms | Toggle: ON/OFF |
| **Logging suksessfull** | 2× medium taps (UIImpactFeedbackStyle.medium) | 400ms | Toggle: ON/OFF |
| **Feil / Validering** | 1× strong tap (UIImpactFeedbackStyle.heavy) | 150ms | Always |
| **Mengde-stepper (±)** | 1× light tap | 50ms | Toggle: ON/OFF |
| **Favoritt toggle (★)** | 1× light tap | 100ms | Toggle: ON/OFF |
| **Swipe-to-delete hover** | 1× weak tap (UISelectionFeedbackGenerator) | 50ms | Visual feedback |
| **Deling vellykket** | 2× light taps | 300ms | Toggle: ON/OFF |

### **Lyddesign**

| Event | Lyd | Varighet | Format |
|-------|-----|----------|--------|
| **Strekkode OK** | "Pling" (220 Hz + 440 Hz harmonic, sine wave) | 200ms | .wav |
| **Logging OK** | "Ding-dong" (upward progression) | 300ms | .wav |
| **Feil/Validering** | "Buzz" (error beep, 150 Hz) | 200ms | .wav |
| **Offline warning** | "Bleep-bloop" (descending, 400→200 Hz) | 400ms | .wav |
| **Sync success** | "Chime" (uplifting 3-note progression) | 500ms | .wav |

**Innstillinger:**
- Haptics: Toggle [ON/OFF] i Settings
- Lyd: Toggle [ON/OFF] i Settings (respekterer device-muting: silent-switch)
- Begge kan toggles individuelt

---

## 4.2 Animations & Transitions

### **Screen Transitions**

```
Home → Camera:            Vertical push (bottom-to-top)
Camera → ProductDetail:   Slide out kamera, fade in kort (0.3s ease-in)
ProductDetail → Home:     Slide-up dismiss
Home → History:           Bottom sheet slide-up (0.25s cubic-bezier)
Product → Mini-Receipt:   Zoom-in + fade (scale: 0.8→1.0, 0.4s ease-out)
```

### **Loading States**

```
Barcode lookup:
• Shimmer animation (pulsing) på produktkort-placeholder (1.5s loop)
• "Søker ..." tekst under (dots animates ".", "..", "...")

Sync upload:
• Liten spinner (CircleProgressView) ved sync
• "Synkroniserer..." badge nederst

Network error:
• Red banner fade-in (0.3s), auto-dismiss etter 4s
```

### **Preutfylt mengde (100g) – Interaction**

```
Produktkort vises:
1. Mengde-felt automatisk prefylt: "100" (no user action needed)
2. Fokus: IKKE på mengde-felt (lar bruker se innholdet først)
3. Bruker kan tapp mengde-felt eller stepper-knapper
4. Endring → live-beregning av totalt kcal/makro (animation: color-pulse på total)
5. Visuell feedback: "Total: XXX kcal" highlighted (500ms pulse, green)

Fokus-atferd:
• Mengde-felt IKKE auto-focused (unngår tastatur pop-up)
• Tapping input → numeric keyboard appear + text-selection
• Dismissing keyboard → felt beholder verdi
```

---

## 4.3 Valideringsfeiltilstander

### **Mengde-validering**

```
Input: 0g
Feedback: Red border, below-field tekst: "Min. 1g"
Icon: ⚠️ orange
Knapp: [Legg til] disabled (grayed out)
```

```
Input: 10.5 kg (10500g)
Feedback: Red border, tekst: "Maks. 10 kg – er du sikker?"
Buttons: [Ja, fortsett] [Nei, endre]
```

```
Input: Negativ eller tekstkarakter
Feedback: Fjerner ugyldig input, beretter brukeren
```

### **Produktopprettelse – Validering**

```
Navn (empty):
Field: Red outline
Error: "Navn er påkrevd"

Kcal = 0 eller >900:
Field: Red outline
Error: "Kcal må være 1–900"
Hint: "Typisk 50–800 for mat"

Makro sum (if manual):
If P + C + F > 100:
Error: "Totalvekt makro kan ikkje overskride 100g per 100g (fysisk umulig)"
```

### **Nettverksfeil**

```
Timeout (>5s):
Modal: "Søket tok for lang tid. Vil du prøve igjen?"
Buttons: [Prøv igjen] [Søk manuelt] [Avbryt]

Server error (5xx):
Modal: "Noe gikk galt. Prøv igjen senere eller søk manuelt."
Buttons: [Prøv igjen] [Søk manuelt]

No internet:
Toast / banner: "Du er offline. Du kan fortsette å logge – vi synkroniserer når du er tilbake."
Tap → dismiss eller auto-dismiss (5s)
```

---

## 4.4 Loading States & Spinners

### **Strekkode-oppslag (barcode lookup)**

```
Sekvens:
1. Skann-deteksjon → kamera lukkes umiddelbar
2. "Henter produkt ..." (med spinner) vises (500ms–3s)
3. Produktkort dukker opp (hvis OK) ELLER "Ikke funnet" (hvis 404)
4. Hvis error: retry-option

Tegn: iOS system spinner (UIActivityIndicatorView, style: medium)
```

### **Sync Upload**

```
Situasjon: Bruker trakk ut nettverkskabel midt i logging
Feedback:
• Lokal event-kø viser: "1 hendelse i kø"
• Icon + tekst: ↻ "Synkroniserer" (med spinner, subtle)
• Når nett tilbake: auto-sync trigger
• Suksess: "✓ Synkronisert"

Design: Subtilt bottom banner (ikke modalt)
```

---

## 4.5 Slettingsoperasjoner & Confirmation

### **Slette innslag fra logg**

```
Interaksjon: Swipe left på logg-innslag
Reveal: [Slett] knapp (rød bakgrunn)

Tap [Slett]:
Alert dialog:
  Title: "Slette 'Brød (150g)'?"
  Message: "Dette kan ikkje angres."
  Buttons: [Avbryt] [Slett] (red)

Slett-handling:
• Lokal DB: sletter umiddelbar
• Event-kø: enqueuer "delete" event
• UI: fader ut (0.3s), re-render logg
• Toast: "✓ Slettet"
```

### **Slette historikk-element**

```
Interaksjon: Long-press på produkt i historikk
Menu: [Slett fra historikk] [Avbryt]

Tap [Slett]:
• Umiddelbar fjernal fra visuell liste
• Produkt forblir i favoritter (hvis der)
• Toast: "✓ Fjernet fra historikk"
```

---

## 4.6 Favoritt-toggle (Star Animation)**

```
Interaksjon: Tapping ☆ på produktkort

Sekvens:
1. ☆ → ★ (animasjon: scale 1.0→1.2→1.0, 300ms, spring)
2. Bakgrunnsfarve pulse (gul highlight, 0.3s fade)
3. Haptic: light tap
4. Toast: "✓ Lagt til favoritter"

Interaksjon: Tapping ★ igjen
1. ★ → ☆ (animasjon: scale 1.2→1.0, 300ms)
2. Toast: "✓ Fjernet fra favoritter"
```

---

## 4.7 Måltidsrad – Interaction & Feedback

```
Interaksjon: Tapping måltid (f.eks. LUNSJ)

Visuelt feedback:
• Tidligere valgt måltid (f.eks. FROKOST): remove highlight
• Nytt måltid (LUNSJ): 
  - Scale 1.0→1.05 (spring, 0.2s)
  - Bakgrundsfargen animeres til selected-state
  - Undertekst endres: "Aktivt måltid"

Haptic: light tap

AppState: current_meal = "lunch"
→ Påfølgende skanning logger til LUNSJ
```

---

## 4.8 Mini-Kvittering – Auto-dismiss & Interaction**

```
Visning: Etter [Legg til] på produktkort

Sekvens:
1. Kvittering dukker opp (bottom sheet, 50% height)
   Animasjon: slide-up (0.3s ease-out)
2. Haptic: double-tap
3. Lyd: ding-dong
4. Tekst vises: produktnavn, mengde, kcal, måltid

Auto-dismiss:
• Timer starter: 5 sekunder
• Hvis bruker berører noe på skjermen: reset timer
• Hvis bruker trykker [Lukk]: umiddelbar dismiss
• Hvis bruker trykker [Skann neste]: kvittering forsvinner, kamera åpner (mengde resettes)

Default-handling: [Skann neste] får focus (visuelt fremhevet)
```

---

## 4.9 Offline-Mode Signalisering

```
Status-indikator:
• Top-bar mini-banner (grå bakgrunn): "📶 Offline"
• Synlig på alle skjermer (unntatt kamera)

Tap banner → Innstillinger / Sync-status

Funksjonalitet:
✓ Logging: fullt mulig (lagres lokalt)
✓ Historikk: synlig
✓ Scanning: lokal DB bare (evt. fallback søk)
✗ Strekkode-API: unavailable (show "Søk manuelt" istedenfor)
✗ Deling: deaktivert (banner: "Deling krever internett")

Auto-sync:
• Når nett returnerer: auto-trigger sync
• Event-kø prosesseres
• Toast: "✓ Synkronisert 3 hendelser"
```

---

## 4.10 Edge Cases & Spesialsituasjoner

### **Scenario: Bruker logger samme produktet to ganger på kort tid**

```
Logg 1: Brød (150g) + Lunsj + 12:30
Logg 2: Brød (100g) + Lunsj + 12:32

Display:
┌─ LUNSJ ────────────────────────┐
│ ▼ Brød, rostaboost (150g) 360   │
│ ▼ Brød, rostaboost (100g) 240   │
│   Total: 600 kcal               │
└─────────────────────────────────┘

Ingen deduplisering; bruker kan slette manuelt om ønskelig
Hint (optional): "Vi merket 2 like varer. Vil du slette en?"
```

### **Scenario: Bruker søker på strekkode mens offline, finner lokalt**

```
Offline → Skanning → Søk i lokal DB
• Hvis produkt er tidligere scannet: vise det direkte
• Hvis ikkje: "Ikkje tilkoblet internet – vil du opprett produktet manuelt?"
• Fallback: Søk etter produktnavn (lokal kun)
```

### **Scenario: Produkt blir moderert og slettet fra backend**

```
Bruker A: opprettet unverified produkt
Bruker B: importerte det fra A's share-link
Backend: moderator godkjente det
Server: nå i verified prodcuts-tabell

Bruker B:
• Lokalt: produk forblir (snapshot av state)
• Neste sync: merker som "verified" (no re-download, bare status-oppdatering)
• UI: ingen endring for bruker

Scenario B: moderator AVVISTE produktet
Bruker A: finner ut gjennom moderation-log (later feature)
Bruker B: produktet blir merket som "rejected"
UI: warning "Dette produktet var ikke godkjent. Du kan fortsatt bruke det lokalt, men det er ikke lenger delt."
```

### **Scenario: Bruker endrer kalorimål midt på dagen**

```
Tidligere: 2000 kcal/dag mål
Nå: 2500 kcal/dag mål

Resultat:
• Status-ring på Home oppdateres umiddelbar
• Progressverdi endres: var 75% (1500/2000), blir 60% (1500/2500)
• Fargen kan endres (var rød, blir gul)
• Toast: "Kalorimål oppdatert"
• Backend: synkroniseres med neste event-upload
```

---

## 4.11 Share-link Web Fallback

```
bruker A deler produkt-link:
matlogg://share/abc123xyz → deep link
https://matlogg.app/share/abc123xyz → web fallback

Web-landing-side (universalLink):
┌─────────────────────────────────────┐
│  MatLogg                             │
├─────────────────────────────────────┤
│                                      │
│  ┌──────────────────────────────┐    │
│  │    [Produktbilde]            │    │
│  └──────────────────────────────┘    │
│                                      │
│  Brød, Rostaboost                    │
│  240 kcal per 100g                   │
│  P: 8g | C: 45g | F: 3g              │
│                                      │
│  Merke: Kneippehuset                 │
│  Kategori: Bakeri                    │
│                                      │
├─────────────────────────────────────┤
│                                      │
│  [Åpne i MatLogg]  ← Deep link       │
│  [Last ned MatLogg] ← App Store      │
│  [Kopier link]                       │
│                                      │
└─────────────────────────────────────┘

Tap [Åpne i MatLogg]:
• Hvis app installed: deep link activates
• App åpner ProductDetail-view (100g prefill)
• Automatisk "Legg til i favoritter"-option

Tap [Last ned MatLogg]:
• Åpner App Store direktelink
• App installs
• User must return to link for import (or links is cached in clipboard)
```
