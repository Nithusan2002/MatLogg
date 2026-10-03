# Produksjonsberedskap

## Aktiv releaseport: lokal app med valgfri konto

Lanseringsvalget 3. oktober 2026 er lokale domenedata uten opplasting.
Kravene under om domeneopplasting, hosted domene-backup/PITR og serverrestore
holdes som framtidig skyport og historiske funn. De blokkerer ikke i seg selv
en lokal lansering. Ingen betalt tjeneste eller serverkonfigurasjon er endret.

Lokal release krever grønne lagrings-/eierskaps-/eksporttester, oppgraderbar
SQLite, riktig tekst om datatap og eksport, samt fysisk QA av kritiske flyter.
Supabase Auth er fortsatt aktiv: DPA/SMTP, provideroppsett, kontosletting,
sikkerhet, driftsberedskap for konto og App Store-opplysninger må avklares.
Lokal modus løser ikke disse eksisterende personvernpunktene.

iCloud-/Finder-restore er uverifisert og tilbys ikke som produktløfte. JSON
kan ikke importeres. Full telefonrestore og produksjonsutrulling er eget scope.
**Go/no-go:** produksjonsutrulling er fortsatt no-go inntil de aktive
konto-/personvern- og releasekravene er lukket; teknisk lokal modus kan testes.

Dette dokumentet er den operative minimumsporten for MatLogg-pilot og senere
produksjon. Local-first gjør at logging kan fortsette når backend er utilgjengelig,
men det fjerner ikke risiko knyttet til konto, persondata, synk eller serverkopier.

## Aktiv cutover-plan

Supabase er målplattform. Staging finnes i `eu-north-1` med migrasjoner,
Edge Functions, auth callback, Vault/Cron og avslått synk-kill-switch. Opprett
senere et separat produksjonsprosjekt i samme EØS-region, og deploy kun de
versjonerte filene i `supabase/`. Konfigurer SMTP, Apple-provider, backup/PITR
og varsling per miljø. Produksjonsmiljøet i GitHub skal kreve manuell
godkjenning.

Punktene nedenfor om NestJS/Prisma gjelder legacy-backenden mens den beholdes
under piloten. Den skal ikke reaktiveres etter produksjonscutover.

## Miljøer og utrulling

- Bruk separate PostgreSQL-databaser og hemmeligheter for staging og produksjon.
- Bygg `backend/Dockerfile` med `runtime` som kjøremål. Kjør migrasjoner som en
  separat engangsjobb fra `migration`-målet før ny backend startes.
- Bruk Node.js 24 LTS som definert i container og CI; ikke rull ut på EOL-runtime.
- Sett minst `NODE_ENV=production`, `DATABASE_URL`, et tilfeldig `JWT_SECRET` på
  minst 32 tegn og korrekt `TRUST_PROXY_HOPS` for plattformen.
- La `CORS_ALLOWED_ORIGINS` være tom når bare native-klienten bruker API-et. Hvis
  webflater legges til, oppgi eksakte kommaseparerte HTTPS-origins.
- Swagger er av i produksjon. Midlertidig aktivering krever
  `SWAGGER_ENABLED=true` og tilgangskontroll i plattformen.
- Backend rulles ut og verifiseres før en klient som avhenger av den. Synkflagget
  i iOS skal forbli av til staging-portene nedenfor er grønne.

## Hemmeligheter og data

- Oppbevar databasepassord og JWT-hemmelighet i plattformens secret manager;
  aldri i image, repo, CI-logg eller mobilklient.
- Aktiver kryptering, automatiske PostgreSQL-backuper og point-in-time recovery.
- Utfør og dokumenter en restore til en separat database før pilot.
- Logger og feilrapportering skal ikke inneholde token, e-post, vekt,
  ernæringslogger, synkpayload eller andre brukerdata.
- Verifiser eksport, soft-delete, tokenrevokering og permanent purge mot faktisk
  personvernerklæring og App Store-opplysninger.

## Overvåkning og varsler

Før pilot skal plattformen samle aggregerte, ikke-sensitive målinger for:

