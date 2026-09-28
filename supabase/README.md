# MatLogg på Supabase

Denne mappen er teknisk sannhetskilde for den nye serverplattformen. SQL-skjema,
RLS, RPC-er og funksjoner skal endres med versjonerte migrasjoner og kode her;
manuelle skjemaendringer i dashboardet er ikke tillatt.

## Lokal utvikling

Krav: Docker og Node.js. Fra repo-roten:

```sh
npm ci
npm run supabase:start
npm run supabase:reset
npm run supabase:lint
npm run supabase:test
npm run functions:test
```

Lokale porter bruker `5532x` for å kunne kjøre ved siden av andre Supabase-
prosjekter. Synk starter alltid av i migrasjonen; `seed.sql` gjentar verdien ved
lokal reset.

Lag `Config/Supabase-Debug.xcconfig.local` med lokal eller staging URL og
publishable key. Release bruker tilsvarende ignorerte
`Config/Supabase-Release.xcconfig.local`. Secret/service-role key skal aldri
ligge i Xcode-konfigurasjon eller appen.

## Staging og produksjon

Opprett to separate prosjekter i samme EØS-region. Legg prosjektspesifikke
tilganger i GitHub environments `staging` og `production`:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_REF`
- `SUPABASE_DB_PASSWORD`

Krev manuell godkjenning på `production`. Kjør workflowen «Deploy Supabase»
først mot staging. Sett deretter `SUPABASE_PUBLISHABLE_KEY` og
`PURGE_CRON_SECRET` som funksjonshemmeligheter i hvert prosjekt. Supabase
injiserer URL og service-role key til Edge Functions.

Aktiver e-postbekreftelse og SMTP, legg inn `matlogg://auth/callback` som tillatt
redirect, og aktiver Apple for `com.nithusan.MatLogg`. Apple provider-secret
opprettes og roteres i Supabase secret storage, aldri i repoet.

Kjør `ops/configure-purge-cron.sql` etter at cron-secret er lagt i Vault.
Konfigurer backup/PITR, varsling og en dokumentert restore-øvelse per miljø.

## Kill switch og cutover

Synk er av etter migrering. Slå den på først etter godkjent fysisk iPhone- og
TestFlight-port:

```sql
update public.app_config
set value = 'true'::jsonb, updated_at = now()
where key = 'sync_enabled';
```

Ved hendelser settes verdien tilbake til `false`. Edge Function returnerer da
`503` med `Retry-After`; lokale hendelser beholdes for retry. NestJS/Prisma
fjernes først etter stabil produksjonspilot.
