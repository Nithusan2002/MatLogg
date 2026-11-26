# Implementeringsplan etter IN2000-gjennomgangen

Dato: 26. november 2026. Status: gjennomføring fra main `068f24d`.

## Status etter avstemming mot main

Den første planen ble skrevet mot maskotarbeidskopien. Main har siden fått
teknisk-gjeld-runde 1 og 2. Tiltakene nedenfor er derfor beholdt som mål,
men skal ikke implementeres en gang til.

| Trinn | Status og bevis | Neste handling |
| --- | --- | --- |
| 1. Lesefeil | Implementert på main: throwing loadAllLogs/loadLogs/loadSummaries, kontrollerte SQLite-statements og feilformidling til ViewModels. Gamle feilskjulende historikkgrensesnitt er fjernet. | Bevar regresjonene; historiske kjøringer er dokumentert i testing.md. |
| 2. Brukertesting | Fem konkrete oppgaver og anonym resultatmal er lagt til i critical-flows-qa-plan.md. Ingen deltakere er rekruttert eller testet. | Gjennomfør med omtrent fem brukere på valgt QA-kandidat. |
| 3. Utkastmodell | Tilstandsmodell og kobling til eksisterende tester er lagt til i draft-recovery-improvement-plan.md. Nye tester kontrollerer forsinket svar/feil etter profilbytte og delt innlasting med retry. | Nye utkasttester bestod fysisk 26. november; stor-tekst UI-gjenoppretting står åpen. |
| 4. UX og tilgjengelighet | Avventer faktiske brukerfunn. Eksisterende fysisk feil/retry-QA fra teknisk gjeld er historisk bevis. | Prioriter høyst tre observerte problemer; manuell VoiceOver er fortsatt åpen. |
| 5. Kobling | HomeView-uttrekk og oppdeling av LocalStore-lesing er allerede på main. | Ingen ekstra refaktorering uten konkret behov. |
| 6. Kandidat | Eksisterende kandidatbevis står i testing.md og production-readiness.md. Denne gjennomføringen har egne kontrollresultater nedenfor. | Ny release krever egen kandidatkontroll og go/no-go. |

Arbeidet gjøres i eksisterende, ren main-checkout. Maskot-/Helsearbeidskopien
endres ikke. Produksjonskode er ikke endret som del av denne avstemmingen;
allerede implementerte rettelser gjenbrukes.

## Mål og rammer

Gjør Spor Mats kjerneflyter mer pålitelige, enklere å bruke og lettere å
videreutvikle. Planen konkretiserer forelesningsgjennomgangen og gjenbruker
`technical-debt-remediation.md`: databasefeil tilsvarer tiltak 1,
kandidatverifisering tiltak 2 og gradvis opprydding tiltak 3. Dette er ikke en
ny, konkurrerende backlog. Legacy-avklaring fra den planen beholdes separat.

Ingen nye produktfunksjoner er besluttet. Lokal lagring, historiske
næringssnapshots, kilde/enhet, atomisk domeneskriving med hendelser og
`DomainUploadPolicy.localOnly` skal bevares. Backup/import, synkaktivering,
auth-endringer, backendmigrasjoner og produksjonsutrulling inngår ikke.

Den opprinnelige maskotarbeidskopien har parallelle, ucommittede endringer. Før kodearbeid må valgt
branch og baseline bekreftes, og overlapp med aktive skrivere avklares.
Ingen andres endringer skal tilbakestilles, stages eller inkluderes utilsiktet.

## 1. Skill lesefeil fra tom historikk

**Prioritet:** først. **Grovt anslag:** 2–4 arbeidsdager.

### Implementering

1. Reproduser feil mot en disponibel SQLite-fil. Kontroller både mislykket
   prepare og avbrutt lesing der praktisk. Regresjonen skal vise at feilen
   ikke blir formidlet før rettingen.
