# Valgfri skylagring og synk v2

Dato: 2026-11-17. Status: utviklingsspesifikasjon med isolert testet loggsynk v2; ikke aktivert
i appen eller produksjonsgodkjent. Brukeren har godkjent arbeid med planen. Gjeldende
Release-policy er fortsatt `DomainUploadPolicy.localOnly`.

## Plattformvurdering etter ny undersøkelse (2026-11-17)

Etter sammenligningen godkjente brukeren videre arbeid med Supabase på en
ny branch. CloudKit-funnene nedenfor beholdes som begrunnelse. Godkjenningen
gjelder første isolerte testflyt, ikke produksjonsaktivering eller kjøp.
localOnly og eksisterende konto-/tilgangsregler er uendret.

CloudKit har lavere direkte driftskostnad for private brukerdata: tjenesten
inngår i Developer Program, mens private data belaster brukerens iCloud-kvote.
Apples annonserte inntil 1 PB for appdata gjelder offentlig data og er ikke
privat gratislagring til hver bruker. Full iCloud-kvote må håndteres uten tap
av lokale registreringer. iCloud-konto og Supabase-/Sign in with Apple-konto
må ikke behandles som samme identitet.

CKSyncEngine støtter egen lokal persistering, så SQLite trenger ikke erstattes
med SwiftData/Core Data. Appen må selv lagre motorstate, anvende endringer,
bevare outbox og løse revisjonskonflikter. Ved iCloud-kontobytte nullstilles
motorens ventende arbeid; lokal eierisolasjon er fortsatt appens ansvar.
Synk av slettinger er ikke en versjonert backup som kan angres.

Viktig uavklart port: App Review 5.1.3(ii) forbyr lagring av «personal health
information» i iCloud. Developer Program-avtalen begrenser også bruk
av Apple-tjenester for sensitive identifiserbare helseopplysninger. Vekt, mål og personlig mathistorikk
må vurderes konkret. At data er manuelle eller krypterte er ikke dokumentert
som unntak. Ingen skriftlig avklaring fra Apple er innhentet. Dette er ikke
en konklusjon om at alle matvarer/oppskrifter er forbudt i CloudKit.

Foreløpig anbefaling: ikke velg CloudKit for hele datasettet før Apple har
avklart datadekningen. Supabase er teknisk best tilpasset dagens kontomodell,
men krever betalt drift ved anbefalt produksjonsoppsett og egne personvern-,
tilgangs- og restorekontroller. Det er ikke automatisk produksjonsgodkjent.
Brukeren har deretter godkjent Supabase-retningen; ingen kjøp er godkjent.

Primærkilder kontrollert i denne undersøkelsen:

- https://developer.apple.com/app-store/review/guidelines/#health-and-health-research
- https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- https://developer.apple.com/icloud/cloudkit/
- https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase
- https://developer.apple.com/videos/play/wwdc2023/10188/
- https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange
- https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/stateupdate

## Produkt og avgrensning

Målet er samme historikk på flere enheter og automatisk gjenoppretting etter
innlogging på en ny installasjon. Supabase videreføres; CloudKit og en separat
brukerstyrt backupfil innføres ikke som parallelle skyprodukter.
Synk av gjeldende data beskytter ikke alene mot feilaktig sletting. Operative
backuper og en demonstrert restore-prosedyre kreves i tillegg.

Lokal logging uten konto beholdes. Konto er ikke et samtykke til opplasting.
Ingen produksjonsaktivering, endret autentisering/tilgang eller kjøp av
abonnement inngår i første tekniske leveranse.

## Datadekning

| Data | Planlagt skydekning | Første tekniske test |
| --- | --- | --- |
| Matlogger | Fullt historisk næringsgrunnlag, kilde, enhet, porsjon og tilberedningsstatus | Én syntetisk logg med full roundtrip |
| Egne produkter | Brukerens grunnlag og metadata | Bare nødvendige referanser i loggen |
| Vann og manuelt registrert vekt | Egne stabile registreringer | Senere |
| Mål og lagrede måltider | Hele aggregater, inklusive måltidselementer | Senere |
| Favoritter | Stabil produktreferanse og fjerningssemantikk | Senere |
| Måltidsbilder | Private objekter og eksplisitt manifest | Senere |
| Personlige detaljer | Kun eksplisitt valgte opplysninger med avklart formål | Senere, krever personvernvurdering |
| Presentasjonsinnstillinger | Tillatt liste, for eksempel energivisning og hubvalg | Senere |
| Helse-leste målinger | Ingen opplasting | Utenfor scope |
| Helse-tillatelser, eksport-ID-er og eksportkø | Ingen overføring til ny enhet | Enhetsspesifikke |
| Tokens, synkkø og ubekreftede utkast | Ikke brukerdata som skal gjenopprettes | Enhetsspesifikke |
| Eksterne produktkataloger/cache | Ikke full kopi | Historiske næringssnapshots bevares |

