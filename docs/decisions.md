# Beslutningslogg

Bruk denne filen for varige valg som påvirker produktretning, arkitektur, datakontrakter eller drift. Hold hvert innslag kort: dato, beslutning, begrunnelse og konsekvens.

## 2026-09-25 – Ekstern produktkatalog er lokal cache

**Beslutning:** Open Food Facts brukes direkte fra iOS for strekkodeoppslag via
API v3 og for eksplisitt innsendt navnesøk. Treff må ha komplett kcal- og
makrogrunnlag, får stabil lokal identitet fra `kilde + ekstern ID` og caches
uten `product.upsert`. Kilde, ernæringsgrunnlag, revisjon, hentetid og relevante
datakvalitetsvarsler bevares. Brukerskapte produkter beholder eksisterende,
atomiske domene- og synkskriving.

**Begrunnelse:** Dette gir rask MVP-integrasjon og offline gjenbruk uten å gjøre
tredjeparts katalogdata til brukereid synkdata. Eksplisitt navnesøk respekterer
Open Food Facts' lavere søkerate, og manglende ernæring gjettes ikke som null.

**Konsekvens:** Synkkontraktens wire-format og schema-versjon endres ikke.
Produktdetaljer viser datakilde og lisenslenker. Backendfasade og bulkimport av
Open Food Facts-dump vurderes først når trafikk, søkekvalitet eller drift tilsier
at direkte klientoppslag ikke lenger er tilstrekkelig.

## 2026-09-25 – Én generisk loggføringsinngang på Hjem

**Beslutning:** Den separate raden med «Søk etter mat» og «Skann» fjernes fra
Hjem. Den vedvarende «Loggfør»-handlingen er den generiske inngangen til søk,
skanning og manuell registrering. Legg-til på måltidskort og personlige
hurtigvalg beholdes fordi de gir henholdsvis måltidskontekst og en kortere
gjenbruksflyt.

**Begrunnelse:** Den generiske raden dupliserte både Loggfør-arket og Søk-fanen
og konkurrerte med appens avtalte primærhandling. Fjerningen gir et roligere
Hjem uten å fjerne noen loggføringsmetode.

**Konsekvens:** Generisk skanning fra Hjem krever først trykk på «Loggfør».
Søk og skanning forblir separate, tekstmerkede handlinger i Loggfør-arket og
Søk-fanen. Ingen data-, synk- eller arkitekturkontrakter endres.

## 2026-09-17 – Normative produkt- og designdokumenter

**Beslutning:** `product-brief.md`, `design-and-user-flow.md` og
`design-system.md` er overordnede normative kilder for henholdsvis produktretning,
UX og visuelle regler. Detaljspesifikasjonene under `docs/specs/` beholdes som
utdypende krav- og referansemateriale. Kode og `current-state.md` avgjør hva som
faktisk er implementert.

**Begrunnelse:** Produkt- og designretningen var spredt over flere dokumenter
med enkelte eldre eller motstridende beskrivelser. Et tydelig hierarki reduserer
duplisering og gjør fremtidige produkt- og UI-beslutninger enklere å kontrollere.

**Konsekvens:** Varige endringer i produktløfte, informasjonsarkitektur eller
designregler oppdaterer det relevante normative dokumentet. Berørte
detaljspesifikasjoner oppdateres samtidig når avviket ellers ville skapt tvil.

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

## 2026-09-20 – Daglige mål får egen redigering og forslag som utkast

**Beslutning:** Profil åpner en egen målredigering. Beregningsveiviseren lager
et forslag som brukeren først anvender på utkastet og deretter lagrer.
Førstegangs-onboarding beholdes. Forslagsveiviseren leser eksisterende
personopplysninger, men skriver dem ikke.

**Begrunnelse:** Gjentatt redigering skal bevare egendefinerte makromål og være
raskere enn onboarding. Ingen implisitt nyberegning skal erstatte lagrede mål.

