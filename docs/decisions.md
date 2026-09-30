# Beslutningslogg

Bruk denne filen for varige valg som påvirker produktretning, arkitektur, datakontrakter eller drift. Hold hvert innslag kort: dato, beslutning, begrunnelse og konsekvens.

## 2026-09-28 – Supabase erstatter egen auth- og synkbackend

**Beslutning:** Supabase Auth, PostgreSQL, RLS og Edge Functions overtar konto,
opplastingssynk og kontosletting. Synkkontrakt v1 og local-first-køen beholdes.
Staging og produksjon er separate EØS-prosjekter. E-post må bekreftes, og
Supabase kan koble Apple og verifisert e-post med samme adresse automatisk.

**Begrunnelse:** En driftet auth- og databaseplattform fjerner egen tokenrefresh,
passordlagring og nettverkstilgang til en utviklermaskin, samtidig som
eierskapsreglene kan håndheves i databasen og Edge Functions.

**Konsekvens:** `supabase/` er teknisk sannhetskilde for ny serverkode. Direkte
domene-skriving fra klienten er sperret; `apply_sync_event_v1` henter alltid
eier fra `auth.uid()`. Produksjonssynk forblir av til staging, fysisk iPhone,
backup/restore og intern TestFlight er godkjent. NestJS/Prisma beholdes kun som
midlertidig referanse fram til stabil pilot og skal ikke reaktiveres etter
produksjonscutover.

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

## 2026-09-26 – Stale-while-revalidate for strekkodeprodukter

**Beslutning:** Lokale Open Food Facts-snapshots brukes uten nettverkskall i 30
dager. Eldre snapshots vises umiddelbart og revalideres i bakgrunnen med maks ett
samtidig kall per strekkode. Etter feil beholdes snapshotet og nye forsøk utsettes
i 24 timer. Matvaretabellen-næring overskrives ikke av denne revalideringen.

**Begrunnelse:** Gjentatt logging skal være umiddelbar og fungere offline, men en
permanent cache kan skjule endringer i produsentens næringsinnhold. Periodisk,
ikke-blokkerende revalidering balanserer respons, tilgjengelighet og datakvalitet.

**Konsekvens:** Lokalt SQLite-skjema økes til v3 med indeks på produktstrekkode.
Katalogcache forblir enhetslokal og oppretter ingen synkhendelse. Historiske
logger beholder sine lagrede næringssnapshots; backend- og synkkontrakten endres
ikke.

## 2026-09-27 – Kontrollert feil ved lokal databaseoppstart

**Beslutning:** Feil ved åpning eller migrering av den lokale SQLite-databasen
skal gjøre lageret utilgjengelig uten å slette, nullstille eller erstatte
databasefilen. Appen viser en blokkerende feiltilstand i stedet for å krasje eller
fortsette mot et tomt lager. Skriveoperasjoner avvises eksplisitt.

**Begrunnelse:** Et tomt fallback-lager kan se ut som datatap og ta imot nye
endringer uten sammenheng med den opprinnelige synkkøen. En kontrollert stopp
bevarer local-first-data og gir et trygt grunnlag for senere recovery.

**Konsekvens:** `LocalStore` har kastbar initialisering, migreringer rulles fortsatt
tilbake transaksjonelt, og dekodingsfeil logges uten å endre den berørte raden.
Migreringstester dekker uversjonert database, v2→v3, rollback og ukjent nyere
skjemaversjon.

## 2026-09-26 – Felles nettverksfeil og avgrenset retry

**Beslutning:** Klientens HTTP-kall bruker eksplisitte timeouts og felles
klassifisering av offline, timeout, brutt forbindelse og ugyldig respons.
Idempotente katalogoppslag kan retries én gang ved transportfeil, kortvarig 429
og 5xx; lengre `Retry-After` vises til brukeren. Muterende auth- og kontokall
retries ikke automatisk. Synk respekterer `Retry-After` persistent.

Synkhendelser retries persistent med eksponentiell backoff og jitter. Etter fem
automatiske forsøk, eller ved permanent 4xx/eksplisitt event-avvisning, beholdes
hendelsen som `deadLetter` til brukeren velger et nytt manuelt forsøk. En timer
vekker køen ved `nextRetryAt`, og nettverksmonitoren trigger synk når forbindelsen
kommer tilbake. Produksjonssynk forblir deaktivert.

**Begrunnelse:** Brukeren skal kunne skille reelle tomme søkeresultater fra
nettverksfeil, uten at ikke-idempotente operasjoner dupliseres. Synkdata skal
aldri slettes fordi nett eller server er midlertidig utilgjengelig.

**Avgrensning:** Automatisk refresh-token og endring av sesjons-/tilgangslogikk
inngikk ikke i denne endringen; dette ble senere besluttet separat.