Før pilot må hver datagruppe ha testet roundtrip eller tydelig synlig avgrensning.
Ingen generell påstand om komplett skybackup før bilder og øvrige annonserte
grupper faktisk kan gjenopprettes. JSON-eksport v2 er en innsynseksport, ikke
automatisk en egnet import- eller synkkontrakt.

## Aktivering og første historikk

1. Innlogging bruker eksisterende kontoflyt. Lokal eierkobling og skydeling er
   separate handlinger. Den gamle lokale profilen må ikke gjøres tilgjengelig
   for en annen konto ved et avbrutt eller gjenopptatt forsøk.
2. Vis hvilke datagrupper som lagres eksternt, leverandør, konsekvens ved
   deaktivering og valg mellom eksisterende historikk eller bare nye data.
   Ingen forhåndsvalgt opplasting. Rettsgrunnlag må avklares før pilot.
3. Backend registrerer aktivt skyvalg, versjon og eier. Den globale nødstopp-
   bryteren og en serverkontrollert adgang for piloten gjelder i tillegg.
4. Lag en konsistent lokal snapshot og en vedvarende grense for senere
   endringer i samme SQLite-transaksjon. Nettarbeidet skjer etter commit.
   Endringer mens snapshot lastes opp, beholdes i en separat v2-outbox.
5. Last opp nåværende tilstand med stabile entitets-ID-er og nye v2-event-ID-er.
   Ikke replay hele den historiske v1-køen. Gamle, slettede eller foreldede
   registreringer må ikke komme tilbake. V1-køen beholdes uten destruktiv rydding.
6. Ved historikkvalg «bare nye data» tas bare senere handlinger med. Nødvendige
   referanser/snapshots for disse handlingene følger med og forklares i valget.

Hvis kontoen allerede har data, vis antall og tidsrom lokalt og i skyen før
førstegangssammenslåing. Ulike ID-er beholdes. Ingen duplikatgjetting basert på
matnavn/tidspunkt. Samme ID med ulike versjoner følger konfliktreglene.

## Kontrakt og servermodell

V2 er en ny eksplisitt kontrakt; eksisterende `sync-events` v1 endres ikke
implisitt til toveis synk. Ingen v1-skrivevei må kunne omgå v2-revisjoner eller
skyvalg etter at kontoen deltar i v2. Før pilot kreves enten versjonsport per
konto ved alle skrivegrenser eller felles transaksjonell revisjonslogikk.

En v2-mutasjon bærer `eventId`, `deviceId`, `type`, `schemaVersion: 2`,
`entityId`, `baseRevision` og en eksplisitt typet payload. Identiteten kommer
kun fra tokenet. Første oppretting bruker `baseRevision: 0`.

Serveren lagrer per eier:

- kanonisk entitet med revisjon og eventuell slettemarkør
- uforanderlig endringslogg med typet snapshot eller sletting
- idempotenskvittering bundet til eier, event-ID og innholdsfingeravtrykk
- skyvalg, bootstrapstatus og enhetsmarkører
- bevarte konfliktkandidater for uløste samtidige endringer

Inbox, domeneskriving, revisjon og endringslogg må committes atomisk.
Gjentatt event-ID med identisk innhold returnerer tidligere kvittering;
samme ID med endret innhold avvises. Avvist konflikt må ikke kvitteres som
anvendt endring. Oppløsning er en ny mutasjon mot aktuell serverrevisjon.

`pull(cursor, limit)` returnerer ordnede endringer, neste markør og om flere
finnes. Markøren er bundet til eier, format og serverhistorikkens epoke.
Ukjent format/utløpt epoke gir kontrollert behov for ny bootstrap, ikke tomt
suksessvar. Avgrens batchstørrelse og payload før dekoding og lagring.

