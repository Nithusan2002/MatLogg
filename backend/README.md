# MatLogg Backend (legacy under Supabase-cutover)

Denne NestJS/Prisma-backenden beholdes midlertidig for sammenligning og trygg
cutover. Ny serverutvikling skjer i `../supabase/`. Ikke fjern denne mappen før
fysisk iPhone, staging, backup/restore og intern TestFlight-pilot er godkjent.

## Vedlikeholdsgrense og avviklingsvilkår

Legacy vedlikeholdes som referanse: sikkerhetsrettelser, nødvendige oppdateringer
av støttede avhengigheter/runtime og bevaring av eksisterende tester. Ny
serverfunksjonalitet utvikles i Supabase. Backend-CI beholdes med samme porter.
Ved neste cutovervurdering skal statusen under oppdateres; alder alene utløser
ikke automatisk sletting eller stenging.

Kodegjennomgang 25. november 2026, basert på `14e861a`:

| Avhengighet/vilkår | Status og neste handling |
| --- | --- |
| Vanlig appoppstart | MatLoggApp og AuthViewModel sin standardinitializer velger SupabaseService eller eksplisitt utilgjengelig konto. De bruker ikke automatisk gammel HTTP-backend. |
| Legacy-klientvalg | AuthRepository.swift beholder AuthAPIClient og LegacyAccountAuthRepository; AuthViewModel har fortsatt `init(apiClient:sessionStore:)`. Kontroller kallere og distribuerte klienter før disse fjernes. Ingen auth-endring inngår i gjeldende opprydding. |
| Delte typer | SupabaseService og SyncEngine bruker APIService.UploadResult, RejectedEvent og APIError. Flytt nødvendige felles typer med kontraktstester før eventuell fjerning av gammel transport. |
| Aktiv katalog og lokalt konto-/profillager | APIService brukes også til produktkatalog; AuthService og deler av AuthRepository.swift inneholder aktive lokale/felles kontrakter. Disse filene skal ikke slettes samlet som «legacy». |
| Drift og eldre distribuerte klienter | Ikke bekreftet. Base-URL `https://api.matlogg.app/v1` i kildekode beviser verken aktiv eller avsluttet drift. Innhent eier-/deployopplysninger og klientstatus før avvikling. |
| Cutoverbevis | Fysisk QA av avgrensede lokale flyter er dokumentert i docs/testing.md. Dette bekrefter ikke alle opprinnelige staging-, backup/restore- og TestFlight-portene. Se docs/production-readiness.md for kandidatbundet status. Eventuell endring av skyspesifikke vilkår krever eksplisitt beslutning. |

En separat avviklingspakke skal behandle følgende konkrete deler:

1. **Serverkilder:** alle versjonerte filer under `backend/`, inkludert
   `src/`, `prisma/`, `test/`, package-/lockfiler, Dockerfile, docker-compose.yml
   og byggeverktøy. Fastsett listen fra `git ls-files backend` på den faktiske
   avviklingscommitten, og registrer den siste committen som bevarer innholdet.
2. **CI/drift:** `.github/workflows/backend-ci.yml` og eventuelle faktiske
   deployjobber/tjenester identifisert i driftskontrollen. Bevar Supabase-CI,
   secret scanning og testbevis som fortsatt gjelder aktiv plattform.
3. **Klienttransport, som egen endring:** vurder APIService sine signupEmail,
   loginEmail, loginApple, revokeRefreshToken, deleteAccount og uploadEvents,
   LegacyAccountAuthRepository og den tilhørende AuthViewModel-initializeren.
   Bevar AuthTokens, lokale sesjons-/profilkontrakter og øvrige delte typer
   så lenge de har aktive kallere. Auth-/tilgangsendringer må avklares særskilt.
4. **Tester og dokumentasjon:** kartlegg hvilke kontrakt-/sikkerhetsregresjoner
   som allerede dekkes på Supabase, og flytt nødvendige manglende kontroller
   før gamle tester fjernes. Oppdater docs/README, current-state, decisions
   og berørte spesifikasjoner samtidig med en godkjent avvikling.