- tilgjengelighet, 5xx-rate og p95/p99-responstid
- PostgreSQL-tilkoblinger, lagring og mislykkede migrasjoner
- antall synkbatcher, avviste hendelser og 429-svar uten payloadinnhold
- mislykket innlogging/refresh som rate, aldri identifiserende verdier

Varsle ved vedvarende 5xx-rate over 1 %, health-feil, databaseutilgjengelighet
eller rask vekst i avviste synkhendelser. Angi én ansvarlig mottaker under pilot.

## Staging-port

1. Supabase-CI er grønn: database-reset, lint, pgTAP, Deno check/lint/test og
   målrettet iOS-bygg/test. Legacy backend-CI holdes grønn fram til opprydding.
2. Produksjonsimaget starter som ikke-root og svarer på `/health`.
3. Dev-login og Swagger er utilgjengelige med produksjonskonfigurasjon.
4. Auth, eierskap, duplikatlevering, tapt ACK, delvis avvist batch og retry er
   verifisert mot staging.
5. Rate limiting gir 429 uten at vanlig synk eller token-refresh blokkeres.
6. Offentlig trafikk har delt/plattformstyrt begrensning; den innebygde
   Throttler-telleren er bare per backendinstans.
7. Produksjonsavhengigheter har ingen uavklarte critical/high-funn. Kjente funn
   i NestJS 10 krever kontrollert rammeverksoppgradering eller dokumentert aksept.
8. Backup er opprettet og restore er demonstrert.
9. Rollback til forrige image er demonstrert uten å rulle tilbake en destruktiv
   migrasjon.
10. Personvern-/App Store-tekst samsvarer med databruk og leverandører.
    Før helsedata lastes opp, er både GDPR artikkel 6-grunnlag og artikkel 9-unntak
    avklart og dokumentert. Hvis uttrykkelig samtykke brukes, er samtykke før
    opplasting og tilbaketrekking verifisert; lokal logging fungerer fortsatt.
    Apparkivet inneholder PrivacyInfo.xcprivacy og korrekte begrunnelser for
    required reason APIs. Kontroller også avhengighetenes manifester og samlet
    privacy report. Open Food Facts sin lagring er avklart for App Privacy-skjemaet.

## Pilot og nødstopp

Start med intern TestFlight, deretter 20–50 inviterte brukere. Følg feilrate,
synkavvisninger og supporthenvendelser minst én uke før bredere utrulling.
Backend kan stoppes uten å stoppe lokal logging. Supabase-funksjonen har en
serverstyrt kill switch som returnerer `503` og `Retry-After`, slik at hendelser
forblir lokale og retrybare. Produksjonssynk skal fortsatt ikke aktiveres før
resten av porten er dokumentert grønn.

Ved alvorlig feil: stans nye backenddeploys, deaktiver synkmottak hvis mulig,
bevar databasen og loggene, og rull tilbake applikasjonsimaget. Ikke reverser en
databasemigrasjon før konsekvensen for nyere data er kontrollert. Etter recovery
replayes ventende klienthendelser idempotent med opprinnelig `eventId`.

## Go/no-go

Offentlig produksjon er **no-go** til staging-porten er utført med faktiske
resultater. Å ha sjekklisten i repoet er ikke i seg selv godkjenning.

## Verifisering 2026-10-02 – synk og recovery

Kontrollert mot arbeidskopien med pågående porsjonsendringer, uten deploy.
Brukte skills: offline-sync, backend-api, ios-swiftui og qa-release.

- Isolert lokal Supabase (`matlogg-sync-readiness`, porter 5662x), med alle
  tre repo-migrasjoner: 69 pgTAP-tester bestod; SQL-lint uten funn.
- Deno 2.5.4: 10 kontrakttester bestod; check av alle tre Edge Functions
  og lint bestod. Serverimporter bruker eksplisitte, versjonerte npm-adresser
  slik at funksjonene også kan startes uten et separat importkart.
- Lokale HTTP-kontroller gjennom Auth → Edge Function → PostgreSQL bestod:
  autentisert kill switch, upload, replay med samme event-ID,
  kryssbrukerkollisjon, delvis batch-avvisning og ugyldig token. Bare syntetiske
  kontoer ble brukt, og lokal server-kill-switch ble satt tilbake til `false`.
