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

## AI-avlesning og produktkatalog

Alle fire app-/serverflagg starter avslått: `nutrition_label_ai_enabled`,
`shared_catalog_read_enabled`, `catalog_contributions_enabled` og
`catalog_auto_publish_enabled`. Aktiver dem separat i staging og i denne
rekkefølgen. Mobilklientens tilsvarende `FeatureFlags` må også aktiveres i et
kontrollert pilotbygg.

AI-funksjonen krever disse Edge Function-hemmelighetene, aldri xcconfig:

- `OPENAI_API_KEY`
- `OPENAI_NUTRITION_MODEL` (valgfri, standard `gpt-6-luna`)
- `NUTRITION_AI_KILL_SWITCH` (`true` stopper nye AI-kall umiddelbart)

`product-submissions` er privat og midlertidig. `catalog-product-images` er
offentlig og inneholder bare forsider for publiserte katalogvarer.
`purge-product-images` bruker samme `PURGE_CRON_SECRET` som kontosletting og
skal planlegges med `ops/configure-purge-cron.sql`. Ikke aktiver AI-pilot før
personvernport, EØS-oppsett, kvoter og evalueringssett er godkjent.

## Lokal testing av produktgrenen

DEBUG-bygg kan aktivere én funksjon om gangen med launch-argumentene
`--enable-nutrition-label-ai`, `--enable-shared-catalog`,
`--enable-catalog-contributions` og `--enable-catalog-auto-publish`.
Release ignorerer disse argumentene. Serverflaggene må også aktiveres i det
lokale testmiljøet. Demo bruker ingen AI-/katalogbackend.

Ved kontroll 2026-10-01 kjører et separat PostgreSQL 17-miljø med prosjekt-ID
`matlogg-catalog-test` fra `/tmp/matlogg-catalog-local-test`. API er på
`http://127.0.0.1:55321`, Studio på `http://127.0.0.1:55323`. DEBUG-konfigurasjonen
peker lokalt, og serverflagget for kataloglesing er aktivert her; tidligere lokal konfigurasjon er sikkerhetskopiert til
`/tmp/matlogg-catalog-original-debug.xcconfig.local`. Bruk en lokal testkonto;
`--skip-auth` gir ingen servertoken til AI/opplasting.

Start funksjonene igjen ved behov:

```sh
node_modules/.bin/supabase functions serve --workdir /tmp/matlogg-catalog-local-test
```

Legg AI-konfigurasjon i en ignorert lokal env-fil og bruk `--env-file` ved
oppstart av funksjonene. Nøkkelen skal bare være i funksjonsmiljøet.
Aktiver ønsket flagg i dette lokale miljøets Studio, for eksempel:

```sql
update public.app_config set value = 'true'::jsonb, updated_at = now()
where key = 'shared_catalog_read_enabled';
```

AI happy path krever OpenAI-nøkkel og separat evaluering. Katalogbidrag lagres
atomisk i lokal kø, men klientens opplasting/innsending av denne køen er ennå
ikke implementert. Bidrag/autopublisering kan derfor ikke testes ende til ende
fra iOS. Rapportering og moderering finnes som serverendepunkter, uten full
klientflyt. Flaggene er av som standard.

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
