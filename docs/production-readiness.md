# Produksjonsberedskap

Dette dokumentet er den operative minimumsporten for MatLogg-pilot og senere
produksjon. Local-first gjør at logging kan fortsette når backend er utilgjengelig,
men det fjerner ikke risiko knyttet til konto, persondata, synk eller serverkopier.

## Aktiv cutover-plan

Supabase er målplattform. Staging finnes i `eu-north-1` med migrasjoner,
Edge Functions, auth callback, Vault/Cron og avslått synk-kill-switch. Opprett
senere et separat produksjonsprosjekt i samme EØS-region, og deploy kun de
versjonerte filene i `supabase/`. Konfigurer SMTP, Apple-provider, backup/PITR
og varsling per miljø. Produksjonsmiljøet i GitHub skal kreve manuell
godkjenning.

Punktene nedenfor om NestJS/Prisma gjelder legacy-backenden mens den beholdes
under piloten. Den skal ikke reaktiveres etter produksjonscutover.

## Miljøer og utrulling

- Bruk separate PostgreSQL-databaser og hemmeligheter for staging og produksjon.
- Bygg `backend/Dockerfile` med `runtime` som kjøremål. Kjør migrasjoner som en
  separat engangsjobb fra `migration`-målet før ny backend startes.
- Bruk Node.js 24 LTS som definert i container og CI; ikke rull ut på EOL-runtime.
- Sett minst `NODE_ENV=production`, `DATABASE_URL`, et tilfeldig `JWT_SECRET` på
  minst 32 tegn og korrekt `TRUST_PROXY_HOPS` for plattformen.
- La `CORS_ALLOWED_ORIGINS` være tom når bare native-klienten bruker API-et. Hvis
  webflater legges til, oppgi eksakte kommaseparerte HTTPS-origins.
- Swagger er av i produksjon. Midlertidig aktivering krever
  `SWAGGER_ENABLED=true` og tilgangskontroll i plattformen.
- Backend rulles ut og verifiseres før en klient som avhenger av den. Synkflagget
  i iOS skal forbli av til staging-portene nedenfor er grønne.

## Hemmeligheter og data

- Oppbevar databasepassord og JWT-hemmelighet i plattformens secret manager;
  aldri i image, repo, CI-logg eller mobilklient.
- Aktiver kryptering, automatiske PostgreSQL-backuper og point-in-time recovery.
- Utfør og dokumenter en restore til en separat database før pilot.
- Logger og feilrapportering skal ikke inneholde token, e-post, vekt,
  ernæringslogger, synkpayload eller andre brukerdata.
- Verifiser eksport, soft-delete, tokenrevokering og permanent purge mot faktisk
  personvernerklæring og App Store-opplysninger.

## Overvåkning og varsler

Før pilot skal plattformen samle aggregerte, ikke-sensitive målinger for:

- tilgjengelighet, 5xx-rate og p95/p99-responstid
- PostgreSQL-tilkoblinger, lagring og mislykkede migrasjoner
- antall synkbatcher, avviste hendelser og 429-svar uten payloadinnhold
- mislykket innlogging/refresh som rate, aldri identifiserende verdier

Varsle ved vedvarende 5xx-rate over 1 %, health-feil, databaseutilgjengelighet
eller rask vekst i avviste synkhendelser. Angi én ansvarlig mottaker under pilot.

## Staging-port

1. Supabase-CI er grønn: database-reset, lint, pgTAP, Deno check/lint/test og
   målrettet iOS-bygg/test. Legacy backend-CI holdes grønn fram til opprydding.
2. Produksjonsimaget starter som ikke-root og svarer på `/health`.
3. Dev-login og Swagger er utilgjengelige med produksjonskonfigurasjon.
4. Auth, eierskap, duplikatlevering, tapt ACK, delvis avvist batch og retry er
   verifisert mot staging.
5. Rate limiting gir 429 uten at vanlig synk eller token-refresh blokkeres.
6. Offentlig trafikk har delt/plattformstyrt begrensning; den innebygde
   Throttler-telleren er bare per backendinstans.
7. Produksjonsavhengigheter har ingen uavklarte critical/high-funn. Kjente funn
   i NestJS 10 krever kontrollert rammeverksoppgradering eller dokumentert aksept.
8. Backup er opprettet og restore er demonstrert.
9. Rollback til forrige image er demonstrert uten å rulle tilbake en destruktiv
   migrasjon.
10. Personvern-/App Store-tekst samsvarer med databruk og leverandører.

## Ekstra port for AI og felles produktkatalog

Disse funksjonene har egne server- og klientflagg og kan rulles ut uavhengig.
De skal aktiveres i rekkefølgen manuell flyt, intern AI-pilot, kataloglesing,
bidrag til kontrollkø og til slutt eventuell autopublisering.

- OpenAI-nøkkel og `OPENAI_NUTRITION_MODEL` ligger bare i Supabase secrets;
  standardmodell er `gpt-6-luna`, og global nødstopp er testet.
- Databehandleravtale, tilgjengelig EØS-behandling, faktisk retensjon og
  personvern-/App Store-tekst er kontrollert før første eksterne AI-pilot.
- Private opplastinger avviser fremmed `assetId`, feil MIME og filer over 5 MB.
  Signerte URL-er, bilder, OCR-tekst og næringspayload finnes ikke i logger.
- Daglig AI-kvote, offentlig katalog-rate-limit og kostnadsalarm er testet.
- Etikettbilder slettes senest 30 dager etter avgjørelse; ubehandlede bidrag
  utløper etter 90 dager. Forsidebilder beholdes bare for publiserte produkter.
- Minst 50 norske/engelske etiketter dekker g/ml, kJ/kcal, porsjonskolonner,
  desimalkomma, salt/natrium, rotasjon og refleks. Autopublisering er no-go med
  mindre grunnlaget er korrekt i hele autopubliseringssettet, synlige tall
  matcher etikettens presisjon, manglende data aldri gjettes og tvetydighet
  stopper i kontrollkø.
- RLS/pgTAP, auth, idempotens, GTIN, eksakt/fuzzy/bildehash-duplikat,
  rapportering og moderatorlogg er grønne i staging.

## Pilot og nødstopp

Start med intern TestFlight, deretter 20–50 inviterte brukere. Følg feilrate,
synkavvisninger og supporthenvendelser minst én uke før bredere utrulling.
Backend kan stoppes uten å stoppe lokal logging. Supabase-funksjonen har en
serverstyrt kill switch som returnerer `503` og `Retry-After`, slik at hendelser
forblir lokale og retrybare. Produksjonssynk skal fortsatt ikke aktiveres før
resten av porten er dokumentert grønn.

Ved alvorlig feil: stans nye backenddeploys, deaktiver synkmottak hvis mulig,
bevar databasen og loggene, og rull tilbake applikasjonsimaget. Ikke reverser en
databasemigrasjon før konsekvensen for nyere data er kontrollert. Etter recovery
replayes ventende klienthendelser idempotent med opprinnelig `eventId`.

## Go/no-go

Offentlig produksjon er **no-go** til staging-porten er utført med faktiske
resultater. Å ha sjekklisten i repoet er ikke i seg selv godkjenning.