- `bash scripts/verify-local-backup-restore.sh` bestod med syntetiske data.
  Logisk dump av `auth`, `public` og `private` ble gjenopprettet i en ny,
  separat database. Radkontrollsummer og antall samsvarte; SQL-restore bevarte
  skjema, RLS og grants uten feil. Skriptet er begrenset til QA-containeren.
  Dette beviser ikke hosted backup/PITR, Storage-backup, hemmeligheter,
  slettingshåndtering etter restore eller operativ recovery.
- Xcode kompilerte appen og testpakken, inkludert `SyncEngine` og
  `SyncRetryTests`. Kjøring av `SyncRetryTests`, `AuthViewModelTests`,
  `inFlightResetsToPending` og `retryBackoffSkipsUntilReady` ble forsøkt med
  `xcodebuild test`, deretter `test-without-building` på en separat iOS 26.5
  QA-simulator. CoreSimulator/testoppstart hang før testresultater og kjøringen
  ble avbrutt. iOS-testene er **ikke** bekreftet grønne og må kjøres igjen.
- Klientens delvise `SERVER_ERROR` følger nå retry/backoff. ACK kan bare
  ferdigmarkere hendelser fra sendt batch, og dupliserte avvisninger krasjer
  ikke klienten. Tester dekker også timeout med opprinnelig event-ID.

Read-only kontroll av `MatLogg Staging` viste `ACTIVE_HEALTHY`,
`sync_enabled=false` og bare migrasjon `20260928090000`. Vann- og
porsjonsmigrasjonene er ikke deployet. Tre Edge Functions er aktive, versjon 2.
Ingen staging-/produksjonsdata eller konfigurasjon ble endret.

**No-go for aktivering:** klient/server-versjonene må samordnes og staging
må gjennomføre samme ende-til-ende-port. Faktisk hosted backup/PITR og
restore, overvåkning/varsler og de øvrige pilotportene er ikke verifisert.
Arkitekturen er bevart: retry ligger ved infrastrukturgrensen, lokal atomisk
lagring og backendens eierskap/transaksjoner er uendret. Ingen arkitekturavvik.

## Oppfølging 2026-10-02 – staging-port gjennomført delvis

Dette erstatter tidligere uverifisert iOS-/staging-status ovenfor.

- Xcode/iOS 26.5 på dedikert QA-simulator: 19 auth-, 30 lagrings- og
  10 synktestkjøringer bestod (59 totalt i siste relevante suite-resultater).
  Tre eldre migrasjonstestoppsett ble rettet til å fjerne vann-tabellen før
  simulert downgrade og bruke siste schema-versjon. Produksjonsmigrasjoner
  ble ikke svekket. Retry testes med SERVER_ERROR og SYNC_DISABLED.
- Lokal Supabase: alle fire migrasjoner, 71 pgTAP-tester, SQL-lint og ny
  logisk backup/restore bestod.
- Staging hvwktobxgarxptefzwbq har alle fire migrasjonene og sync-events v3
  med JWT-verifisering bevart. Migrasjonshistorikken matcher repo-filene.
- Auth → Edge → PostgreSQL med syntetiske kontoer bestod: autentisert
  kill switch, upload, replay, kryssbrukerkollisjon, delvis batch og ugyldig
  JWT. Mottak ble kun åpnet kortvarig under testen; sync_enabled=false er
  bekreftet etterpå. Testkontoer og deres domenedata er ryddet bort.
- Direkte RPC kunne omgå Edge-nødstoppen. Migrasjon
  20261002190000_rpc_sync_kill_switch.sql håndhever nå samme kontroll før
  database-/inbox-skriving. Staging-kall med synk av gir status rejected og
  code SYNC_DISABLED. Auth, grants, eierskap, local-first og atomiske
  transaksjonsgrenser er bevart. Ingen arkitekturavvik.

Kommandoer: målrettet xcodebuild test for AuthViewModelTests, SyncRetryTests
og MatLoggTests; supabase migration up --local, supabase test db,
supabase db lint --local --schema public --schema private --level warning
og bash scripts/verify-local-backup-restore.sh. Staging ble oppdatert via
Supabase-connectoren; HTTP-testene brukte syntetiske kontoer og verifisert TLS.
Produksjon er ikke opprettet eller endret.

