---
name: backend-api
description: Implementer og vurder MatLoggs Supabase-plattform, Edge Functions, RLS og legacy NestJS/Prisma, autentisering, validering og backend-kontrakter.
---

# Backend og API

Les bare kildene som gjelder endringen:

- Supabase-oppsett og database: `supabase/README.md` og berørte SQL-migrasjoner.
- API: relevant del av `docs/specs/06-api-endpoints.md`, berørt Edge Function og klientkall.
- Synk: `docs/sync-contract-v1.md`, `sync-events` og berørt kall i `SupabaseService.swift`. `APIService.swift` håndterer blant annet eksterne produktkall og er ikke aktiv synktransport.
- Legacy: `backend/README.md`, berørte NestJS-moduler og Prisma-skjema ved skjemaendring.

- Valider all ekstern input ved grensen og returner stabile, maskinlesbare feil.
- Autoriser mot ressursens eier; stol aldri på `userId` fra payload når identiteten finnes i tokenet.
- Bruk transaksjon når inbox/deduplisering og domeneskriving må være atomisk.
- Endre aktiv database via versjonert SQL-migrasjon i `supabase/migrations/` (Prisma-migrasjon for legacy) og vurder constraints, unike nøkler, indekser, nullable-felt og slettesemantikk.
- Hold API-endringer bakoverkompatible eller dokumenter eksplisitt versjonering og utrullekkefølge.
- Ikke rediger eller commit generert output som løsning på kildekodeendringer.

Ved kodeendring, kjør relevante Supabase-/Deno-kontroller fra `docs/testing.md`. Ved databaseendring, valider migrasjonen og berørte RLS-/RPC-regler i en ikke-produksjonsdatabase. For legacy-kode, kjør relevante tester og build når endringen påvirker kompilering; generer Prisma-klient ved skjemaendring. Rene dokumentasjonsendringer trenger ikke build.

Målrettede kontroller fra repo-roten med Deno tilgjengelig:

```bash
deno check 'supabase/functions/<funksjon>/index.ts'
deno test --allow-env 'supabase/functions/tests/<testfil>.ts'
```

Velg eksisterende funksjon/testfil for berørt adferd. Ved database-/RLS-endring: `npm run supabase:lint` og `npm run supabase:test` mot lokal Supabase. Reset er ikke en standardkontroll; bruk bare en bekreftet disponibel lokal database. Legacy-kommandoer fra `backend/`: `npm test`, eventuelt `npm run build`; integrasjonstester krever bekreftet testdatabase, se `docs/testing.md`.
