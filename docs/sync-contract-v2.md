# Loggsynk v2 – utviklingskontrakt

Dato: 2026-11-17. Implementert for isolert utvikling/testing; ikke aktivert i
appen eller produksjon. Erstatter ikke dagens v1-flyt for andre datatyper.
Overordnet scope: [skylagring og synk](cloud-sync-v2.md).

## Innganger og porter

Autentiserte PostgREST-RPC-er:

- `log_sync_head_v2()` → `{owner, historyEpoch, cursor}`.
- `push_log_v2(mutation: JSON)` → `{eventId, status, change, historyEpoch}`.
- `pull_logs_v2(after_cursor: bigint, history_epoch: uuid)` → `{owner, changes, cursor, historyEpoch}`.
- `begin_log_bootstrap_v2(snapshot_id: uuid, expected_epoch: uuid)` → fast manifest.
- `read_log_bootstrap_v2(snapshot_id: uuid, page_offset: integer)` → en side fra snapshotet.

Lesing uten epoke og skriving uten `historyEpoch` avvises. Tidligere interne
funksjoner uten epokekontroll har ikke lenger execute-grant til klientrollen.

Offentlige SQL-wrappere er security invoker. Implementasjonen ligger i
`matlogg_internal`; data ligger i private tabeller uten klientgrants, med RLS.
Alle innganger krever aktiv konto, globalt `log_sync_v2_enabled=true` og
administrativt opprettet eieradgang med `enabled=true`. Ingen bruker kan melde
seg selv inn gjennom disse RPC-ene. Migrasjonen oppretter avslått globalport;
verken eksisterende kontoer eller klienter aktiveres.

V1-RPC-implementasjonen avviser alle hendelser fra en eier som er registrert i
v2, også når eierens v2-adgang er midlertidig deaktivert. `V2_REQUIRED` hindrer
at en gammel skriver omgår revisjonskontroll. V1-hendelser beholdes lokalt;
ingen automatisk omskriving eller replay av historisk kø innføres.

## Mutasjon

```json
{
  "eventId": "uuid",
  "deviceId": "uuid",
  "entityId": "uuid",
  "schemaVersion": 2,
  "historyEpoch": "uuid",
  "type": "log.upsert",
  "baseRevision": 0,
  "payload": {"log": "FoodLog object", "product": "Product snapshot object"}
}
```

`log.delete` har ingen payload (manglende eller null). `log.upsert` inneholder
hele FoodLog og et tilhørende produkt-snapshot. Eksemplets plassholderstrenger
er ikke gyldig payload. Ingen private bilder eller bilde-URL-er inngår.
Historisk produktinformasjon tilhører loggaggregatet; den overskriver ikke
andre profilers brukerprodukter eller den felles katalogcachen.

Den foreløpige loggpayloaden bruker modellens camelCase-felt. Alle datoer er
numeriske sekunder siden 2001-01-01 UTC (Foundations referanseepoke), ikke
Supabase-SDK-ets ISO-standard. `SupabaseCloudLogTransport` fryser JSON med egen
encoder og dekoder responsdata med tilsvarende decoder. Kilde, datodag,
registreringstid, enhet og desimalverdier skal ikke utledes fra hverandre.
Dette formatet er eksplisitt v2; senere modellendringer krever ny vurdering av
bakoverkompatibilitet. Ukjent enum eller ugyldig modell skal stoppe siden uten
lokal delvis import eller markørflytting.

Serveren begrenser JSON-mutasjonen til 64 KiB, validerer identiteter,
kontraktsversjon, kjernedata, kilde, enhet, porsjonsgrunnlag og produktmetadata.
Eier fra tokenet må samsvare med loggens eier; klientfelt erstatter ikke token.
Serverrevisjoner gjelder hele loggaggregatet, inklusive produkt-snapshot.

## Transaksjoner og retry

Inbox/kvittering, aggregat, revisjon og endringslogg skrives i samme
Postgres-transaksjon. Event-ID er globalt unik. Identisk JSONB og samme eier
returnerer tidligere kvittering; endret innhold eller annen eier avvises med
`EVENT_ID_COLLISION`. En konfliktkvittering bevarer også hele mutasjonen.

