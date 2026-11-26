# Utbedring av legacy-avhengigheter

Gjennomgang 26. november 2026, kodegrunnlag `068f24d`. Planen er ikke
implementert. Ingen pakker, API-er, tilgangsregler eller CI-porter er endret.

## Bekreftet grunnlag

Ny `npm audit --omit=dev --json` viser 0 kritiske, 7 høye og 5 moderate
berørte pakker. Dette er ikke 12 uavhengige angrepsveier: audit teller også
overordnede Nest-pakker som arver funn fra underavhengigheter. Alle funnene
under finnes i produksjonsavhengighetene, selv om enkelte funksjoner ikke er
funnet brukt av appens serverkode. Faktisk legacydrift og eldre klientbruk er
fortsatt uavklart; se `backend/README.md`. Ingen produksjon er testet.

`proxy-addr` 2.0.8 fjernet det tidligere kritiske funnet. Backend CI for
`068f24d` bestod, men det bekrefter ikke at de øvrige funnene er løst.

| Prioritet | Pakker og audit-alvorlighet | Eksponering i undersøkt kode | Tiltak |
| --- | --- | --- | --- |
| 1 | `body-parser` (høy), `qs` (moderat) | `src/main.ts` registrerer JSON-parser med 5 MB-grense. Parsing skjer før controllerens domeneregler; autentisering og grenser inne i synkvalideringen erstatter ikke parservern. De konkrete qs-funksjonene i advisoryene er ikke alle påvist brukt av applikasjonen. | Test avgrenset oppdatering til `body-parser` 1.20.9 og `qs` 6.17.1. Nest 10 låser body-parser eksakt, og Express/body-parser låser qs til eldre minor. Ren lockfile-refresh er derfor ikke nok; vurder smale, dokumenterte overrides innen samme major. |
| 2 | `zod` (høy) | Direkte brukt i `sync.contract.ts` og `sync.service.ts`, inkludert samlingsvalidering. Maks 50 events, 64 KiB dekodet payload og 50 måltidslinjer reduserer risiko, men er ikke bevis på at minneproblemet er eliminert. | Egen migrering fra 3.25.76 til patchet Zod 4 (audit angir minst 4.6.6). Bevar canonical typer, defaults, ukjente felt, feilutfall og synkformat. Kontroller blant annet endret `z.record`-API. |
| 3 | `@nestjs/core` (moderat), `@nestjs/platform-express` (høy), `@nestjs/common` (moderat), `@nestjs/throttler` (moderat) | Core og adapter brukes ved all serveroppstart. Audit arver også parser-/upload-funn. Throttler beskytter auth-/synkruter og må regresjonstestes ved bytte. Den konkrete Core-injeksjonens utnyttbarhet er ikke fastslått her. | Planlegg samlet Nest-oppgradering med kompatible peers. Audit foreslår Core/platform 12.6.3; verifiser versjonene på implementeringsdagen. Ikke oppgrader Nest-pakkene uavhengig eller anta at alle følgefunn er egne feil. |
| 4 | `multer` (høy), `file-type` (moderat) | Trukket inn av adapter/common. Ingen FileInterceptor, filvalidering eller opplastingsruter er funnet i `backend/src`. Lavere påvist eksponering, men pakkene følger produksjonsinstallasjonen. | Løs med kompatible Nest-avhengigheter. Ikke innfør filopplasting. Isolert major-override av file-type er ikke anbefalt uten kompatibilitetsbevis. |
| 4 | `@nestjs/swagger` (høy), `js-yaml` (høy), `lodash` (høy) | Swagger importeres og dekoratorene brukes. Dokumentruter er av som standard i produksjon, men `SWAGGER_ENABLED=true` kan åpne dem. Ingen direkte YAML-innlesing eller lodash-template fra brukerinput er funnet. Dette er ikke en garanti mot indirekte bruk. | Ta med Swagger i Nest-migreringen. Hvis migreringen utsettes, vurder separat samme-major patch av js-yaml (minst 4.3.2) og lodash (utenfor rapportert sårbart område), med Swagger-byggtest. Swagger 7 låser begge eksakt; dette krever eksplisitt kompatibilitetsvurdering. |

## Gjennomføring i avgrensede trinn

1. **HTTP-parser først.** Undersøk pakkeendringene og bruk kun smale overrides
   dersom eksisterende krav hindrer en vanlig patch. Bevar 5 MB-grensen og
   request-/feilsemantikk. Legg til målrettet HTTP-regresjon for overstor JSON,
   ugyldig JSON og komprimert body med ugyldig avslutning; serveren skal avvise
   kontrollert og fortsatt svare på neste forespørsel. Ikke bruk ubegrensede
   belastningstester eller ekte produksjonsserver.
2. **Zod som egen endring.** Sammenlign aksepterte/avviste v1-payloads før og
   etter, inkludert ukjente felt, default/null/optional, ugyldig dato/UUID,
   batch-/payloadgrenser og store samlinger. Test tapsfri retry, eierskap og
   atomisk inbox/domeneskriving med eksisterende kontrakt-/integrasjonstester.
3. **Nest/Swagger samlet.** Fastsett versjonsmatrise for common/core/adapter,
   testing, CLI/schematics, Swagger, JWT/passport og throttler før endring.
   Kontroller migreringskrav mot de faktiske API-ene i repoet. Endringer i
   autentisering eller tilgang skal avklares før implementering; en
   avhengighetsoppdatering er ikke autorisasjon til å endre disse reglene.
   Hvis dette blir for stort for referansevedlikehold, avklar migrering kontra
   avvikling med drifts-/klientbevis. Ikke slett legacy eller svekk CI som snarvei.

Etter hvert trinn: kjør ny audit og vurder faktiske resterende dependency paths.
Ikke bruk `npm audit fix --force` som samlet løsning. Ikke lov null funn før
den konkrete kandidatlåsefilen er kontrollert.

## Minste verifisering og ferdigkriterium

- Node 24, ren installasjon fra låsefil, bygg og `npm test` for berørte endringer.
- Parsertrinnet krever HTTP-regresjonene over. Zod-/Nest-endringer krever også
  eksisterende database-, HTTP- og auth-integrasjonstester mot bekreftet
  disponibel lokal PostgreSQL, samt containerbygg i Backend CI.
- Audit-porten `--omit=dev --audit-level=critical` beholdes. Vurder høye/moderate
  funn eksplisitt; grønn eksisterende port betyr ikke at de er borte.
- Ingen skjema-, klient/server-kontrakt-, localOnly- eller opplastingsendring.
  Avhengighetsretning, eierskap og transaksjoner følger fortsatt
  `docs/architecture-principles.md`. Ingen utrulling inngår i planen.
- Rapporter kandidatcommit, audit før/etter, faktisk utførte tester og eventuelle
  resterende funn. Rå audit-/testlogger holdes utenfor repoet.

Gjennomgangen brukte npm-registerets versjons-/avhengighetsmetadata og fersk
audit, låsefil, serveroppstart, synkvalidering, runtime-policy og målrettet søk
etter upload/YAML/template-bruk. Ingen nye bygg eller tester ble kjørt fordi
leveransen bare er denne planen. Skill: `backend-api`.