**No-go-punkter:** hosted backup/PITR og isolert hosted restore er ikke
bekreftet; dashboardet krever innlogging. Varsler/ansvarlig mottaker og
operativ recovery er ikke demonstrert. Fysisk iPhone er registrert, men
utilgjengelig; TestFlight, personvernporten for helsedata og separat
produksjonsmiljø gjenstår.

Security Advisor: app_config har RLS uten klientpolicy (tilsiktet sperring),
og sync-RPC har authenticated SECURITY DEFINER EXECUTE (tilsiktet med
identitets-/eierskapskontroller). Leaked-password protection er av og må
vurderes før pilot: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
Direkte RPC går fortsatt utenom Edge-kvoten; plattform-/databasebegrensning
må avklares og verifiseres før aktivering. Edge rate limiting alene dekker
ikke hele skriveflaten.

## Oppfølging 2026-10-03 – hosted backup og fysisk enhet

Innlogget Supabase-dashboard bekrefter at MatLogg Staging er på Free-plan,
viser «No backups», og at Free ikke inkluderer prosjektbackuper. Pro vises
fra USD 25/måned med daglige backuper beholdt i sju dager. PITR er et separat
Pro-tillegg fra USD 100/måned. Ingen abonnement eller backupinnstilling er
endret. Prisene er viste startpriser; org-plan, flere prosjekter, compute og
forbruk kan påvirke sluttsummen. Hosted restore kan ikke testes fra en
hosted backup som ikke finnes. Dette er en blocker for framtidig skybackup og krever et eksplisitt budsjettvalg;
lokal lansering tilbyr ikke serverkopi av domenedata.

Fysisk iPhone 17 er nå tilkoblet og paret, iOS 27.0, Developer Mode aktivert.
Enhetsverifisering bruker separat bundle-ID
com.nithusan.MatLogg.SyncReadinessQA for å isolere testlagring fra brukerappen.
Fysisk Xcode-kjøring av MatLoggTests og SyncRetryTests bestod: 40 tester.
Kjørte xcodebuild test mot fysisk iPhone med separat bundle-ID og eksplisitt
utviklingsteam, uten repo-endringer i signeringsoppsettet. Ingen testkall
lastet opp brukerdata, og produksjonssynk er fortsatt av. Testresultat ligger
lokalt i /tmp/MatLoggPhysicalSyncQA/Logs/Test/
Test-MatLogg-2026.10.03_07-42-45-+0200.xcresult.
Målrettet fysisk UI-test testFirstLoggingWithoutAccountAndRelaunch bestod
også: lokal logging, Angre og gjenåpning i separat QA-app. Kjørte samme
xcodebuild-oppsett med bare denne UI-testen. Resultat: 40 enhetstester + én
UI-test på fysisk iPhone, begge testkjøringer TEST SUCCEEDED. UI-resultat:
/tmp/MatLoggPhysicalSyncQA/Logs/Test/
Test-MatLogg-2026.10.03_07-45-19-+0200.xcresult.

Dette er ikke en full enhets-/TestFlight-port; låsing, nettverksbytte,
operativ varsling og hosted restore krever fortsatt egne resultater.

## Fast kontroll av strekkodedekning

Før pilot etableres et fast utvalg på 30–50 norske butikkvarer, fordelt på
meieri, brød/korn, drikke, ferdigmat, pålegg, snacks og plantebaserte varer.
Bruk faktisk strekkode fra pakken og kontroller næringsgrunnlag og enhet mot
etiketten. Test med nett og et tomt katalogcachegrunnlag; ikke slett brukerdata
for å gjøre kontrollen. Pilotansvarlig gjentar kontrollen hver måned og legger
til 5 nye varer. Dette er en manuell rutine, ikke en planlagt bakgrunnsjobb.

Før resultatene i [kontrollmalen](barcode-coverage.csv), én rad per vare og
kontrolldato. Tillatte resultater: `komplett`, `ukjent`, `ufullstendig`,
`teknisk_feil` og `avvik_mot_pakke`. Noter måleenhet og konkrete avvik. Malen
inneholder ingen ferdig kontrollerte varer; første baseline må fylles fra
faktiske pakker før pilot. Ikke før bruker-ID, skannhistorikk eller matinntak.

