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