En database-sekvens alene er ikke en sikker nedlastingsmarkør: transaksjoner
kan committes i annen rekkefølge enn sekvensnumrene tildeles. Første løsning
serialiserer skriving og tildeling per eier med samme transaksjonslås for alle
skriveveier. `pull` må ikke flytte markøren forbi en ucommittet endring.
En monotont økende eiermarkør oppdateres i samme transaksjon.

Alle API/RPC-er og private bildeobjekter må autorisere faktisk eier, aktivt
skyvalg, slettestatus og støttet klientversjon. Token og logger må ikke inneholde
mat-/vektpayloads. Direkte RPC/Storage-tilgang må testes, ikke bare Edge-ruten.

## Nedlasting og gjenoppretting

`View → ViewModel → Repository → Service/local store/API` beholdes.
Feature-ViewModels eier brukerhandlinger; AppState koordinerer bare aktiv
kontekst. Transport og lokalt lager injiseres via små testbare protokoller.

Ren installasjon henter en konsistent bootstrap med snapshot-ID og tilhørende
endringsgrense. Sider leses fra samme snapshot; sletting under nedlasting må
ikke føre til at rader hoppes over. Serveren fryser snapshotet eller leverer
en tilsvarende dokumentert konsistensgaranti. Etter snapshot hentes deltaer.

Mottatte sider valideres og legges i et midlertidig lokalt område. Eier,
referanser, antall, format og integritet kontrolleres. Ustøttede enheter,
kilder eller ernæringsfelt skal ikke stilltiende droppes. Fullføring og markør
skrives atomisk før den nye historikken tas i bruk. Nettet holdes aldri åpent
inne i SQLite-transaksjonen.

Ved ordinær pull skrives endringer og markør i samme lokale transaksjon uten
å lage nye opplastingshendelser. Lokale ventende endringer overskrives ikke;
serverversjon og lokal kandidat holdes adskilt til konflikt er løst.
Et svar for tidligere aktiv eier forkastes ved kontobytte. Avbrutt bootstrap
gjenopptas eller startes kontrollert på nytt uten å slette eksisterende data.

## Konflikter og sletting

- Ulike ID-er bevares som separate registreringer.
- Samtidig redigering av samme ID bevarer begge kandidatene til brukeren velger.
  Klientklokke brukes ikke til skjult «siste skriv vinner».
- Sletting vinner over samtidig redigering; kandidaten kan forklares/vises,
  men gjenoppliving krever en ny eksplisitt registrering med ny ID.
- Favorittfjerning vinner over samtidig tillegging per produkt.
- Mål og lagrede måltider behandles som hele aggregater, ikke feltvis blanding.
- Slettemarkører beholdes til en dokumentert klienthorisont er etablert.
  Enheter utenfor horisonten må bootstrappe; de kan ikke replaye gammel kø.

Deaktivering stopper nye skyjobber og sperrer servermutasjoner fra gamle
enheter. Det er ikke det samme som sletting. Brukeren må kunne velge å beholde
eller slette skykopien med tydelige konsekvenser. Kontosletting må også dekke
endringslogg, konflikter, snapshots og bildeobjekter. Ved operativ restore skal
slettinger gjenanvendes før trafikk åpnes. Oppbevaringsfrister må fastsettes
før pilot; dokumentet hevder ikke at sletting fjerner eldre backup umiddelbart.

## Status i appen

Bruk eksisterende semantiske tokens. Ingen ny obligatorisk onboarding.
Profil tilbyr «Skylagring og synk» når funksjonen faktisk er tilgjengelig.

- Av: «Lagret på denne enheten».
- Ventende: «Lagret på enheten. Venter på nett» med antall ventende endringer.
- Aktiv: «Sist synkronisert …» bare etter både push og pull frem til en kjent
  servergrense. Ikke en garanti om enheter som fortsatt er offline.
- Feil: Behold lokale data, forklar retry og vis siste bekreftede synk.
- Ny telefon: vis gjenopprettingsfremdrift, avbrudd og gjenoppta.

