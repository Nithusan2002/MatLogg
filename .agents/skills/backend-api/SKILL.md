---
name: backend-api
description: Implementer og vurder MatLoggs Supabase-plattform, Edge Functions, RLS og legacy NestJS/Prisma, autentisering, validering og backend-kontrakter.
---

# Backend og API

Les `supabase/README.md`, `docs/specs/06-api-endpoints.md`, `docs/sync-contract-v1.md`, berørte Edge Functions/SQL-migrasjoner og klientkallet i `SupabaseService.swift`. Ved legacy-arbeid, les også `backend/README.md`, berørte NestJS-moduler og Prisma-skjemaet. `APIService.swift` håndterer blant annet eksterne produktkall og er ikke appens aktive synktransport.

- Valider all ekstern input ved grensen og returner stabile, maskinlesbare feil.
- Autoriser mot ressursens eier; stol aldri på `userId` fra payload når identiteten finnes i tokenet.
- Bruk transaksjon når inbox/deduplisering og domeneskriving må være atomisk.
- Endre aktiv database via versjonert SQL-migrasjon i `supabase/migrations/` (Prisma-migrasjon for legacy) og vurder constraints, unike nøkler, indekser, nullable-felt og slettesemantikk.
- Hold API-endringer bakoverkompatible eller dokumenter eksplisitt versjonering og utrullekkefølge.
- Ikke rediger eller commit generert output som løsning på kildekodeendringer.

Ved kodeendring, kjør relevante Supabase-/Deno-kontroller fra `docs/testing.md`. Ved databaseendring, valider migrasjonen og berørte RLS-/RPC-regler i en ikke-produksjonsdatabase. For legacy-kode, kjør backend build og relevante tester; generer Prisma-klient ved skjemaendring. Rene dokumentasjonsendringer trenger ikke build.