Rapporter komplett-treffandel, antall ukjente/ufullstendige varer, tekniske feil
og avvik separat. Tekniske feil testes på nytt før dekningen vurderes. Første
baseline brukes til å avtale pilotens dekningsmål; vi lover ikke 95 % dekning
uten måling. Ved gjentatte hull i vanlige norske varegrupper vurderes en ekstra
leverandør som en egen produktbeslutning.

## Lokal lansering: implementering og QA 2026-10-03

- App-root, shared og alternative SyncEngine-oppsett har localOnly som standard.
  Releasebygg har ingen opplastingsåpen policy; bare DEBUG-tester kan velge
  integrationTesting. Backendflagg og server-kill-switch forblir av.
- Null opplasting verifisert med transportspion for start, foreground, nett
  tilbake, manuell trigger, offline/online og kontobytte, også med flagg på.
  Ingen kølesing, in-flight/ACK/dead-letter eller retry-planlegging i lokal modus.
- Hjem, førstegangsbruk, innlogging/kontokobling og Profil forklarer lokal lagring.
  Gamle synkfeil/retry-handlinger skjules. JSON beskrives uten restore-løfte.
- Eksportens eierskap, bilder, mål-/vekt-/vann-/porsjonsdata og opprydding er testet.
  SQLite og eksportens Data Protection-attributter er verifisert på fysisk iPhone.
  Abandoned eksportfiler eldre enn 24 timer ryddes best-effort ved serviceoppstart.
- Fysisk iPhone 17/iOS 27.0, separat bundle com.nithusan.MatLogg.SyncReadinessQA:
  **76 enhetstester i seks målrettede suites, 0 feil**. Kjørte xcodebuild test
  med SyncRetryTests, ProfileTests, MatLoggTests, AuthServiceTests,
  PortionLoggingTests og WaterLoggingTests. Resultat:
  /tmp/MatLoggPhysicalSyncQA/Logs/Test/Test-MatLogg-2026.10.03_08-09-38-+0200.xcresult.
- Tre fysiske UI-flyter bestod: lokal førstegangslogging/Angre/gjenåpning,
  førstegangsbruk med AccessibilityXXXL og lokal status/eksporthandling i Profil.
  Profiltesten bestod i Test-MatLogg-2026.10.03_08-06-18-+0200.xcresult (den andre UI-testen ble deretter rettet); de to onboardingflytene bestod
  samlet i Test-MatLogg-2026.10.03_08-08-02-+0200.xcresult. Stor-tekst-feil
  ble rettet ved å flytte datatapsinformasjonen inn i den scrollbare listen.
- Simulator viste ikke iOS-beskyttelsesattributter; kontrollen ble flyttet til
  fysisk enhet. To senere simulatorbygg hang under kompilering og ble avbrutt;
  de rapporteres ikke som grønne. Endelig fysisk kontroll er grønn.
- PrivacyInfo.xcprivacy bestod plutil -lint; git diff --check er ren.

Arkitekturkontroll: policyen eies av infrastrukturen og injiseres ved roten;
AppState koordinerer tilgjengelighet, og views viser state/videresender handlinger.
Ingen ny View-IO, backend-/kontrakts-/skjemaendring eller endret auth/tilgang.
Eksisterende atomisk domeneskriving + event og eierfiltrering beholdes og testes.
Ingen nye arkitekturavvik identifisert.

Gjenstår før offentlig release: eksisterende konto-/personvern-/driftsavklaringer
og TestFlight-port. iCloud/Finder-restore på ny telefon, eierbinding uten token,
fysisk flymodus-/låseøvelse og full VoiceOver-gjennomgang er ikke utført.
Nettstatus er testet med injisert tilstand; ingen ekte helsedata ble sendt.
UI-kjøringen logger også «Invalid frame dimension» under launch; flytene bestod,
men denne visuelle runtime-advarselen skal følges opp før bred pilot.
Skykopi tilbys ikke, og ny import eller telefonrestore er ikke gjennomført.
**Go for videre lokal QA; no-go for produksjonsutrulling før aktive porter er lukket.**
