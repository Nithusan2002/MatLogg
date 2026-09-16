# Beslutningslogg

Bruk denne filen for varige valg som påvirker produktretning, arkitektur, datakontrakter eller drift. Hold hvert innslag kort: dato, beslutning, begrunnelse og konsekvens.

## 2026-09-15 – Prosjektstruktur og agentarbeidsflyt

**Beslutning:** Behold ett Xcode-prosjekt og eksisterende appstruktur, samle spesifikasjoner i `docs/specs/`, og bruk `AGENTS.md` med domeneavgrensede skills i `.agents/skills/`.

**Begrunnelse:** Prosjektet er foreløpig lite nok til at en større fysisk kodeomlegging eller moduldeling ville gitt mer flyttekostnad enn verdi. Dokument- og agentstrukturen gjør ansvar og sannhetskilder tydelige uten å risikere byggeoppsettet.

**Konsekvens:** Nye filer følger eksisterende feature-/laginndeling. Separate Swift Packages eller større arkitekturomlegging vurderes først når kompileringstid, testbarhet, gjenbruk eller eierskap gir et konkret behov.

## 2026-09-15 – Varm visuell retning og fem hovedfaner

**Beslutning:** MatLogg bruker et varmt, kortbasert designsystem med avrundet systemtypografi og fem hovedfaner: Hjem, Søk, Legg til, Fremgang og Profil. Home viser alltid alle fire måltider, mens detaljert redigering åpnes som en filtrert dagslogg.

**Begrunnelse:** Retningen kombinerer en vennlig, lett tilgjengelig førsteside med en komplett dagsoversikt og gjør søk, logging og fremgang raskt tilgjengelig uten å endre domenemodellen.

**Konsekvens:** Favoritter og nylig brukt hører til Søk, den sentrale fanen åpner en legg-til-meny, og nye skjermer skal bruke semantiske farger og dynamiske, avrundede systemfonter. Safe Mode, local-first-lagring og synkkontrakter forblir uendret.

## 2026-09-15 – Pragmatisk MVVM og versjonert local-first-synk

**Beslutning:** iOS-klienten følger avhengighetsretningen `View → ViewModel → Repository → Service/local store/API`. `AppState` begrenses til appomfattende koordinering. Lokal domeneskriving og synkhendelse er én atomisk operasjon, og klient/backend deler en eksplisitt, versjonert kontrakt. Backend validerer input og håndhever eierskap fra autentisert identitet.

**Begrunnelse:** Tydelige grenser gir testbare features og hindrer at UI, global state og infrastruktur vokser sammen. Atomisk køskriving, idempotens og eierskapskontroll er nødvendig for en trygg local-first-modell.

**Konsekvens:** Nye features skal følge `docs/architecture-principles.md`. Kontraktsendringer må oppdateres på begge sider og dokumenteres. Produksjonssynk aktiveres ikke før integrasjonstester for retry, duplikater og eierskap er grønne.
## 2026-09-16 – Referansedrevet Home og hurtiglogging

- Home bruker en varm, kortbasert retning med stor kaloristatus, separate makrokort, full måltidsoversikt og en egendefinert femfaners bunnlinje.
- Den sentrale Legg til-handlingen åpner et tilgjengelig bunnark med måltidsvalg, søk, skanning, manuell registrering, favoritter og nylig brukte produkter.
- Den kanoniske lagrings- og synkverdien `snacks` beholdes, men presenteres som «Kveldsmat». Dette unngår datamigrering og kontraktsendring.
- Safe Mode skal fjerne skjulte verdier og tilhørende tilgjengelighetstekst, ikke maskere dem med avslørende plassholdere.

## 2026-09-16 – Versjonerte lokale SQLite-migrasjoner

**Beslutning:** Det lokale SQLite-skjemaet versjoneres med `PRAGMA user_version`. Hver migrasjon kjøres i en egen transaksjon, og versjonen økes bare når hele migrasjonen er vellykket.

**Begrunnelse:** Local-first-data må overleve appoppgraderinger. Idempotente, transaksjonelle migrasjoner gjør eksisterende installasjoner oppgraderbare uten tabellsletting eller delvis oppdatert skjema.

**Konsekvens:** Alle fremtidige lokale skjemaendringer får en ny, eksplisitt migrasjonsversjon og en test for oppgradering og databevaring. En database som er nyere enn appens støttede versjon åpnes ikke, for å unngå stille korrupsjon. Dette endrer ikke synkkontrakt v1 eller backendens Prisma-skjema.

## 2026-09-16 – Versjonert PostgreSQL-baseline

**Beslutning:** Backendens eksisterende Prisma-modell får en innskrevet
baseline-migrasjon, og databasespesifikke synkegenskaper verifiseres i en egen
PostgreSQL-integrasjonstest.

**Begrunnelse:** Prisma-skjemaet alene er ikke en deploybar eller sporbar
databasehistorikk. Idempotens, transaksjonell rollback og eierskap må testes mot
den faktiske databasen, ikke bare som isolerte kontraktsregler.

**Konsekvens:** Lokale og senere produksjonslignende miljøer bruker
`prisma migrate deploy`. Produksjonssynk forblir deaktivert til testen er grønn
mot PostgreSQL og de resterende retry- og klient–server-portene er bestått.

## 2026-09-16 – iOS 17, e-postauth og sletting med retensjonsperiode

**Beslutning:** Minimumsplattformen er iOS 17. MVP viser bare fungerende
e-post/passord-auth. Kontosletting fjerner lokale data etter godkjent serverkall,
revokerer servertilgang umiddelbart og purger personlige domenedata etter 30 dager.

**Begrunnelse:** Produktet skal ikke vise døde innloggingsvalg eller love sletting
som bare logger ut. iOS 17 gir en realistisk kompatibilitetsgrense for dagens
SwiftUI-implementasjon.

**Konsekvens:** Apple/Google er senere scope. Brukeropprettede produktbidrag
anonymiseres ved purge, mens logger, mål, favoritter, vekt og inbox-data slettes.
Produksjonssynk forblir deaktivert.