## 2026-09-27 – Roterende refresh-token og ett autentiseringsretry

**Beslutning:** Access-token varer som standard i 15 minutter. Ved 401 på et
autentisert kall bruker iOS et refresh-token fra Keychain, lagrer det roterte
tokenparet samlet og gjentar originalkallet høyst én gang. 403 behandles som
manglende autorisasjon og utløser ikke refresh. Ugyldig eller gjenbrukt
refresh-token avslutter den lokale sesjonen.
Vanlig utlogging fjerner lokale credentials umiddelbart og forsøker deretter å
revokere refresh-sesjonen på serveren uten å blokkere offline-utlogging.

Backend genererer kryptografisk tilfeldige refresh-tokens, lagrer bare SHA-256-
hashen og roterer tokenet atomisk ved bruk. Gjenbruk av et revokert token
revokerer øvrige aktive refresh-sesjoner for brukeren. Refresh-token varer i 30
dager og slettes sammen med brukeren. Revokerte sesjonsrader beholdes frem til
utløp for å bevare gjenbruksdeteksjon; utløpte rader ryddes ved oppstart og
deretter daglig.

**Begrunnelse:** Kortlivede bearer-tokens begrenser skadeomfanget ved lekkasje,
mens rotasjon gir en sømløs sesjon uten å gjøre muterende nettverkskall til
generelle retry-operasjoner. Ett eksplisitt retry etter vellykket refresh er
trygt for synk fordi hendelsene allerede er idempotente, og nødvendig for
kontosletting fordi første 401 betyr at domenekallet ikke ble utført.

**Utrulling:** Prisma-migrasjonen må kjøres før backend med refresh-endepunktet
rulles ut. Ny backend er bakoverkompatibel med eldre klienter; ny iOS-klient kan
logge inn mot eldre backend, men må logge inn på nytt når access-tokenet utløper
fordi eldre svar ikke inneholder refresh-token.
## 2026-09-26 – Bevar desimalpresisjon i næringssummer

- Kaloriverdier bevares som desimaltall fra per-100-grunnlag gjennom logger,
  lagrede måltider, dagsoppsummering og synk. Hele kcal er kun presentasjon.
- Porsjons- og mengdeberegning skalerer lagret snapshot gjennom én felles
  kalkulator. Redigering av en historisk logg bruker dens snapshot og enhet.
- Gram og milliliter konverteres ikke uten dokumentert tetthet. Når
  Matvaretabellen erstatter næringsgrunnlaget, settes basis eksplisitt til
  per 100 g i stedet for å arve en mulig per-100-ml-basis.
- Wire-formatet forblir schema v1 fordi heltall er en delmengde av JSON-tall;
  backend må likevel støtte desimallagring før nye klienter rulles ut.

## 2026-09-27 – Offline-garanti og ærlig synkstatus

**Beslutning:** MatLogg behandler vellykket lokal lagring som fullført arbeid og
synk som en etterfølgende kopi. Egne logger, mål, vekt, favoritter, lagrede
måltider og lokale produktdata skal kunne brukes uten nett. UI skiller mellom
lokalt lagret, ventende, automatisk retry, krever handling og bekreftet tom kø
for denne enheten.

Synkkontrakt v1 løser kun leveringsduplikater gjennom `eventId`. Den skal ikke
hevdes å løse flerenhetskonflikter eller bruke heuristikk på produkt, mengde og
tidspunkt. En senere toveis kontrakt må ha serverrevisjoner og eksplisitt
konflikthåndtering; sletting vinner over samtidig redigering.

**Begrunnelse:** Brukeren må kunne stole på at offline-data ikke er tapt, samtidig
som appen ikke lover konvergens som dagens opplastingskontrakt ikke kan levere.

**Konsekvens:** Produkttekst bruker «lagret på enheten» og presiserer at en tom
kø gjelder endringer fra denne enheten. Produksjonssynk forblir deaktivert, og
innføring av toveis synk krever ny kontraktsversjon og egne konflikt-, retry- og
flerenhetstester.

Klienten teller alle ikke-ferdige køtilstander, viser permanente feil per
hendelsestype og lar brukeren prøve én avvist hendelse på nytt uten å aktivere
alle andre. Nett tilbake omtales som et synkforsøk mens appen kjører eller ved
neste oppstart/foreground, ikke som garantert bakgrunnskjøring. Lokal
brukerbinding av køhendelser er et eget auth-/migrasjonsarbeid og en blocker før
produksjonssynk.

## 2026-09-27 – Brukerbundet lokal synkkø og karantene for legacy-hendelser