En lås per eier serialiserer revisjonstildeling og commit. Revisjoner er en
monoton eiersekvens, ikke et klokkeslett eller en ubeskyttet SQL-sekvens.
Separate entiteter beholder egne siste revisjoner fra denne sekvensen.
`pull` gir maksimalt 100 endringer i stigende rekkefølge. Neste markør er siste
returnerte revisjon; tom side beholder forespurt markør. Negativ eller fremtidig
markør avvises. Endringslogg, kvitteringer og slettemarkører komprimeres eller
slettes ikke i denne leveransen.

SQLite skjema 10 innfører separate v2-tabeller; skjema 11 legger til epoke,
vedvarende bootstrap-plan, staging og lokale gjenopprettingskandidater. `saveCloudLog` og
`deleteCloudLog` lagrer domenet og en v2-hendelse atomisk, uten v1-hendelse.
SQLite-skjema 12 lagrer kontobundet aktivering. Vanlige appskrivere bruker
v2 atomisk ved aktivt valg og eksplisitt lokal testpolicy; øvrige kontoer
fortsetter med dagens lokale/v1-skriving.
Første hendelse per entitet får baseRevision fra serverversjonen brukeren har
lokalt ved skriving. Senere hendelser venter på forgjengeren og får grunnlaget
fra dens ACK i samme lokale transaksjon, før en ny pull kan endre serverstate.
Dette hindrer at gjenopptakelse eller bootstrap stilltiende rebaserer en
usendt lokal redigering på en nyere, usett serverversjon.
Timeout og prosessomstart beholder event-ID, innhold og frosset revisjon.
Andre entiteter kan fortsette når én entitet er i konflikt.

Mottatt side og nedlastingsmarkør skrives atomisk. Feil på en senere endring
ruller hele siden tilbake. Fjernendringer lager verken v1/v2-outboxhendelser
eller Helse-eksport. Egne nye lokale handlinger beholder ordinær Helse-adferd.
Ventende lokale endringer beskyttes mot overskriving, og produkt-snapshot for
siste lokale kandidat kan leses gjennom v2-lagerets aggregatmetode.

## Konflikter

- Ny logg har base 0. Oppdatering krever aktuell entitetsrevisjon.
- Ulik revisjon ved upsert gir `status=conflict`, med serverversjonen i `change`.
  Ingen ny domeneendring; begge kandidatene beholdes.
- Sletting vinner over samtidig redigering og oppretter en varig tombstone.
  En oppdatering kan aldri gjenopplive samme ID etter sletting.
- Nedlastet sletting skjuler lokal registrering, men konfliktkandidaten beholdes
  i outbox. En senere bevisst nyregistrering må få ny ID.
- Konflikt blokkerer senere opplastinger for samme ID, ikke andre ID-er.

Koordinatoren returnerer `CloudLogSyncResult` med markør, eksplisitte
konflikter og separate gjenopprettingskandidater (`recovery`). Kandidat-API-et viser lokal mutasjon, den opprinnelige
konfliktkvitteringen og nyeste kjente servertilstand. UI tilbyr eksplisitte
konfliktvalg. Ingen automatisk konfliktvinner er innført.

Feil som ugyldig input, deaktivert synk, ugyldig markør og kollisjon returneres
som RPC-feil. Det finnes ikke en bakgrunnstimer i denne koordinatoren. Køen
beholdes ved feil for neste eksplisitte kjøring. Den lar ikke feil fremstå som
kvittert opplasting. Gjeldende eierskap og en kjøringsgenerasjon sjekkes etter
hvert nettverkskall; svar etter kontobytte anvendes ikke.

## Historikkepoke og førstegangsoverføring

Hver eier har en servergenerert UUID-epoke. Klienten sjekker head før den sender
noe, og både mutasjoner, kvitteringer og nedlastingssider er epokebundet.
Serveren låser samme eierrad under sjekk og bruk, slik at epokebytte ikke kan
snike seg mellom validering og skriving. En gammel eventkvittering åpner ikke
for replay i en ny epoke. PostgRESTs gamle én-parameters lese-RPC sperres.

`transferHistory` krever et eksplisitt valg:

- `downloadOnly`: last ned; ikke last opp eksisterende lokal historikk.
- `includeLocalHistory`: ta med gjeldende lokale verdier fra det valgte lokale
  snapshotet, med nye event-ID-er. V1-køen leses ikke som hendelseskilde og
  endres ikke. Valget kan også gjøres senere i samme epoke etter downloadOnly.