Gjenoppretting av kilder/CI skal kunne skje fra det registrerte arkivpunktet.
Dette gjenoppretter ikke en database eller driftstjeneste; eventuell operativ
rollback krever egen verifisert oppskrift og skal ikke reaktivere gammel auth
automatisk. Før pakken er godkjent beholdes eksisterende drift, kode og porter.

**Beslutning i gjeldende runde:** viderefør referansevedlikehold og fullfør
beslutningsgrunnlaget. Større sletting, endring av auth/tilgang og produksjons-
avvikling er fortsatt avklaringspunkter, ikke godkjente implementeringstiltak.

Backenden bygges og kjøres på Node.js 24 LTS. Eldre lokale Node-versjoner er
ikke en støttet produksjonsruntime.

## Lokal oppstart

```bash
docker compose up -d
npm install
export DATABASE_URL="postgresql://matlogg:matlogg@localhost:5432/matlogg?schema=public"
export JWT_SECRET="replace-with-a-long-local-secret"
export APPLE_CLIENT_ID="com.nithusan.MatLogg"
export DEV_LOGIN_ENABLED="true"
npx prisma migrate deploy
npm run start:dev
```

API-et nekter å starte uten `JWT_SECRET`. `dev-login` er deaktivert som
standard, kan bare aktiveres eksplisitt og er alltid deaktivert når
`NODE_ENV=production`.

Verifiser synk mot den lokale PostgreSQL-databasen:

```bash
npm test
npm run test:integration
npm run test:http-integration
npm run test:auth-integration
```

Integrasjonstestene krever `DATABASE_URL` (verdien i `.env.example` fungerer
med Docker Compose-oppsettet) og rydder opp alle testdata de oppretter.
HTTP-testen starter NestJS på en tilfeldig lokal port og bruker en egen
`JWT_SECRET` kun for testprosessen.

Auth-integrasjonstesten dekker registrering, passordhashing, innlogging,
rotering/gjenbruksvern, samtidige refresh-forsøk, utløp og
utloggingsrevokering for refresh-token, soft-delete og permanent purge etter
retensjonsperioden. Access-token varer som standard i 15 minutter;
refresh-token varer i 30 dager og lagres bare som hash. Utløpte
refresh-sesjonsrader ryddes ved oppstart og deretter daglig; revokerte rader
beholdes frem til utløp for å kunne oppdage gjenbruk.

Apple-innlogging krever at `APPLE_CLIENT_ID` matcher appens Services ID eller
bundle-ID. Backend verifiserer Apple-tokenets signatur, issuer, audience,
utløp og nonce. Lik e-post kobler ikke automatisk en Apple-identitet til en
eksisterende e-postkonto.

Health check:

```
GET http://localhost:4000/health
```

Swagger:

```
http://localhost:4000/docs
```

Swagger er på i utvikling og av som standard når `NODE_ENV=production`.

## Produksjonsimage

Bygg og kjør det minimale runtime-imaget:

```bash
docker build --target runtime -t matlogg-backend .
docker run --rm -p 4000:4000 \
  -e NODE_ENV=production \
  -e DATABASE_URL="postgresql://..." \
  -e JWT_SECRET="<tilfeldig hemmelighet på minst 32 tegn>" \
  matlogg-backend
```

Kjør migrasjoner som en separat engangsjobb fra `migration`-målet før ny
runtime-versjon startes. Produksjonskrav, staging-port og rollback finnes i
[`docs/production-readiness.md`](../docs/production-readiness.md).

