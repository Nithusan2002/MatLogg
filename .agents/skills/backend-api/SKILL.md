---
name: backend-api
description: Implementer og vurder MatLoggs NestJS-API, Prisma/PostgreSQL-modell, autentisering, validering og backend-kontrakter.
---

# Backend og API

Les `backend/README.md`, `docs/specs/06-api-endpoints.md`, berørte NestJS-moduler, Prisma-skjemaet og klientkallet i `APIService.swift`.

- Valider all ekstern input ved grensen og returner stabile, maskinlesbare feil.
- Autoriser mot ressursens eier; stol aldri på `userId` fra payload når identiteten finnes i tokenet.
- Bruk transaksjon når inbox/deduplisering og domeneskriving må være atomisk.
- Endre database via Prisma-migrasjon og vurder constraints, unike nøkler, indekser, nullable-felt og slettesemantikk.
- Hold API-endringer bakoverkompatible eller dokumenter eksplisitt versjonering og utrullekkefølge.
- Ikke rediger eller commit generert output som løsning på kildekodeendringer.

Kjør minst backend build og relevante tester. Ved databaseendring, generer Prisma-klient og valider migrasjonen i en ikke-produksjonsdatabase når det er tilgjengelig.
