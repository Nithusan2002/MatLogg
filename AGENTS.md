# AGENTS.md – MatLogg

## Prosjekt

MatLogg er en norsk iOS-app for enkel matlogging, ernæringsoversikt og måloppfølging. Klienten er SwiftUI og local-first; aktiv serverplattform er Supabase Auth, Edge Functions og PostgreSQL/RLS. NestJS/Prisma beholdes som legacy under cutover.

Les `docs/README.md` og relevante spesifikasjoner før produktmessige eller arkitektoniske endringer. Kode og migrasjoner er teknisk sannhetskilde når eldre spesifikasjoner avviker; dokumenter viktige avvik.

`docs/architecture-principles.md` er normativ for alle kodeendringer. Les den før implementering og bruk den aktivt i review og ferdigvurdering. Dersom en foreslått endring bryter prinsippene, skal agenten enten endre løsningen eller synliggjøre avviket og be om avklaring før implementering.

## Arkitekturkrav

- Følg pragmatisk MVVM i iOS-klienten: `View → ViewModel → Repository → Service/local store/API`.
- Views skal ikke utføre domenelogikk eller IO. ViewModels eier feature-state og brukerhandlinger; repositories skjuler datakilder; services håndterer avgrenset infrastruktur.
- `AppState` skal bare koordinere appomfattende state og skal ikke være permanent hjem for featurelogikk, domeneregler eller IO.
- Sett sammen avhengigheter ved app-roten. Bruk små protokoller og injeksjon ved IO-grenser slik at ViewModels kan testes uten ekte database eller nettverk.
- Bevar local-first. Domenedata og tilhørende synkhendelse skal skrives atomisk lokalt.
- Alle synkhendelser skal ha stabil event-ID, canonical type og eksplisitt schema-versjon. Klient og backend skal følge `docs/sync-contract-v1.md` og endres samlet ved kontraktsendringer.
- Backend skal validere input, hente identitet fra token, autorisere mot ressursens eier og skrive inbox/domenedata atomisk.
- Produksjonssynk skal forbli deaktivert til relevante kontrakt-, retry-, idempotens-, eierskaps- og integrasjonstester er grønne.

## Grunnregler

- Bygg den enkleste løsningen som dekker avtalt scope. Ikke utvid MVP uten å synliggjøre konsekvensene.
- Behandle ernæringsverdier, målberegninger og brukerdata som sensitive. Ikke presenter estimater som medisinske råd eller dokumenterte fakta.
- Bevar datakilde og måleenhet gjennom søk, matching, lagring og visning. Ikke gjett manglende næringsdata.
- Legg aldri hemmeligheter, tokens, persondata eller ekte produksjonsdata i repoet.
- Bruk versjonerte SQL-migrasjoner i `supabase/migrations/` for den aktive serverplattformen. Legacy-skjemaet endres via Prisma-migrasjoner. Ikke rediger genererte filer i `backend/dist/`.
- Bruk semantiske design-tokens og eksisterende komponenter fremfor lokale stilvarianter.
- Alle `ScrollView`, `List` og `Form` som vises under den vedvarende bunnmenyen skal bruke `matLoggTabBarScrollClearance()`; ikke-scrollbare faneskjermer skal også holde bunntilknyttet innhold over menyen. Dette gjelder nye skjermer som pushes i en fanes `NavigationStack`, men ikke sheets, fullskjermsvisninger, innlogging eller onboarding.
- Verifiser proporsjonalt med risiko. Kjør som standard bare den minste målrettede kontrollen som gir reell trygghet; ikke kjør full testpakke eller full build uten konkret grunn. Verifisering kan hoppes over for dokumentasjon, tekst og åpenbart risikofrie endringer. Logikk, lagring, synk, backend, personvern og autentisering skal fortsatt ha relevant målrettet verifisering. Oppgi alltid hva som ble kjørt, eller hvorfor verifisering ble hoppet over.
- Oppdater relevante docs når API-kontrakter, synkformat eller scope endres. Før større tekniske og produktmessige beslutninger i `docs/decisions.md`.

## Tokenøkonomi

- Undersøk bare filer og dokumentasjon som er nødvendige for oppgaven. Bruk målrettet søk før hele filer leses.
- Ikke kartlegg, refaktorer eller kommenter kode utenfor avtalt scope.
- Gjenbruk allerede innhentet kontekst og ikke les uendrede filer på nytt uten grunn.
- Samle uavhengige søk og kontroller i færrest mulig verktøykall.
- Ikke bruk nettsøk eller underagenter med mindre brukeren eller en gjeldende overordnet instruksjon krever det.
- Gjør rimelige, reversible antakelser fremfor å starte unødvendige avklaringsrunder. Oppgi viktige antakelser kort.
- Sluttrapporter skal som standard være korte og bare dekke endringer, verifisering og gjenværende risiko. Ikke gjengi kode eller full diff uten forespørsel.
- Ikke opprett ekstra dokumentasjon, planer eller oppsummeringer med mindre de er påkrevd eller har varig verdi.

