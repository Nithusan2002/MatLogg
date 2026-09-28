# MatLogg Backend (legacy under Supabase-cutover)

Denne NestJS/Prisma-backenden beholdes midlertidig for sammenligning og trygg
cutover. Ny serverutvikling skjer i `../supabase/`. Ikke fjern denne mappen før
fysisk iPhone, staging, backup/restore og intern TestFlight-pilot er godkjent.

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