2. Start med `LocalStore.getAllLogs` og `getLogs`. Kontroller prepare og
   avsluttende `SQLITE_DONE`, og formidle feil i stedet for å returnere delvis
   eller tom historikk. Avklar også håndtering av ugyldige lagrede rader:
   de skal ikke forsvinne lydløst fra resultatet.
3. La `DatabaseService` formidle lesefeil og utilgjengelig lager. Fjern
   tomliste-fallback for de berørte kallene. Bruk eksisterende feiltyper når
   de dekker behovet.
4. Oppdater `FoodLogRepository` og direkte berørte kallere/testdobler.
   Kartlegg faktisk bruk før signaturendring; unngå en varig parallell
   lesemetode som fortsatt skjuler feil.
5. Oppdater berørte ViewModels: førstegangsfeil gir feilstatus og nytt forsøk;
   oppdateringsfeil beholder siste vellykkede data for samme profil og kontekst.
   Ved profil-/datobytte skal gamle data ikke framstå som den nye kontekstens.
6. Bruk eksisterende feilkomponenter og norske meldinger. Ikke vis nullsummer
   eller tomtilstand som om lesingen var vellykket. Ingen sensitive data i
   diagnostikk.

**Berørte filer:** `LocalStore.swift`, `DatabaseService.swift`,
`FoodLogRepository.swift`, direkte berørte repositories/ViewModels/views og
deres tester. Eksakt kallersett fastsettes med referansesøk før implementering.

**Ferdig når:** vellykket tom lesing, lesefeil, utilgjengelig lager og
mislykket oppdatering kan skilles; retry virker; profil-/datobytte er trygt;
lagring og hendelsestransaksjoner er bevart.

**Minste kontroll:** regresjon før/etter, målrettede lagrings- og ViewModel-tester,
berørte logging-/batchtester samt én UI-kontroll av feil → retry → historikk.
Ingen reset av ordinært applager.

**Skills:** offline-sync, ios-swiftui, nutrition-privacy; product-design ved
endret feilpresentasjon.

## 2. Gjør en liten brukertestrunde

**Prioritet:** etter stabil kandidat fra trinn 1; forberedelse kan gjøres tidligere.
**Anslag:** 1–2 arbeidsdager, eksklusive rekruttering og venting.

- Rekrutter omtrent fem relevante iPhone-brukere. Inkluder variasjon i
  erfaring og tilgjengelighetsbehov når mulig. Antallet er pragmatisk,
  ikke et grunnlag for statistisk generalisering.
- Bruk syntetiske matvarer, profiler og oppgaver. Deltakerne trenger ikke
  dele egen mathistorikk. Ingen ny telemetri eller opptak som standard.
- Test uten veiledning: søk og mengdevalg, ukjent strekkode, feilretting,
  lagret måltid, offline-lagring og gjenåpning.
- Registrer fullført uten hjelp, tidsbruk, feil og nøling. Definer start/slutt
  for hver oppgave på forhånd. Skill observasjon fra vår tolkning.
- Prioriter funn etter konsekvens og gjentakelse. Velg høyst tre konkrete
  forbedringer. Behold resten som oppfølging i eksisterende arbeidsoversikt.

**Ferdig når:** hver oppgave har dokumentert resultat, og de valgte problemene
har evidens, ønsket adferd og akseptansekriterier. Hvis deltakere ikke er
tilgjengelige, markeres runden som ventende; egen QA erstatter ikke brukertesting.

**Skills:** product-review og product-design. Ved sensitiv datainnsamling må
opplegget vurderes særskilt før gjennomføring.

## 3. Modellér én risikofylt flyt og tett relevante testhull

**Prioritet:** etter trinn 1; kan gjøres mens brukertesting venter.
**Anslag:** 1–2 arbeidsdager for én avgrenset flyt.

Start med manuell registrering/utkast, med mindre ferske funn peker på en
mer risikofylt flyt. Helse-eksport og maskot tas når de berøres, uten en
samlet omskriving nå.

