---
name: offline-sync
description: Utform og endre MatLoggs lokale lagring, synkkø, event-format, retry, idempotens og konfliktregler mellom iOS og backend.
---

# Offline-first og synk

Velg kontekst etter endringen: Ved lokal lagring/kø, les berørte deler av `LocalStore.swift` og `SyncEngine.swift` samt relevante tester. Ved transport/backend, les `SupabaseService.swift`, `sync-events` og berørte SQL/RPC-er. Ved event-format eller kompatibilitet, les `docs/sync-contract-v1.md` og relevant del av `docs/specs/05-data-model-sync.md` og `docs/specs/07-edge-cases.md`. Les legacy-backendens sync-modul bare ved kompatibilitetsarbeid i `backend/`.

Lokale brukerhandlinger skal lagres atomisk før nettverksforsøk. Hver hendelse skal ha stabil unik ID, eksplisitt type og schema-versjon. Retry må være trygg: backend skal deduplisere på event-ID, og klienten skal ikke miste en hendelse ved timeout eller prosessavbrudd.

Ved kontraktsendringer, vurder bakoverkompatibilitet, utrullekkefølge, ukjent event-type, delvis batch-feil, payload-grenser, klokkeavvik og to enheter. Ikke endre konfliktstrategi implisitt.

Test minst den berørte happy pathen og relevante feilmoduser: gjentatt levering, offline→online, avbrutt in-flight, valideringsfeil og retry/backoff. Oppdater både dokumentert format og begge sider av kontrakten når de påvirkes.

Finn målrettede testkommandoer i `docs/testing.md` og `ios-swiftui`/`backend-api` etter hvilken side som endres. Ved kontraktsendring skal relevante tester på begge sider kjøres; grønne klienttester alene bekrefter ikke kompatibilitet.