Et nytt klientlager kan gjenopprettes med `sync`, som bruker downloadOnly når
ingen epoke er kjent. Server- og klientportene må allerede tillate skybruk;
innlogging alene aktiverer fortsatt ikke dette. Profil har et eksplisitt
aktiverings-/historikkvalg. `transferHistory` fullfører import og kølegging, ikke opplastings-ACK;
kalleren må deretter kjøre `sync` før opplasting kan bekreftes.

Serveren materialiserer et immutable snapshot av nåværende entiteter inklusive
slettemarkører. Manifestet har snapshot-ID, eier, epoke, antall og upperCursor.
Eierradlåsen beskytter både telling og materialisering. Nye endringer etter
snapshotet hentes som deltaer fra upperCursor. Sidene har inntil 100 entiteter
sortert på stabil ID; offset brukes bare mot det uforanderlige snapshotet.
Samme begin-ID gir samme manifest ved retry. Snapshot gjelder i 24 timer;
maksimalt ti aktive snapshots per eier. Utløpte og gamle epokers caches ryddes
ved ny begin. Dette er caches, ikke historiske brukerbackuper.

Lokalt fanges valgt historikk og en plan atomisk før nettverk. Sidene valideres
og stages i SQLite med vedvarende offset. Ingen delvis serverhistorikk vises
før hele importen er validert. Ved fullføring skrives entiteter, epoke og
upperCursor atomisk. Nettverksavbrudd beholder plan og offset. Konto- eller
epokebytte kan ikke anvende et svar i feil kontekst. Utløpt snapshot avbryter
bare staging; en ny kjøring må opprette et nytt snapshot. Et eksplisitt annet
historikkvalg under en pågående overføring avvises med historyChoiceMismatch;
kalleren må avbryte den gamle planen før det nye valget tas i bruk. Automatisk
resume viderefører det tidligere, lagrede valget.

Eksisterende lokal historikk overskrives ikke ved import. Ulike ID-er bevares.
Ved eksplisitt historikkopplasting av samme ID med forskjellig innhold brukes
base 0 slik at serveren rapporterer konflikt; ingen skjult overskriving eller
likhetsgjetting på matnavn/tidspunkt. Ved downloadOnly beholdes ulik lokal
historikk som egne recovery-kandidater. Serverens tombstone kan skjule lokal
logg, men den lokale kandidaten beholdes for gjennomgang. Manglende nødvendig
produktgrunnlag stopper importen fremfor å konstruere næringsverdier. Eldre
logger uten enhet bruker den allerede dokumenterte gram-standarden; manglende
næringskilde forblir ukjent.

Ved endret epoke rebootstrapper klienten fra et nytt snapshot. Gamle
outboxhendelser (inklusive usendte slettinger og tidligere konflikter) beholdes
med original identitet, payload og epoke i status recovery. De sendes ikke på
nytt og rebaseres ikke automatisk. Lokale verdier som avviker eller mangler på
den gjenopprettede serveren bevares også som recovery. Vanlig redigering eller
sletting av slike uavklarte ID-er avvises med historyReviewRequired, slik at en
ny handling ikke utilsiktet omgår nødvendig gjennomgang. Egne nye ID-er kan
fortsatt registreres og synkroniseres gjennom den separate v2-skriveren.

## Eksplisitte konflikt- og recoveryvalg

`CloudLogReview` fanger epoke, siste nedlastede serverversjon, alle lokale
hendelser, recoverydata og faktisk lokal logg. Bekreftelsen sammenlignes med
en ny lesing i samme SQLite-transaksjon som valget. Endrede verdier, nye
hendelser, epokebytte og pågående bootstrap avviser gamle bekreftelser.

«Bruk skyversjonen» forkaster de gjennomgåtte lokale endringene og bruker
nedlastet serververdi, inkludert sletting/fravær. «Bruk mitt lokale valg»
erstatter hendelsene med én ny event-ID i gjeldende epoke, basert på siste
lokale verdi eller sletting og den gjennomgåtte serverrevisjonen. En logg
med server-tombstone kan bare beholdes som en kopi med ny logg-ID/base 0.
Dette omgår aldri tombstonen. Senere serverendringer gir ny CAS-konflikt.
Valget og domene/outboxendringene er atomiske; valg alene gjør ingen nettverks-
opplasting. Urelaterte ressurser og andre eieres køer endres ikke.