Logging må alltid kunne fortsette offline. Tilgjengelighet, stor tekst,
VoiceOver, redusert bevegelse og klaring over bunnmenyen følger prosjektets designkrav.

## Leveranser og akseptanse

1. **Spesifikasjon:** dette dokumentet, avgrenset datadekning og kostnadsgrunnlag.
2. **Vertikal teknisk test:** én syntetisk matlogg lagres i database A med outbox,
   sendes til disponibel backend, hentes til ren database B og sammenlignes
   på ID, eier, mengde/enhet, kilde og hele næringssnapshotet. Ingen UI- eller
   produksjonskobling. Gjentatt push/pull gir én registrering, ikke to.
3. **Robusthet:** prosessavbrudd etter servercommit før ACK, etter lokal apply
   før markør, kontobytte under svar, to samtidige servertransaksjoner,
   tombstone etter offline-redigering, foreldet klient og delvis batchfeil.
   Kryssbruker-lesing, eventkollisjon og direkte RPC/Storage skal avvises.
4. **Datadekning og produkt:** øvrige aggregater, bilder, førstegangsvalg,
   konfliktvisning, kontosletting og synkstatus med målrettet QA.
5. **Pilot:** fysisk to-enhets-QA, faktisk brukerforståelse, dokumentert
   hosted restore, varsling og oppdaterte juridiske/App Store-tekster.
6. **Produksjon:** eksplisitt go/no-go. Serverutrulling før kompatibel klient;
   nødstopp bevarer kø og lokale data. Ingen destruktiv nedmigrering av v2-data.

Ved punkt 2 brukes dedikerte QA-databaser og syntetiske eiere. Ingen reset av
en eksisterende database uten bekreftet disponibelt miljø. En test med minne-
fake beviser ikke Postgres/RLS eller ekte lokal persistering.

## Drift, sikkerhet og kostnader

Planforutsetning er transportkryptering, privat lagring, RLS og leverandørstyrt
kryptering i hvile; dette er ikke et løfte om ende-til-ende-kryptering.
E2EE krever separat nøkkel-/gjenopprettingsdesign før det kan loves.
Behandlingsgrunnlag for sensitive data, databehandleravtale, region,
tilgangsstyring og backup-/loggfrister skal godkjennes før ekstern pilot.

Supabase oppgir per 2026-11-17 Pro fra USD 25/måned, med sju dagers daglige
databasebackuper. PITR prises separat fra USD 100/måned. Dette er et
budsjettgrunnlag, ikke verifisert plan for prosjektet eller et godkjent kjøp.
Compute for ekstra miljøer, lagring, bilder, trafikk og uavhengig objektbackup
må tas med. Kostnadsestimat for faktisk bruk krever brukerantall, historikk-
og bildestørrelse; ingen sum per bruker er beregnet uten disse inputene.

Databasebackup inkluderer ikke selve Storage-filene. Restore-øvelsen må derfor
kontrollere både database og objektmanifest, inkl. manglende/slettede objekter.
Foreslått startmål før pilot er RPO ≤24 timer for katastrofegjenoppretting og
RTO ≤24 timer; dette er mål som må måles og vedtas, ikke gjeldende garanti.
Vanlig enhetsgjenoppretting bruker siste serverbekreftede synk; usendte lokale
registreringer kan ikke loves tilbake ved tap av telefonen.

Kilder kontrollert 2026-11-17:

- https://supabase.com/pricing
- https://supabase.com/docs/guides/platform/backups

## Gjeldende implementasjonsgap

`SyncEngine` har bare produksjonspolicy `localOnly`. `SupabaseService` har
opplasting, ikke bootstrap/pull. V1 mangler serverrevisjon og klientens
konfliktbehandling. Historisk `localImageData` inngår ikke i synkpayloaden.
Personlige detaljer/innstillinger har ikke full kontraktsdekning. Eksisterende
`LiveSupabaseSyncTests` dekker opplasting/replay, ikke gjenoppretting til ny
lokal database. Disse forholdene må ikke beskrives som ferdige funksjoner.

## Isolert gjenopprettingsprototype

`LocalStore.restoreLogSnapshotForTesting` finnes bare i Debug. Den lagrer ett
komplett FoodLog-snapshot atomisk, uten synk- eller Helse-eksporthendelser.
Feil eier, ugyldige verdier og ulikt lokalt innhold avvises; identisk replay
er en no-op. Dette er ikke bootstrap, konfliktløsning eller komplett v2-synk.