- Beskriv eksisterende tilstander og hendelser med ett lite tilstandsdiagram
  i relevant eksisterende funksjonsdokument.
- Ta med avbrudd, bakgrunn, gjenåpning, lagringsfeil, gjentatte trykk og
  profilbytte. Skill ønsket oppførsel fra faktisk oppførsel.
- Sammenhold modellen med eksisterende tester. Legg bare til manglende,
  risikorelevante kontroller; ikke dupliser dekket adferd.
- Bruk beslutningstabell/grenseverdier der kombinasjoner krever det, for
  eksempel gyldig/ugyldig mengde, kjent/ukjent enhet og nett tilgjengelig/av.
- Endre state-representasjon bare dersom konkrete ugyldige kombinasjoner
  eller vedlikeholdsproblemer krever det. Bruk funksjonens ViewModel.

**Ferdig når:** modellen samsvarer med avtalt oppførsel, relevante overganger
har kontroll, og observerte feil har regresjon før/etter retting.

**Skills:** ios-swiftui, offline-sync ved utkastlagring og nutrition-privacy
ved mengde-/næringsgrunnlag. Product-review ved foreslått scopeendring.

## 4. Rett observerte brukerproblemer og kontroller tilgjengelighet

**Prioritet:** funnstyrt. **Anslag:** settes etter trinn 2; ingen samlet pris
før problemene er kjent.

Ta én av de høyst tre valgte forbedringene om gangen: produktvurdering →
liten designendring → implementering → målrettet kontroll → kort retest.
Gjenbruk komponenter og semantiske tokens. Bevar bunnmenyklaring.

Kontroller hele berørte oppgaven med VoiceOver, største Dynamic Type og
redusert bevegelse, samt alternativ til kamera når skanning berøres.
Kontroller fokus, forståelige etiketter, feilretting, bekreftelse og Angre.
Simulator brukes til automatikk og layout; faktisk VoiceOver og kamera
kontrolleres på fysisk enhet. Utestående fysisk kontroll rapporteres eksplisitt.

**Ferdig når:** valgt problem er løst etter akseptansekriteriene, berørte
regresjoner består og oppgaven kan fullføres i relevante tilgjengelighetsmoduser.
Retest med brukere når tilgjengelig; manglende retest er et verifiseringshull.

**Skills:** product-review, product-design, ios-swiftui, relevante fag-skills
og qa-release.

## 5. Reduser kobling der arbeidet avdekker et konkret behov

Dette er løpende arbeid i små leveranser, ikke en egen stor refaktorering.
Første uttrekk estimeres først når ansvar og berørte tester er valgt.

- Trekk ut ett ansvar i HomeView eller LocalStore når det gir enklere
  endring, test eller forståelse. Filstørrelse alene er ikke nok.
- Behold feature-state i ViewModel, rene beregninger uten IO og injeksjon ved
  datagrenser. Bruk eksisterende beregningskode fremfor nye parallelle varianter.
- Behold transaksjonskoordineringen når lagringskode deles.
- Hold refaktorering og synlig adferdsendring reviewbare separat der praktisk.

**Ferdig når:** samme adferd består i berørte tester, ansvaret er tydeligere
og endringen følger arkitekturprinsippene. Ved lagringsendring kontrolleres
rollback og atomisk domene-/hendelsesskriving.

## 6. Samle kandidatbevis før neste release

**Anslag:** 0,5–1 arbeidsdag for sammenstilling, pluss manglende QA.
Gjenbruk kandidatoversikten fra eksisterende utbedringsplan.

- Knytt resultatene til faktisk commit og eventuelle lokale endringer,
  scheme/byggtype, enhet/OS, dato og resultatsted.
- Avstem eksisterende testbevis mot endret kode. Kjør berørte kontroller;
  full suite/build krever konkret grunn eller gjeldende releaseport.