**Konsekvens:** `DailyGoalsViewModel` eier utkast, validering og lagringsstatus,
og `GoalSuggestionViewModel` eier beregningsvalgene. Avhengigheter settes sammen
ved app-roten. Eksisterende lokal transaksjon og synkkontrakt gjenbrukes;
produksjonssynk forblir deaktivert. Uendret lagring skriver ingen ny hendelse.
Skjulte mål er ikke redigerbare før brukeren endrer visningsvalget i Innstillinger.

## 2026-09-20: Gjenbruk av enkeltmåltid før målbaserte matforslag

**Beslutning:** Første utvidelse er et frivillig forslag om gårsdagens måltid
på Hjem, med mengdejustering og angre. Ingen mønstermotor, helgeregler eller
rest-kalkulator innføres. Se [scope](meal-reuse.md).

**Begrunnelse:** Direkte gjenbruk støtter rask logging og kan prøves uten nye
målberegninger, ekstra innsamling av data eller ekstern AI.

**Konsekvens:** Egen ViewModel injiseres ved app-roten. Repository får atomiske
batchoperasjoner for logger og tilhørende eksisterende synkhendelser. Ingen
synkkontrakt eller produksjonsflagg endres. Brukertest gjenstår.

## 2026-09-23 – Målforslag uten gjettet standardverdi

**Beslutning:** Automatiske kaloriforslag krever komplett beregningsgrunnlag for
en voksen: gyldig vekt, høyde, alder 18+ og valg av kvinne- eller mannvarianten
i den eksisterende Mifflin–St Jeor-formelen. Ved manglende eller annet grunnlag
viser appen et tomt felt for eget mål fremfor et aktivitetsbasert standardtall.
Forslaget omtales som et estimert startpunkt. Standard makroprofiler følger
NNR 2023-intervallene for voksne.

**Begrunnelse:** Et generelt enkelttall og en udokumentert kjønns-/formelkonstant
ga falsk presisjon. Makroprofilen merket «anbefalt» lå samtidig utenfor nordiske
referanseintervaller for protein. Den nye avgrensningen er ærligere uten å gjøre
MatLogg til et medisinsk rådgivningsprodukt eller samle inn flere sensitive data.

**Konsekvens:** Brukere under 18 og brukere uten støttet beregningsgrunnlag kan
fortsatt angi egne mål eller bruke appen uten synlige mål. Eksisterende lagrede
mål, local-first-lagring og synkkontrakt endres ikke. Beregningen er ikke
tilpasset graviditet, amming eller medisinske ernæringsbehov.

## 2026-09-23 – Ikke-modal bekreftelse etter matlogging

**Beslutning:** Den modale mini-kvitteringen erstattes av en kompakt melding med
vare, mengde, måltid, «Lagret på enheten» og Angre. Meldingen forsvinner etter
fire sekunder. Ved strekkodeskanning fortsetter kameraet automatisk.

**Begrunnelse:** Kvitteringsarket gjentok informasjon brukeren nettopp hadde
kontrollert og avbrøt en hyppig handling. Den kompakte bekreftelsen gir trygghet
og feilretting uten å legge inn et ekstra steg.

**Konsekvens:** «Skann en til», «Legg til igjen» og «Lukk» fjernes fra
bekreftelsen. Angre bruker eksisterende local-first-sletting og synkhendelse;
datamodell, synkkontrakt og backend endres ikke.

## 2026-09-24 – Fail-closed auth og brukereid synk-idempotens

**Beslutning:** Backend krever eksplisitt `JWT_SECRET` ved oppstart. Den kjente
utviklingsverdien avvises i produksjon, og dev-login krever et eksplisitt flagg
og kan aldri aktiveres med `NODE_ENV=production`. Replay av en synkhendelse
bekreftes bare når eksisterende inbox-rad eies av samme bruker.

**Begrunnelse:** En glemt miljøvariabel eller et åpent dev-endepunkt skal ikke
kunne gi tilgang til produksjonsdata. Idempotens skal heller ikke kunne bekrefte
en event-ID på tvers av brukere.