**Beslutning:** Alle nye synkhendelser lagrer en lokal `ownerUserId` i samme
SQLite-transaksjon som domenedataene. Synkmotoren kan bare hente hendelser for
aktiv autentisert bruker, og planlagte retries kanselleres ved utlogging eller
brukerbytte. `ownerUserId` er lokal rutingmetadata og sendes ikke til backend.

Ved migrering til lokalt skjema v4 settes alle ikke-ferdige hendelser uten
verifiserbar eierbinding i `quarantined`. De beholdes for sporbarhet, men kan
aldri lastes opp eller aktiveres med manuelt retry. Brukeren ser et generisk
antall i Data og synk, uten hendelsesinnhold.

**Begrunnelse:** Backend bruker bearer-tokenet som autoritativ identitet. Uten
lokal eierbinding kunne en køhendelse opprettet under én konto ellers bli sendt
etter innlogging med en annen konto. Karantene velger dataminimering og
fail-closed fremfor å gjette eierskap fra payload eller nåværende sesjon.

**Konsekvens:** Den tidligere lokale eierbindingsblockeren er lukket, men
produksjonssynk forblir deaktivert til relevante integrasjons- og
produksjonsforberedende tester er kjørt og godkjent.

## 2026-09-27 – Minste produksjonsfundament før synkpilot

**Beslutning:** Backend pakkes som et flertrinns containerimage med separat
migrasjonsjobb og en minimal runtime som kjører kompilert kode som ikke-root.
Produksjonskonfigurasjon feiler lukket ved manglende database eller svak
JWT-hemmelighet. Swagger er av i produksjon, sikkerhetsheadere er på, og auth,
token og synk har per-klient rate limits i tillegg til en global grense.

Backendendringer verifiseres i CI mot midlertidig PostgreSQL med migrasjoner,
kontrakt-, auth-, HTTP- og idempotens-/eierskapstester før runtime-imaget bygges.
Kritiske dependency-funn stopper CI. Kjente high/moderate funn i NestJS 10 må
oppgraderes eller eksplisitt risikovurderes før offentlig produksjon.

**Begrunnelse:** Local-first begrenser konsekvensen av backendnedetid, men ikke
risikoen for misbruk av auth, feil eierbinding eller tap av serverkopier. Dette
er det minste tekniske sikkerhetsnettet for en kontrollert pilot uten å låse
prosjektet til en bestemt skyleverandør.

**Avgrensning:** Endringen oppretter ikke staging, backup, alarmer eller secrets
hos en leverandør og aktiverer ikke produksjonssynk. Disse krever faktiske
verifiseringsresultater etter porten i `docs/production-readiness.md`.

## 2026-09-27 – Lokal bruk uten konto og valgfri Apple/e-postkonto

**Beslutning:** Førstegangsbruk kan fortsette med en stabil lokal profil uten
konto. Konto med Apple eller e-post/passord er valgfritt. Eksisterende lokale
data knyttes atomisk til kontoen bare etter eksplisitt bekreftelse. Utlogging
skjuler kontodata på enheten og oppretter ikke automatisk en ny identitet.

**Begrunnelse:** Kjerneverdien er local-first logging, og konto skal ikke være
en personvern- og konverteringsbarriere før den gir en tydelig brukerverdi.
Navn er derfor fjernet fra registreringen. Apple-identitet kobles ikke
automatisk til e-postkonto ved lik adresse.

**Konsekvens:** Synk v1 er fortsatt bare opplasting og markedsføres ikke som
backup, gjenoppretting eller flerenhetssynk. Produksjonssynk forblir deaktivert.

## 2026-09-28 – Kostnadsfri, lokal råvarekatalog

**Beslutning:** Appen leveres med en normalisert snapshot av Matvaretabellen og
søker denne lokalt. Open Food Facts beholdes som kostnadsfri kilde for eksplisitt
navnesøk etter merkevarer og strekkodeoppslag. Snapshotet oppdateres med en ny
appversjon, normalt årlig. Automatisk fuzzy kobling skal ikke erstatte næring på
et strekkodeprodukt med data fra en generisk råvare.

**Begrunnelse:** Dette gir norsk råvaresøk uten nettilgang, ingen løpende
API-kostnad og mindre deling av søketekst. Det unngår også at navnelikhet blir
presentert som verifisert næringsdata.

**Konsekvens:** Matvaretabellen-snapshot og ekstern katalogcache er lokal
katalogtilstand og oppretter ikke synkhendelser. Brukeropprettede produkter får
egen lokal eierbinding og følger claim/sletting fra auth-grunnlaget i forrige
commit. SQLite-skjemaet økes til v5; wire-format og synkkontrakt er uendret.

## 2026-09-29 – GS1 Data Matrix brukes bare som produktidentifikator