- Gjør en avgrenset sikkerhetsvurdering av endrede dataflyter: profilisolasjon,
  ekstern input, uønsket deling, logger og nye avhengigheter. Registrer konkrete
  funn, uten å innføre et nytt generelt sikkerhetsrammeverk.
- Kontroller fortsatt lokal lagring uten nett, omstart, kilde/enhet,
  næringssnapshots og at domeneopplasting er sperret.
- Oppdater bare relevante status-/test-/funksjonsdokumenter. Rå logger og
  QA-opptak holdes utenfor repoet.

**Ferdig når:** relevante porter har kandidatbundet bestått resultat eller
en tydelig blokkering. Go/no-go gjelder bare verifisert scope; utrulling
krever separat avklaring. Brukeren håndterer releasearkivet.

## Gjennomføringsregel og samlet prioritering

Start med trinn 1. Forbered trinn 2, og gjør trinn 3 hvis rekruttering venter.
La brukertestfunn styre trinn 4. Trinn 5 følger berørte endringer; trinn 6
samler bevis før release. Basispakken er grovt 4,5–9 arbeidsdager før
funnstyrte UX-rettelser, eventuell refaktorering og resterende fysisk QA.
Anslagene er planleggingsrammer, ikke leveringsløfter.

For hver kodeleveranse: avgrens scope og ferdigkriterier, skriv relevant
regresjon, implementer, kjør minste meningsfulle kontroll etter `docs/testing.md`,
og gjennomgå diff mot `docs/architecture-principles.md`. Kontroller
avhengighetsretning, local-first, transaksjoner, eierskap og testbarhet.
Ingen implisitt utvidelse av scope eller arkitekturavvik.

## Faktisk verifisering av denne gjennomføringen

Grunnlag: main `068f24d` med endringene i LoggingDraftTests og de tre
plandokumentene i denne leveransen. Ingen produksjonskode er endret.

- `xcodebuild build-for-testing -project MatLogg.xcodeproj -scheme MatLogg
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/MatLoggIN2000QA
  CODE_SIGNING_ALLOWED=NO` bestod. App, enhets- og UI-testtargets kompilert,
  inkludert de nye utkasttestene. Dette er ikke en iOS-runtime-kjøring.
  Logg: `/tmp/matlogg-in2000-build.log`.
- Eksisterende midlertidig macOS-harness: `swift test --package-path
  /tmp/matlogg-debt-core` bestod med 78 tester i 11 suiter. Logg:
  `/tmp/matlogg-in2000-core.log`. 36 produksjonsfiler og ni testfiler er
  byte-identiske med main; harness har plattformtilpasninger i
  ProductRepository/ProfileFavoritesViewModel. Harness laster ikke den nye
  utkasttestkoden og verifiserer ikke iOS/UI, full app eller release.
- `git diff --check` bestod; den nye planfilens whitespace og sluttnyline er
  kontrollert separat. Nye testmetoder bruker syntetiske profiler og en
  injisert repository-dobbel uten nettverk eller domeneskriving.
- Oppfølging: fysisk iPhone 17 / iOS 27.3 ble tilgjengelig. Alle 13 utkast-
  testmetoder (14 utførelser) og én feil/retry-UI-test bestod. Utkastets
  stor-tekst-UI-test feilet under inntasting/fokus og senere testopprydding;
  gjenopprettingsdelen er ikke bekreftet. Forsøksvise UI-testendringer er
  fjernet. Se «IN2000 — fysisk QA» i testing.md for resultater og neste steg.
  Manuell VoiceOver og deltakertesting er fortsatt ikke utført.

Arkitekturreview: endringen tilfører bare testdekning og dokumentasjon.
Avhengighetsretning, lokal lagring, transaksjoner, eierskap, kilde/enhet og
opplastingspolicy i produksjonskode er uendret. Ingen arkitekturavvik.
Skills brukt: product-review, product-design, offline-sync, ios-swiftui,
nutrition-privacy og qa-release (instruksjoner lest i denne chatten).
Ingen commit, push, arkiv eller utrulling er utført.