**Konsekvens:** Alle miljøer som starter API-et må konfigurere `JWT_SECRET`.
Lokale miljøer må i tillegg velge `DEV_LOGIN_ENABLED=true` dersom dev-login
skal brukes. Synkkontraktens wire-format og schema-versjon forblir uendret.

## 2026-09-24 – Lagrede måltider som eget aggregat

**Beslutning:** Et navngitt lagret måltid er en egen brukereid mal med
matvarer, mengder, næringssnapshot og kilde. Bruk av malen oppretter nye,
selvstendige logger; endring av malen påvirker aldri historikk. Første versjon
opprettes fra et allerede registrert måltid og er ikke en oppskriftsbygger.

**Begrunnelse:** Dette gir rask, eksplisitt gjenbruk uten å blande permanent
brukerinnhold med det midlertidige forslaget «fra i går» eller utvide til
oppskrifter og måltidsplanlegging. Snapshotet hindrer stille endring av tidligere
godkjent næringsgrunnlag.

**Konsekvens:** Lokalt skjema økes til v2. Klient og backend støtter
`saved_meal.upsert` og `saved_meal.delete`, men produksjonssynk forblir av og
flerenhetsnedlasting er ikke implementert. Malens lokale skriving og hendelse er
atomisk; logging fra malen gjenbruker eksisterende atomiske loggbatcher.

## 2026-09-26 – Mengdeenhet bevares for væsker

**Beslutning:** Produktets dokumenterte grunnlag kan være per 100 g eller per
100 ml. Logger, gjenbruk, lagrede måltider, eksport og synkhendelser bevarer
`g` eller `ml`. Eldre data uten enhet tolkes som gram. Historiske wire-feltnavn
`grams` og `amountG` beholdes i synkkontrakt v1, men ledsages av eksplisitt enhet.

**Begrunnelse:** Open Food Facts oppgir blant annet Monster Ultra White som
500 ml med næringsverdier per 100 ml. Å vise dette som 500 g mister kildens
enhet og antyder en tetthetskonvertering vi ikke har grunnlag for.

**Konsekvens:** Backend får additive enhetsfelt med database-default `g` og
constraints for `g`/`ml`. Produksjonssynk forblir deaktivert; dersom den senere
aktiveres, må backend med enhetsstøtte rulles ut før klienter som sender `ml`.

## 2026-09-26 – Loggbok og gaffel som appikonretning

**Beslutning:** MatLoggs valgte appikonretning er konseptet med en åpen loggbok,
en gaffel integrert i bokryggen og en korallfarget hake. Ikonet bruker appens
varme krembakgrunn, dype plommefarge og korall som hovedpalett, uten ordmerke.

**Begrunnelse:** Symbolet kobler mat og loggføring direkte, og samsvarer med
appens varme, rolige og konkrete uttrykk bedre enn et generelt helse- eller
kostholdssymbol. Den enkle silhuetten kan også fungere uten tekst.

**Konsekvens:** En 1024 × 1024-master uten transparens eller ytre hjørnemaske er
lagt i appens asset-katalog og kontrollert i liten ikonstørrelse. Standardikonet
brukes også når egne mørke og tonede varianter ikke er definert.

## 2026-09-26 – IO-frie SwiftUI-renderpass

**Beslutning:** SwiftUI-views skal motta ferdig lastede presentasjonsdata og skal
ikke slå opp enkeltobjekter i SQLite fra `body` eller radberegninger. Relaterte
objekter lastes i batch gjennom repository-grensen. Hurtig input-state isoleres
fra kostbare søsken som diagrammer, bilder og lange lister.

**Begrunnelse:** Synkrone radoppslag blokkerer hovedtråden og skalerer som N+1 ved
søk og re-rendering. Bred state-observasjon gjorde også at tastetrykk bygget opp
vesentlig større view-trær enn nødvendig.

**Konsekvens:** ViewModels kan eie presentasjonsoppslag som produktnavn, mens
repositories tilbyr batchlesing. Stabil identitet og `Equatable` brukes målrettet
etter måling; `.id()` skal ikke brukes som en generell ytelsesmekanisme. Dette
endrer ingen domeneskriving, synkhendelse eller wire-kontrakt.