Debug-siden Profil → Matlogger i skyen bruker View → ViewModel → Repository
→ koordinator/lager/transport. Bare HTTP loopback-konfigurasjon får transport
ved app-roten, og launch-argumentet `--enable-cloud-log-sync` kreves.
Debug-roten må også velge `DomainUploadPolicy.integrationTesting` eksplisitt;
repository-fabrikkens standard `localOnly` sperrer overføring før IO.
Aktivering skjer etter eksplisitt historikkvalg og vellykket bootstrap.
Et eksisterende aktivt valg kan forsøke synk ved innlogging/forgrunn, lokal
commit eller gjenopprettet nett. Innlogging uten et slikt valg laster ikke opp. Kontobytte ugyldiggjør bekreftelser og forsinkede UI-resultater.

**Driftskrav:** Etter en reell serverrestore eller omskriving av historikken må
operatøren rotere history_epoch for alle berørte eiere før trafikken åpnes.
En restore av hele databasen gjenoppretter også de gamle UUID-ene; Denne implementasjonen mottar ikke automatisk varsel om restore. Protokollen kan ikke
oppdage en glemt rotasjon når gamle markører fortsatt ser gyldige ut.
Integrasjonstesten simulerer både tilbakerullet revisjon og eksplisitt rotasjon
for en syntetisk eier i disponibel lokal QA. Hosted restore er ikke utført.

## Videre porter

Denne leveransen er fortsatt logg-only, ikke komplett skybackup. Før brukerpilot
gjenstår pilot-/serverlivssyklus og servergodkjenning, øvrige
aggregater/bilder, retensjon og en demonstrert operativ backup-/restore-rutine.
Produksjon forblir localOnly. Release oppretter ikke v2-transport/koordinator.
Debug kobler bare eksplisitt aktivert testing til lokal Supabase. Implementert kontrakt og
lokale tester er ikke godkjenning til å endre denne policyen.

## Aktivering, lokale skriveruter og deaktivering (skjema 12–13)

Valget og enhetsidentiteten lagres per eier i cloud_log_connections. Runtime-
porten er avslått som standard og åpnes bare av eksplisitt testpolicy ved
komposisjon. Et lagret aktivt valg åpner derfor ikke opplasting i Release.
prepare setter først forbindelsen av, slik at skriveruter under bootstrap
bevarer endringer som recovery; etter vellykket import aktiveres forbindelsen.
Vanlige enkelt-/batchskrivere, sletting og utkastfullføring skriver logg og
v2-outbox i samme SQLite-transaksjon uten ekstra v1-logghendelse.

Deaktivering er lokal og stopper nye forespørsler ved å ugyldiggjøre kjøringen.
En allerede sendt forespørsel kan være committet. Kø og senere lokale endringer
(inkludert slettinger) beholdes som recovery og blir ikke automatisk sendt ved
ny aktivering. Ingen lokal brukerdata eller serverhistorikk slettes av valget.
Off-modus tillater fortsatt lokal redigering; aktiv modus krever gjennomgang
av recovery-ID-er. V1-køen er aldri kilde for historikkopplasting.

En felles feature-ViewModel koordinerer foreground/nett/lokal-commit-triggere
uten retry-timere. Konto- og deaktiveringskontekst kontrolleres ved asynkrone
resultater. Domeneendringer varsler eksisterende loggvisning for ny lesing.
Produkt-snapshot brukes som kontobundet fallback ved lesing, uten å skrive
privat matvareinformasjon inn i en delt katalograd. Ingen realtime/polling;
endringer fra annen enhet hentes ved neste synkutløser.

Skjema 13 beholder matvaregrunnlaget i en privat cache med nøkkel eier +
produkt-ID, også etter at loggen er slettet og serverens tombstone har erstattet
aggregatet. Dette gjør eksisterende «Angre sletting» med ny logg-ID mulig for
nedlastede logger. Cachen inneholder snapshot uten bilder/URL, lager ingen
synkhendelse eller delt katalograd og slettes ved lokal kontosletting/reset.