## Prosjektkart

| Område | Formål |
| --- | --- |
| `MatLogg/App/` | App-state, domenemodeller, feature flags og personvernkonstanter |
| `MatLogg/DesignSystem/` | Farger, typografi og gjenbrukbare SwiftUI-komponenter |
| `MatLogg/Services/` | Lokal lagring, API, auth, synk, matching og enhetsintegrasjoner |
| `MatLogg/Views/` | Feature-sorterte skjermer og delte views |
| `MatLoggTests/`, `MatLoggUITests/` | Swift Testing og UI-tester |
| `supabase/` | Aktiv serverplattform: Auth-integrasjon, Edge Functions, SQL-migrasjoner og RLS |
| `backend/src/` | Legacy NestJS-moduler for auth, helse, Prisma og synk |
| `backend/prisma/` | Databaseskjema og migrasjoner |
| `docs/specs/` | Produkt-, UX-, data-, API- og roadmap-spesifikasjoner |
| `docs/decisions.md` | Kort, kronologisk logg over varige tekniske og produktmessige valg |
| `matlogg-legal/` | Juridiske tekster; endres med særskilt varsomhet |

## Skills

Bruk relevante skills fra `.agents/skills/` for arbeidsområdet. Disse er førstevalg for MatLogg; last andre skills bare når oppgaven krever en konkret kapasitet som prosjektets skills ikke dekker.

| Arbeid | Påkrevd skill |
| --- | --- |
| Ny funksjon, endret scope eller større brukerflyt | `product-review` før implementering |
| Visuell retning, brukerflyt, UX-tekst, skjermkritikk eller designsystem | `product-design` før implementering |
| SwiftUI, navigasjon, state, tilgjengelighet eller iOS-tester | `ios-swiftui` |
| Lokal lagring, event queue, konfliktregler eller synkformat | `offline-sync` |
| Supabase, Edge Functions, RLS, legacy NestJS/Prisma, auth, API-kontrakter eller databaseendringer | `backend-api` |
| Ernæringsdata, måleenheter, målberegning, personvern eller helserelatert språk | `nutrition-privacy` |
| Nye funksjoner, sikkerhetskritiske endringer, pilot eller release | `qa-release` etter relevante fag-skills |

`nutrition-privacy` er obligatorisk for endringer som påvirker kalorimål, vekt, personopplysninger eller kildevisning. `qa-release` er obligatorisk før produksjonsutrulling.

## Arbeidsrekkefølge

- Ny brukerfunksjon: produktvurdering → produktdesign → iOS/UX → backend/synk ved behov → implementering → QA.
- Data- eller synkendring: offline-sync → backend-api → kompatibilitetsvurdering → implementering → QA.
- Release: relevante fag-skills → qa-release → eksplisitt go/no-go.

## Autonomi og verifisering

- Innen avtalt scope, fullfør lokale, reversible endringer og relevante kontroller uten gjentatt bekreftelse. Rett feil som endringen introduserer og kjør berørte kontroller på nytt til de består, eller til en konkret blokkering krever brukerinput. Ikke utvid arbeidet til urelaterte feil.
- Fastsett ut fra oppgaven hva som viser at den er ferdig før implementering: ønsket adferd og minste relevante kontroll. Bruk eksisterende tester og kommandoer i `docs/testing.md` og fag-skills. Små, tydelige oppgaver trenger ikke egen planfil.
- Ved bugfix, bruk en reproduksjon eller regresjonstest når praktisk, og kontroller at den fanger feilen før rettelsen og består etterpå. Ikke svekk tester for å få grønt resultat.
- Bruk dedikerte QA-miljøer ved tester som endrer data. Bekreft lokal/disponibel database før reset eller migrering; ikke anta at miljøvariabler peker lokalt. Respekter grensene nedenfor.
- Gjennomgå egen diff for utilsiktede endringer, arkitekturbrudd og relevante feilmoduser før ferdigmelding. Oppgi faktisk resultat og verifiseringshull; en foreslått kommando er ikke en utført kontroll.

## Stopp før

Forklar konsekvensene og be om avklaring før destruktive datamigrasjoner, sletting av vesentlig kode eller brukerdata, endringer i autentisering/tilgang, håndtering av produksjonshemmeligheter, produksjonsutrulling eller større avvik fra spesifisert scope.

## Ferdigdefinisjon

Før en kodeendring regnes som ferdig, kontroller den eksplisitt mot `docs/architecture-principles.md`, inkludert avhengighetsretning, local-first, transaksjonsgrenser, eierskap og testbarhet der punktene er relevante.

Rapporter kort: hva som ble endret, berørte filer, skills brukt, verifisering, antakelser, arkitekturavvik og gjenværende risiko eller neste steg.
