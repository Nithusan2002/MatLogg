# MatLogg Backend (MVP)

## Lokal oppstart

```bash
docker compose up -d
npm install
npx prisma migrate dev
npm run start:dev
```

Health check:

```
GET http://localhost:4000/health
```

Swagger:

```
http://localhost:4000/docs
```

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
        "entityId": "goal",
        "schemaVersion": 1,
        "payload": "eyJrY2FsVGFyZ2V0IjoyMDAwLCJwcm90ZWluVGFyZ2V0IjoxNTAsImNhcmJUYXJnZXQiOjI1MCwiZmF0VGFyZ2V0Ijo2NX0="
      }
    ]
  }'
```

## Env

Se `.env.example`.