API-et har en standardgrense på 120 kall/minutt per klient og endepunkt, med
strammere grenser på auth og synk. Den innebygde telleren er per backendinstans;
offentlig produksjon trenger i tillegg delt eller plattformstyrt edge-begrensning.
Sett `TRUST_PROXY_HOPS` til det dokumenterte antallet
proxyledd hos driftsleverandøren; feil verdi kan gjøre IP-basert begrensning
upålitelig. Native iOS trenger ikke CORS. Eventuelle web-origins oppgis som
eksakte HTTPS-adresser i `CORS_ALLOWED_ORIGINS`.

## Dev-login

```bash
curl -X POST http://localhost:4000/auth/dev-login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@matlogg.no"}'
```

Svar:

```json
{ "accessToken": "<jwt>" }
```

## Sync events

```bash
curl -X POST http://localhost:4000/v1/sync/events \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "b8e59c6b-0c55-4f7e-9a43-1c0d6f3f9a21",
    "clientTime": "2026-01-23T12:00:00.000Z",
    "events": [
      {
        "eventId": "1b6b94e6-8e1b-4f2d-9c7a-2ef9f9df77d9",
        "type": "goal.set",
        "createdAt": "2026-01-23T12:00:00.000Z",
        "entityId": "7d87bddf-bb1d-43f8-bdc8-e242bcd97e2b",
        "schemaVersion": 1,
        "payload": "eyJrY2FsVGFyZ2V0IjoyMDAwLCJwcm90ZWluVGFyZ2V0IjoxNTAsImNhcmJUYXJnZXQiOjI1MCwiZmF0VGFyZ2V0Ijo2NX0="
      }
    ]
  }'
```

## Env

Se `.env.example`.

## Beslutningsgrunnlag kontrollert 26. november 2026

Anbefaling: behold avgrenset referansevedlikehold inntil faktisk drift og
eldre klienter er avklart. Denne gjennomgangen godkjenner ingen avvikling.
Grunnlag: lokal main `068f24d`; ingen forespørsler er sendt til produksjon.

- AuthViewModel sin standardinitializer velger SupabaseService eller
  UnavailableAccountAuthRepository. Legacy-initializere finnes fortsatt.
- APIService inneholder fremdeles gammel konto-/synktransport, men også
  produktkatalog. SupabaseService og SyncEngine bruker fortsatt UploadResult,
  RejectedEvent og APIError derfra. En samlet filsletting ville ramme aktiv kode.
- Backend CI bygger, tester og kjører migreringer i testmiljø. Ingen
  produksjonsdeploy er definert i denne workflowen. Dockerfile kjører
  migrering ved oppstart; det er ikke bevis for at containeren er i drift.
- `git ls-files backend` viser 52 versjonerte filer på denne kandidaten.
  Eksakt avviklingsliste må tas fra godkjent avviklingskandidat, ikke fra
  lokale node_modules eller generert dist.

Følgende eksterne opplysninger mangler før anbefalingen kan endres:

| Avklaring | Nødvendig bevis / neste handling |
| --- | --- |
| Hvem drifter eventuell gammel API-tjeneste, og hvor? | Navngitt tjeneste-/deployeier, aktiv konfigurasjon og siste deploy. Fravær av deploy i repoet er utilstrekkelig. |
| Bruker distribuerte klientversjoner gammel API? | Versjonsoversikt og aggregert trafikk for relevante ruter, uten tokens/persondata. En kildekode-URL beviser ikke trafikk. |
| Kan eventuell database/tjeneste gjenopprettes? | Verifisert backup-/restore- og rollback-oppskrift før stenging. Kildearkiv er ikke databaserestore. |
| Hvilke opprinnelige cutoverporter gjelder fortsatt? | Kandidatbundet staging-/pilot-/backupstatus eller eksplisitt beslutning om endret scope. Lokal lansering opphever ikke krav automatisk. |

Når disse foreligger: oppdater tabellen, velg behold/migrer/avvikle og
utarbeid den konkrete avviklingspakken beskrevet ovenfor før godkjenning.
Den separate lokale avhengighetsplanen under docs/plans er et eget arbeid;
parser-, Zod- eller Nest-migrering inngår ikke i denne avviklingsvurderingen.