`LiveSupabaseSyncTests.completeLogRoundtripToCleanDatabase` bruker en egen
QA-tabell fra `scripts/fixtures/log-restore-spike.sql` med autentisert RLS.
Tabellen er en immutable transportfixture uten produksjonsmigrasjon. Den
bruker hele Codable-loggen, ikke tapsfull v1-payload. Lagret logg i database A
lastes til testtabellen, leses med innlogget eier og gjenopprettes to ganger i
ren database B. Etter gjenåpning sammenlignes hele den serialiserte loggen.
Testen prøver også lesing og skriving fra en reell annen syntetisk konto.

Dette beviser transport av FoodLog, ikke en komplett brukbar dagslogg:
produktnavn, produktets øvrige næringsgrunnlag, bilder og andre aggregater må
følge en produksjonsklar gjenoppretting. V1-køen sendes ikke som snapshot;
eksisterende upload/replay testes separat i samme harness.

## Videre leveranse: loggsynk v2

Se [implementert utviklingskontrakt](sync-contract-v2.md) for konkret RPC,
SQLite-kø og konflikthåndtering. Dette erstatter QA-tabellen som transport for
den nye v2-testen, men bevarer den eldre prototypen som separat test.
Supabase-retning er godkjent av brukeren. Produksjon og app-root er uendret.
Den første leveransen dekker matloggaggregater med produkt-snapshot uten
bilder; historikk-bootstrap, øvrige aggregater og epokebundet serverrestore
står fortsatt åpne. Planens framtidskrav tidligere i dokumentet er ikke
påstander om at disse er implementert.

## Historikk og epoke – videreført 2026-11-17

Logg-only førstegangsoverføring og epokebundet rebootstrap er nå implementert
for isolert utvikling. Se siste del av [v2-kontrakten](sync-contract-v2.md).
De tidligere avsnittene om manglende epoke og logg-bootstrap er historiske
statuspunkter; øvrige datagrupper, UI/valg og hosted restore er fortsatt åpne.
Gamle, usendte hendelser flyttes til gjennomgang, ikke replay etter serverrestore.
Operatøren må rotere epoken etter restore før trafikk åpnes; dette skjer ikke
automatisk ved å gjenopprette en Supabase-backup.

## Manuelle valg i Profil – videreført 2026-11-17

Konflikt-/recoveryvalg er implementert med atomisk bekreftelse og kontroll av
utdaterte kandidater. Debug kan åpne Profil → Matlogger i skyen via
`--enable-cloud-log-sync`. Bare lokal HTTP loopback-konfigurasjon komponeres
med testpolicyen `integrationTesting`; repository-fabrikken bruker ellers
`localOnly` og sperrer overføring. Produksjon og normal appskriving er uendret.
Historikkvalg, manuell synk og valg mellom lokal/sist hentet skyversjon krever
separate bekreftelser. Dette er en utviklingsflyt, ikke ferdig automatisk backup.
Komplett aktivering/deaktivering, serverlivssyklus og ordinære v2-skrivere
gjenstår før brukerpilot.

## Kontobundet aktivering og ordinær logging – videreført 2026-11-17

Neste godkjente leveranse kobler vanlige matloggskrivere til v2 ved aktivt
kontovalg i lokalt QA-miljø. Profil tilbyr aktivering med/uten lokal historikk
og deaktivering som beholder lokale/eksterne data. Skjema 12 bevarer valg og
enhetsidentitet; av-/på-valg åpner ikke nye serverrettigheter. Klientens
testpolicy, Debug-argument og HTTP loopback kreves fortsatt.

Offline-oppretting, redigering og sletting lagres atomisk før nett. Ved avslag
beholdes endringene som recovery uten replay; reaktivering krever gjennomgang.
Synk forsøkes etter lokal commit, ved nettgjenoppretting/forgrunn og innlogging
med eksisterende aktivt valg. Dette er ikke realtime eller bakgrunnsbackup.
Øvrige datagrupper, hosted driftsøvelse, serverlivssyklus for brukerpilot og
Release-aktivering står fortsatt åpne. Se siste del av v2-kontrakten.