**Beslutning:** Skanneren støtter GS1 Data Matrix i tillegg til endimensjonale
strekkoder. Klienten trekker bare ut, validerer og normaliserer GTIN fra
Application Identifier 01 før eksisterende lokal cache og Open Food Facts-oppslag.

**Begrunnelse:** Ferskvarer kan merke produktet med GS1 Data Matrix i stedet for
synlig EAN, men MatLogg trenger bare produktidentiteten for ernæringsoppslag.

**Konsekvens:** Pakkedato, holdbarhetsdato, lotnummer og andre sporbarhetsdata
lagres eller sendes ikke. Endringen krever ingen databasemigrasjon, backend- eller
synkkontraktsendring.

## 2026-09-29 – Oda MCP utsettes som mulig fremtidig integrasjon

**Beslutning:** Oda MCP implementeres ikke i nåværende scope. Matvaretabellen og
Open Food Facts forblir gjeldende produkt- og næringskilder.

**Begrunnelse:** Oda kan senere være nyttig for eksplisitt import av konkrete
varer fra handlekurv eller ordrehistorikk, men skal ikke brukes som primær
næringsdatabase uten avklart gjenbruksrett, stabilitet, GTIN-dekning, caching og
personvernkonsekvenser.

**Konsekvens:** Ingen kode, datamodell, personverntekst eller brukerflyt endres
nå. En eventuell senere vurdering skal starte som en valgfri, brukerinitiert
integrasjon og bevare kilde, måleenhet, næringsgrunnlag og loggsnapshot.

## 2026-09-29 – Onboarding starter med trygghet og eksplisitte visningsvalg

**Beslutning:** Velkomsten komprimeres slik at kjernebudskap og handlinger er
synlige uten scrolling på en vanlig iPhone, med scrolling som fallback for liten
plass og stor tekst. Onboarding lar brukeren velge visning før mål og tilbyr en
egen vei for kun loggføring.

**Begrunnelse:** Lokal bruk og lav terskel er appens kjerneverdi. Kalorier, vekt
og mål skal være eksplisitte valg, ikke forutsetninger for å komme i gang.

**Konsekvens:** «Start uten mål», skjulte kalorier og Trygg modus oppretter ikke
et skjult mål. Automatisk estimat krever komplett, støttet grunnlag; ellers kan
brukeren supplere opplysninger, angi et eget mål eller fortsette uten mål.

## 2026-09-29 – Næringsverdier vises alltid, mål forblir valgfrie

**Beslutning:** Safe Mode og separate valg for å skjule kalorier eller mål
fjernes. Kalorier og tilgjengelige makroverdier vises konsekvent når data finnes.
Brukeren kan fortsatt velge kun loggføring uten at et mål eller personlige
opplysninger opprettes.

**Begrunnelse:** MatLoggs kjerne er mat- og ernæringslogging. En fast
næringsvisning gjør onboarding, innstillinger, målredigering og skjermhierarki
enklere, og fjerner tre overlappende presentasjonstilstander. Mål, vekt og
beregningsgrunnlag forblir eksplisitte og valgfrie, og språket skal fortsatt være
nøytralt og ikke-dømmende.

**Konsekvens:** Beslutningen erstatter tidligere Safe Mode- og visningsvalg i
dette dokumentet. Eldre lokale preferansenøkler ignoreres, og eldre mål-JSON med
`safeModeEnabled` skal fortsatt kunne leses. Lokal databasestruktur,
`goal.set`-payload, synkkontrakt og backend endres ikke.

## 2026-09-30 – Vann per glass

Vann logges som én separat registrering per glass på Hjem, med valgt dato og
profileier. Ingen antatt ml-mengde eller helsemål. Egen ViewModel/repository og
atomisk SQLite/synkkø; additive v1-typer på Supabase. Produksjonssynk forblir av.

## 2026-09-30 – Profil, personopplysninger og lokal eksport

Profil prioriterer personlige detaljer, ett redigerbart målkort og innganger
til favoritter/innstillinger. Dupliserte tallkort fjernes. Personopplysninger
redigeres som et eksplisitt utkast; fødselsdato krever valg og bekreftelse,
og lagringsfeil beholder utkastet. Vekt til beregning endrer ikke vekthistorikk
eller eksisterende mål.

Lokal JSON-eksport utvides med gjeldende mål, vekthistorikk, personlige detaljer
og favoritter. UI oppgir de eksporterte datasettene og lover ikke komplett
kontoeksport eller gjenoppretting. Eksport fra en tidligere profil forkastes
ved profilbytte, og midlertidige eksportfiler ryddes etter deling.
Rapporteringsvalg vises som utilgjengelige så lenge SDK-integrasjon mangler.
Auth, slettemekanismer, databaseskjema og synkkontrakt endres ikke.
