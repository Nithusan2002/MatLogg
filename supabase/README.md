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
E-postvarsling er klargjort med Resend-adapter (ingen abonnement er opprettet).
Sett `DELETION_ALERT_RESEND_KEY`, `DELETION_ALERT_FROM` (verifisert avsender) og
`DELETION_ALERT_TO=nithusank.2002@gmail.com` i Supabase secret storage.
Varslene inneholder bare feilkategori og antall, aldri konto-ID eller brukerdata.
Manglende konfigurasjon eller leveringsfeil logges; dette regnes ikke som
aktivert varsling. Verifiser en syntetisk feilmelding i mottakerens innboks før
produksjon. Leverandøravtale og avsenderoppsett må være avklart.
API-kontrakt: https://resend.com/docs/api-reference/emails/send-email
Nye kontoslettinger forsøker å slette domenedata og Auth i samme forespørsel,
uten fast ventetid. Ved feil beholder profilen slettemarkøren, og cron prøver
igjen hvert femte minutt. Kontoens egne produkter slettes også ved purge.
Eksisterende sletteforespørsler beholder tidligere frist; migrasjonen flytter
ikke eksisterende brukerdata til umiddelbar purge. RLS sperrer lesetilgang straks profilen
markeres for sletting, også for et fortsatt gyldig access-token.
Tidligere frakoblede produkter omfattes
ikke automatisk; eier-ID kan ikke rekonstrueres uten separat vurdering.

Kontroller cron og HTTP-resultat separat: vellykket cron betyr at SQL-jobben
kjørte, ikke at Edge Function fullførte slettingen. Overvåk både uteblitte
kjøringer, HTTP-feil/timeouts og `failed > 0` i purge-resultatet. Ikke logg
kontoidentifikatorer eller payload. Dokumenter hvem som mottar varsler og
hvordan slettinger gjenanvendes før en restore åpnes for trafikk.

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

## Lokal restore-kontroll

`scripts/verify-local-backup-restore.sh` bruker bare den isolerte
`supabase_db_matlogg-sync-readiness`-containeren med syntetiske QA-data.
Den dumper `auth`, `public` og `private`, gjenoppretter til en ny database,
sammenligner radkontrollsummer og rydder opp i restore-databasen og dumpen.
Hosted backup/PITR og recovery skal i tillegg verifiseres etter
`docs/production-readiness.md` før pilot.
