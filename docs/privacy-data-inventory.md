# Datakart og kontrollstatus

Oppdatert: 19. oktober 2026. Behandlingsansvarlig oppgitt av bruker:
Nithusan Krishnasamymudali. Kontakt i eksisterende erklæring:
nithusank.2002@gmail.com.

Brukeravklaringer 3. oktober: målgruppen er 16 år og eldre. Aksept av
Supabases standardvilkår inkluderer DPA, kontrollert 8. oktober (se nedenfor).
Piloten tilbyr nå bare Apple-innlogging; egen SMTP er ikke konfigurert.
Aldersgrensen er en produktbeslutning, ikke et artikkel 9-grunnlag.
Onboarding, vilkår og håndtering av eksisterende profiler under 16 må avklares
samlet før aldersgrensen regnes som implementert. Ingen profiler slettes på
grunnlag av denne beslutningen.

Dette er et teknisk arbeidsgrunnlag for behandlingsprotokoll og risikovurdering,
ikke en ferdig juridisk vurdering. Kode er undersøkt; staging er delvis
kontrollert med read-only aggregater 19. oktober. Tidligere fysiske kontroller er datert nedenfor og i
`production-readiness.md`. Full leverandørlagring og avtale-/risikovurdering
er fortsatt ikke ferdig verifisert. Alle rader gjelder
appbrukere. Juridisk vurdering må avklare ansvaret for lokal behandling separat
fra konto-/serverbehandling; «lokalt» betyr ikke automatisk GDPR-unntak.

## Dagens dataflyter

| Data / formål | Lagring og mottaker | Rettsgrunnlag / status | Lagring og sletting sett i kode |
| --- | --- | --- | --- |
| E-post, konto-ID, Apple-identitet; autentisering. Valgfritt delt Apple-navn som lokalt forslag til visningsnavn | Supabase Auth for identitet/e-post; konto-/lokal profilsnapshot og Apple-navneforslag i UserDefaults, tokens i Keychain. Apple-navneforslaget sendes ikke til Supabase av MatLogg | Erklæringen angir art. 6(1)(b); avtale og faktisk konfigurasjon må kontrolleres | Navneforslaget fjernes med lokal kontoprofil ved utlogging. Nye sletteforespørsler forsøker permanent sletting i samme kall; feil beholdes for retry hvert femte minutt. Eldre forespørsler beholder tidligere frist. Hosted sletting er historisk verifisert 7. oktober, ikke kjørt om igjen her. Full logg-/backupretensjon er uavklart. |
| Visningsnavn, fødselsdato, kjønn, høyde, vekt og aktivitetsnivå; personlige detaljer/målforslag | Profilavgrenset UserDefaults; ikke aktiv skysynk | Nødvendighet, lokal behandlingsrolle, art. 6 og eventuell art. 9 må vurderes; fødselsdato er valgfri | `DatabaseService.deleteLocalData` fjerner profilens personalDetails-nøkkel. Ingen tidsstyrt sletting sett. |
| Matlogger, vann, mål, vekt; logging og oversikt | SQLite i Application Support, med profileier; lokal synkkø | Helseopplysninger i prosjektets klassifisering; lokal behandlingsrolle og grunnlag må vurderes, i tillegg til fremtidig serverbehandling | Eieravgrenset lokal sletting er transaksjonell; ingen generell dokumentert ettårsfrist i undersøkt kode. |
| Lagrede måltider og egne produkter; gjenbruk | SQLite; måltids-/produktbilder lagres lokalt | Bilder og fritekst kan inneholde person-/helseopplysninger; må inngå i risikovurdering | Lokale eierdata slettes. Eksport er utvidet med egne produkter og produktbilder. |
| Favoritter og skannhistorikk; raske oppslag | SQLite per profil | Formål og nødvendig lagringstid må dokumenteres | Eieravgrenset sletting; begge inngår i eksporten. |
| Sist brukte mengde/porsjon og gjenbruksvalg | Profil-/produktavgrensede UserDefaults-nøkler (`lastAmount`, `useLastAmount`) | Kan avsløre matvalg/mengder; må omfattes av datakart og sletting | Profilavgrenset fjerning er lagt inn i `deleteLocalData`; verdiene inngår i eksporten. |
| Lokale innstillinger og analyse-/krasjvalg | UserDefaults; SDK-hookene utfører ingen innsamling | Ingen aktiv analyse-/krasjleverandør i undersøkt kode | Enhetsomfattende valg; må skilles fra profilens domeneinnhold. |
| Søketekst/GTIN, IP og appidentifikasjon; produktoppslag | HTTPS til Open Food Facts; lokal katalogcache | Vurder grunnlag, mottakerrolle og ekstern lagring; ikke kall mottakeren databehandler uten vurdering | Leverandørens lagring og tilgang er uavklart. Råvaresøk i medfølgende Matvaretabellen er lokalt. |
| Offentlige produktbilder; visning | HTTPS til URL i produktdata; egen URLSession/URLCache, opptil 50 MB diskcache | Eksterne bildemottakere og IP-overføring må kartlegges fra faktiske URL-er | Cache-policy er implementert; komplett domeneoversikt og sletting av bildecache er ikke verifisert. |
| JSON-eksport med helse-/kontoopplysninger og måltidsbilder | Midlertidig fil, deretter brukerens valgte delingsmottaker | Brukerinitiert eksport; mottaker velges av bruker | `ProfileExportViewModel` rydder eksporten. Complete-filbeskyttelse og best-effort-rydding av tempfiler eldre enn 24 timer er implementert; full fysisk eksport via Filer gjenstår. Eksterne kopier styres av brukeren. |
| Event-ID, enhets-ID, payload og profileier; planlagt synk | Lokal kø; Supabase inbox/domenetabeller ved fremtidig aktivering | Klientflagg er av. Art. 6/9 og eventuelt samtykke må avklares før aktivering | Kø slettes med eierdata; serverinbox beholdes til purge i undersøkt migrasjon, ikke «behandles og kastes». |
| Driftslogger, SMTP, support og backup | Faktiske leverandører/oppsett må identifiseres | Formål, art. 6, tilgang, avtaler og frister gjenstår | Koden logger hovedsakelig feilkoder/aggregater ved undersøkte servergrenser; samlet drift er ikke kontrollert. |

## Bekreftede dokumentasjonsavvik og åpne kontrollfunn

1. Eksporten er utvidet 3. oktober med egne produkter/produktbilder, alle mål,
   skannhistorikk, produktutkast, kataloginnsendinger og profilens mengdevalg.
   Arkivet har `export_schema_version: 2`; eksisterende kategorier beholdes.
   Nye SQLite-kategorier feiler ved uleselige rader fremfor å returnere tomt
   resultat. Øvrige eksisterende repository-lesinger må fortsatt vurderes for
   ufullstendige resultater ved lesefeil. Fullt art. 15-/20-scope er ikke godkjent.
   Produktbilder og porsjonsdata er base64. Mål, produkter og skannhistorikk har
   ISO 8601-datoer; utkast/innsendinger beholder lagret JSON-format.
2. `DatabaseService.deleteLocalData` etterlot profilens sist brukte mengder.
   Profilavgrenset opprydding av `lastAmount`-/`useLastAmount`-nøkler, inkludert
   porsjonsdata, er nå lagt inn. Regresjonskontrollen dekker at profil B og
   enhetsinnstillinger bevares når A slettes. Testresultat føres nedenfor.
3. Tidligere purge frakoblet produkter med `owner_id = null`. Dette er rettet
   til sletting av eierknyttede produkter 7. oktober. Eventuelt tidligere
   frakoblet innhold krever separat vurdering; frakobling beviser ikke anonymisering.
4. Eksplisitt filbeskyttelse er senere implementert for SQLite og sidefiler,
   og eksport har complete-filbeskyttelse. Se lokal lanseringskontroll nedenfor.
   Restore og full fysisk eksport er fortsatt åpne kontroller.
5. Eldre spesifikasjoner omtaler CoreData, ett års serverlagring og kassering av
   usynkede hendelser. Aktiv lokal lagring er SQLite; teksten er ikke grunnlag for
   å slette data eller erklære etterlevelse.
6. Personvernerklæringens delingslenker og App Privacy-opplysninger må kontrolleres
   mot faktisk tilgjengelig funksjon og releasekonfigurasjon.

## Gjeldende oppfølgingsstatus – 19. oktober 2026

| Planpunkt | Status | Neste steg |
| --- | --- | --- |
| P0-1 Ansvar | Juridisk identitet og begge operative kontaktroller bekreftet 19. oktober | Vurder ombudsbehov separat; etabler sakslogg/fraværsdekning og øv rutinen. |
| P0-2 Datakart | Kodekontroll og korrigerte dataflyter 19. oktober; juridisk protokoll uferdig | Godkjenn lokal rolle og grunnlag per formål; avklar eksterne logger og bildemottakere. |
| P0-3 Leverandører | Standard DPA og offentlige kilder kontrollert; staging-aggregat kontrollert 19. oktober | Avklar konkret retensjon og overføringer; behold beslutningen om ikke å sende Supabase-henvendelsen. Egen auth-SMTP er utsatt. |
| P0-4 Risiko/DPIA | Konkret vurderingsgrunnlag nedenfor; ingen endelig beslutning | Behandlingsansvarlig må avklare omfang/ansvar og sluttføre DPIA-vurderingen, inkludert mindreårige. |
| P0-5/6 Lagring, eksport og sletting | Flere rettelser og tester bestått 3.–14. oktober | Fullfør kandidatkontroll av faktisk eksport; avklar restore og resterende slettings-/retensjonsgrenser. |

Verifisering 2. oktober: `git diff --check` bestod. Målrettet `xcodebuild test`
for `MorningCheckInTests/localWeightWriteQueuesEventAndUpdatesSameEntry` ble
avbrutt etter omtrent fire minutter uten testresultat; flere andre Xcode-jobber
kjørte samtidig. Ingen kompilatorfeil ble rapportert i denne loggen, men testen
regnes **ikke som bestått**. Kjør den igjen i et isolert testmiljø før rettelsen
regnes som ferdig verifisert. Ingen produksjonsdata ble slettet.

Verifisering 3. oktober: målrettet `xcodebuild test` med
`-only-testing:MatLoggTests/ProfileTests` og
`-only-testing:MatLoggTests/MorningCheckInTests` bestod: **15 tester i 2 suiter**.
Egen simulator `MatLogg Privacy QA` (iOS 26.5) og DerivedData
`/tmp/matlogg-privacy-derived` ble brukt. Dette erstatter det uavklarte resultatet
for slettingsrettelsen fra 2. oktober. Testene dekker eksport med produktbilder,
målhistorikk, skannhistorikk, mengdevalg, annen profils data, feilende eksport-
repository og sletting som bevarer annen profil og fjerner eierens synkhendelser.
`git diff --check` bestod. Ingen drift-/avtaleport er godkjent av disse testene.

Arkitekturkontroll: eksportens nye IO-grense er et injisert
`ProfileDataExportRepository` satt sammen ved app-roten. Eierfiltrering ligger
i lokal lagring; ingen endring i synkformat, synkflagget eller autentisering.
Oppryddingen ligger ved eksisterende repository/service-
grense i `DatabaseService`, etter vellykket lokal databasesletting, og bruker
eksakte profilprefikser. Ingen view-IO, auth-endring eller synkkontraktendring.
SQLite-transaksjonen er bevart; opprydding i UserDefaults er fortsatt en separat
operasjon, slik den eksisterende personlige-detaljer-oppryddingen er. Robusthet
ved prosessavbrudd mellom disse lagrene må inngå i videre slettingskontroll.

## Innledende risikovurdering

Dette er en første vurdering uten sannsynlighetsscore; manglende miljøbevis skal
ikke oversettes til lav risiko. Navngitt ansvarlig må godkjenne restrisiko.

| Risiko | Konsekvens | Tiltak / bevis som mangler |
| --- | --- | --- |
| Kryssprofiltilgang eller feil kobling av lokal profil | En annen persons spisehistorikk, vekt eller mål vises/eksporteres | A/B-profiler, kontobytte og kobling må verifiseres ende til ende; eksisterende RLS kontrolleres i aktivt miljø. |
| Rester etter sletting og ufullstendig eksport | Rettighetskrav oppfylles ikke; sensitive data blir liggende | Rett de identifiserte nøkkel-/eksportfunnene og test negative eierskapstilfeller. |
| Tyveri av enhet eller midlertidig eksport | Uønsket tilgang til helseprofil | Verifiser fil-/Keychain-beskyttelse, backup og rydding etter avbrutt eksport på fysisk enhet. |
| Leverandør-/supporttilgang uten avklart avtale eller overføringsgrunnlag | Uautorisert eller ulovlig ekstern behandling | Dokumenter avtaler, roller, tilgang, land og relevante overføringsmekanismer. |
| Restore gjenoppretter slettede data | Slettede kontoer/data blir tilgjengelige igjen | Dokumenter og demonstrer gjenanvendelse av slettinger før miljøet åpnes. |
| Fremtidig synk laster opp uten gyldig grunnlag | Helseopplysninger behandles ulovlig | Bevar avslåtte flagg; avklar grunnlag og verifiser servergrense før aktivering. |
| Barn eller sårbare brukere får unødvendig innsamling/press | Personvern- og helsemessig skade | Avklar målgruppe, fødselsdatobehov, målberegninger, trygt språk og DPIA-kriterier. |

DPIA-status: **ikke avgjort**. Vurderingen må ta hensyn til faktisk målgruppe,
omfang, sensitive data, eventuell profilering og Datatilsynets obligatoriske
liste. Personvernombud vurderes separat; énpersonforetak gir ikke automatisk
unntak eller automatisk plikt.

## Rutineutkast: rettighetskrav og sikkerhetsbrudd

Brukeren bekreftet 19. oktober 2026 Nithusan Krishnasamymudali som operativ
kontakt for både personvernspørsmål og sikkerhetshendelser, på
nithusank.2002@gmail.com. Dette er ikke utnevnelse som personvernombud.
Operativ stedfortreder og sikker lagring av sakene er ikke avklart.
Rutinen er et utkast og er ikke øvd.

Ved rettighetskrav:

1. Registrer mottakstid, forespurt rettighet og frist i tilgangsstyrt sakslogg.
   Ikke kopier helseopplysninger til GitHub/repo eller vanlig feillogg.
2. Verifiser identitet proporsjonalt; ikke krev legitimasjonskopi som standard.
   Bruk sikker kanal når saken krever person-/helseopplysninger.
3. Kartlegg lokale data, Auth, serverdata og relevante leverandører. Forklar
   tydelig hva MatLogg ikke kan hente fra brukerens enhet.
4. Besvar normalt innen én måned. Dokumenter eventuelt lovlig behov for
   forlengelse og informer innen den opprinnelige fristen.
5. Dokumenter gjennomføring, avgrensninger og rettslig grunnlag for eventuelt
   avslag. Verifiser eksport/sletting og informer om klagemulighet.

Ved mulig brudd på personopplysningssikkerheten:

1. Registrer når hendelsen ble kjent, berørte systemer og hvem som håndterer den.
2. Begrens eksponering, stans aktuell dataflyt og sikre nødvendige bevis med
   minst mulig sensitive data. Ikke slett bevis eller gjør destruktiv rollback.
3. Vurder konfidensialitet, integritet og tilgjengelighet, berørte personer,
   datatyper, mulig skade og tiltak. Dokumenter også beslutninger om ikke å melde.
4. Dersom bruddet ikke sannsynligvis er uten risiko for rettigheter/friheter,
   meld til Datatilsynet uten ugrunnet opphold og om mulig innen 72 timer etter
   kjennskap. Meld trinnvis hvis nødvendige detaljer fortsatt mangler.
5. Ved sannsynlig høy risiko: informer berørte uten ugrunnet opphold med klar
   beskrivelse, kontakt, mulige konsekvenser og tiltak, med vurdering av
   relevante lovbestemte unntak.
6. Gjenopprett kontrollert, verifiser eierskap og slettestatus, og dokumenter
   årsak og varige tiltak. Gjennomfør øvelse før ekstern pilot.

## Kodegrunnlag

- `MatLogg/App/FeatureFlags.swift`, `MatLogg/MatLoggApp.swift`
- `MatLogg/Services/AuthService.swift`, `SupabaseService.swift`
- `MatLogg/Services/LocalStore.swift`, `DatabaseService.swift`
- `MatLogg/Services/HealthProfileRepository.swift`, `UserDataExportService.swift`
- `MatLogg/Services/APIService.swift`, `ProductImageRepository.swift`
- `MatLogg/ViewModels/PreferencesViewModel.swift`, `ProfileExportViewModel.swift`
- `supabase/functions/delete-account/index.ts`, `purge-accounts/index.ts`
- `supabase/migrations/20260928090000_initial_matlogg.sql`

Arbeidsgrunnlaget inneholder ingen ekte brukerdata eller hemmeligheter. Se
[forbedringsplanen](privacy-security-improvement-plan.md) for porter og
myndighetskilder. Ingen releaseport regnes som bestått av denne kartleggingen.

## Lokal lansering: kontroll av lagring og distribusjonsopplysninger

Domenedata lastes ikke opp, også med backendflagg på: localOnly er default og
releasebygg har ingen upload-enabled policy. Supabase Auth og Open Food Facts
forblir aktive; e-post og bruker-ID i PrivacyInfo.xcprivacy beholdes derfor.
Manifestet angir ingen sporing og deklarerer UserDefaults-bruken. Endelig
App Store Connect-erklæring og tredjepartsopplysninger må fortsatt vurderes
mot faktisk releasekonfigurasjon; ingen butikkopplysninger er publisert her.

SQLite ligger i Application Support og ekskluderes ikke eksplisitt fra backup.
Måltids-/produktbilder ligger i SQLite-payloads; de er ikke separate bildefiler.
Appens databasedirectory og eksisterende database/journal/WAL/SHM får eksplisitt
completeUntilFirstUserAuthentication; nye journaler i appdirectory arver vernet.
Profil-ID, lokale profilsnapshots, detaljer og preferanser er i UserDefaults.
Disse filene ekskluderes ikke eksplisitt av appen. Dette er kodekontroll av
backupgrunnlaget, ikke bevis på iOS-restore eller valgt backupinnstilling.
Auth-token bruker AfterFirstUnlockThisDeviceOnly og kan ikke forventes å følge
med til en ny enhet. Eierbinding etter restore uten token er uverifisert.

Eksport skrives atomisk med completeFileProtection. Normal delingsavslutning
og profilbytte rydder filen via ProfileExportViewModel. Prosesskrasj kan etterlate
en beskyttet tempfil. Ved neste opprettelse av eksporttjenesten fjernes egne
JSON-eksporter eldre enn 24 timer best-effort; nyere filer beholdes slik at en
åpen delingsdialog ikke mister filen. Ingen bakgrunnsgaranti for sletting gis. JSON-import er ikke tilgjengelig.

Den hvilende køen bevarer payload per endring og vokser med bruk. Det innføres
ikke destruktiv komprimering i denne leveransen. Følg faktisk SQLite-/køstørrelse
under pilot før en separat, tapsfri vedlikeholdsstrategi vurderes.

## Kontroll 7. oktober 2026 – personvernlenke og sletteflyt

Appens felles lenke er endret til `https://nithusan.no/MatLogg/personvern.html`
(HTTP 200 ved kontroll). Lokal profilsletting tilbys også uten konto.
Klienten lagrer slettefremdrift og gjenopptar bekreftet lokal opprydding etter
omstart; ubekreftet serversvar behandles som usikker status. Eieravgrensede
midlertidige eksporter fjernes; delte/eksterne kopier kontrolleres av brukeren.

Brukeren godkjente sletting av egne serverprodukter. Migrasjonen
`20261007054620_account_deletion_products.sql` erstatter `owner_id = null`
med faktisk sletting og bevarer opprinnelig purge-frist ved retry. Dette gjelder
eierknyttede produkter; tidligere frakoblede produkter kan ikke automatisk
knyttes tilbake til en konto og krever separat vurdering.

Read-only kontroll i MatLogg Staging viste aktiv cron med `15 2 * * *`, sju
registrerte vellykkede kjøringer siste sju dager og ett nylig HTTP 200-svar
med purge-resultat. Cron-status alene beviser ikke kontosletting. Hosted
backup/loggretensjon og slettinger etter restore er fortsatt uverifisert.
Den publiserte nettsidens tekst må oppdateres sammen med utrulling; endring av
`matlogg-legal/privacy.md` publiserer ikke nettsiden automatisk.

Verifisering 7. oktober: første målrettede iOS-kjøring bestod med **47 tester**,
0 feil. Lokal databasekontroll bestod med **27 pgTAP-kontroller**. Lokal Auth/
Edge Function-test bestod: serverbekreftelse, sperret innlogging, permanent
Auth-/produktsletting, gjentatt purge og bevaring av annen eier. Legacy-backend
bygget og målrettet auth-maintenance-test bestod.

Migrasjonene `20261007054620_account_deletion_products.sql` og
`20261007054925_account_deletion_rate_windows.sql` er anvendt i MatLogg Staging.
Den siste inkluderer `private.sync_rate_windows`, som inneholder eier-ID uten
FK-cascade. Hosted kontroll med syntetiske kontoer bestod: `delete-account`
bekreftet forespørselen, ny innlogging ble avvist, og faktisk `purge-accounts`
returnerte HTTP 200 med `purged: 1, failed: 0`. Etterkontroll via Auth Admin API
og REST bekreftet hard-delete og produktsletting, mens annen konto/produkt var
bevart. Testkontoene ble ryddet. Separat transaksjon med rollback kontrollerte
alle domenekategorier, rate-limit-rader og bevart retry-frist i staging.

`matlogg-web/src/PrivacyPage.tsx` er også oppdatert: publisert side omtalte
konto og serversletting som fremtidige funksjoner. Nettside/app er ikke
publisert i denne oppgaven. Backup-/loggfrister, håndtering etter restore og
varsling til en konkret mottaker gjenstår før produksjonsgodkjenning.

### Lokale registreringsutkast (2026-10-07)

Manuell registrering lagrer rå input, nærings-/porsjonsgrunnlag, ferdig importert
bilde, produktreferanse, mengde, dato og måltid i `food_logging_drafts` per lokal
profil. Formålet er å fortsette en avbrutt registrering. Utkast lastes bare for
aktiv profil, eksporteres som eid JSON og slettes ved Forkast, fullført logging
eller sletting av profildata. Ingen automatisk utløp eller opplasting.
Bilder ligger i samme SQLite-snapshot og følger samme sletting og filbeskyttelse.
Dette er lokal gjenoppretting; avinstallering eller tap av telefonen dekkes ikke.

Tilgangskontroll samme dag: gammelt JWT kunne lese produktdata etter soft-delete
før rettelsen. Brukeren godkjente RLS-endringen. Migrasjonen
`20261007055901_account_deletion_read_access.sql` er anvendt i staging og
krever aktiv profil på alle brukeravgrensede lesepolicyer. **95 lokale
pgTAP-kontroller i sju filer** bestod etter endringen, inkludert umiddelbar
lesesperring med gammelt token for alle datakategorier. Lokal HTTP-test og
hosted staging HTTP-test bestod med ekte Auth-token: slettet konto fikk tomt
RLS-resultat straks, mens annen aktiv konto beholdt lesetilgangen.
Ingen produksjonsutrulling er utført.

Historisk kontroll i staging fant ingen frakoblede `source = user`-produkter,
men fire rate-limit-rader uten tilhørende Auth-konto. Nye sletteforespørsler
rydder slike rader som del av purge. Brukeren godkjente separat opprydding,
og `supabase/ops/cleanup-orphan-rate-windows.sql` fjernet nøyaktig fire rader i
staging. Skriptet berører bare eier-ID-er som ikke finnes i Auth og stopper
hvis det gjennomgåtte antallet har endret seg.

Sluttkontroll etter gjenopptakelse: **48 iOS-tester i tre relevante suiter**
bestod uten feil på egen MatLogg Deletion QA-simulator. Midlertidig scheme
utelot UI-testtargetet for å isolere enhetstestene fra annet pågående arbeid.
Logg og xcresult ligger under ignorert `build/privacy-deletion-qa/`.
Etter ny reset av det isolerte lokale testmiljøet bestod **95 databasetester**
og databaselint uten feil. CI-skriptet for HTTP-testen bestod også: faktisk
Auth-sletting, avvist innlogging, sletting av egne produkter, eierisolasjon
og gjentatt purge. Det midlertidige testmiljøet og test-schemet ryddes etter
kontrollen; testloggene beholdes i den ignorerte build-mappen.
Read-only etterkontroll i staging viste **0 foreldreløse rate-limit-rader**.
Identiteter, økter og refresh-tokens for den tidligere purgede syntetiske
kontoen ble også kontrollert i staging: alle tre kategorier hadde 0 rader.
Arkitekturkontroll: views sender handlinger til AuthViewModel; repository/
services håndterer IO. Lokal eieravgrenset transaksjon er bevart; slettemarkør
og fil-/UserDefaults-opprydding er gjenopptakbare separate operasjoner.
Synkkontrakt og produksjonsflagg er uendret. Ingen nye arkitekturavvik.

## Oppfølging – serversletting uten fast ventetid

Ny implementasjon fjerner 30-dagersventetid for nye forespørsler.
Serverslettingen forsøkes i samme forespørsel; ufullført sletting beholdes for
retry. RLS-sperren oppheves ikke ved Auth-feil. Varslingsmottaker er
nithusank.2002@gmail.com; e-postadapter er klargjort, men leverandør/avsender
og secret er ikke konfigurert. Aktuelle backup-/loggfrister i produksjon er
fortsatt ukjent: connector viser bare staging, og dashboard krever innlogging.
Historiske funn og 30-dagersbeskrivelser ovenfor gjelder tidligere versjon.

Verifisering av ny flyt: **95 databasekontroller**, **15 Deno-tester**,
Deno check/lint, databaselint, målrettet legacy auth-maintenance-test og
backend-/nettbygg bestod. Lokal HTTP-test bekreftet sletting i samme kall,
eierisolasjon og køet retry. Staging-migrasjonen
`20261007144356_account_deletion_without_wait` og begge Edge Functions er
utrullet. Cron er kontrollert aktiv med `*/5 * * * *`.
Hosted HTTP-test med syntetisk konto bekreftet Auth-hard-delete og
produktsletting i samme kall og avvist lesing med gammelt token; testkontoen
ble ryddet. Seks eldre sletteforespørsler beholdt fristene, ingen var due.
Denne iOS-endringen er bare bekreftelsestekst; tidligere 48 målrettede
iOS-tester er ikke kjørt på nytt. Ingen produksjons- eller nettpublisering.
Arkitekturkontroll: eksisterende IO-grenser og lokal slettetransaksjon er
bevart. Serverens domenepurge er atomisk; Auth følger etter og feil kan
prøves igjen. Ingen synkkontraktendring eller nye arkitekturavvik.


## Landingsside: tekst og kildekreditering (2026-10-08)

Lokal nettside beskriver nå manuell bildedemo uten betapåmelding.
Kontaktvinduet viser samme ansvarlige navn og e-postadresse som erklæringen.
Personlige detaljer beskrives med påkrevd fødselsdato ved lagring, i samsvar
med appens juridiske tekst. Bunnmenyen lenker til Open Food Facts-kreditering,
CC BY-SA 3.0 / ODbL, produktkilder og originalfotografier. Måltidsillustrasjoner
merkes som AI-genererte. Ingen ny datainnsamling eller ekstern tjeneste innført.

HTTP-kontroll bekreftet 200 på `https://nithusan.no/MatLogg/personvern.html`
og 404 på `https://nithusan.no/matlogg`; appens eksisterende URL beholdes.
Dette bekrefter lenkens tilgjengelighet, ikke full produksjonsetterlevelse.
Kontakt og kildekreditering er kontrollert i lokal nettleser; TypeScript/Vite
og diffkontroll bestod. Ingen publisering av disse endringene er utført.
Push til main vil utløse nettstedets publiseringsworkflow. Åpne produksjons-,
leverandør-, risiko-/DPIA- og App Store-porter gjelder fortsatt.


## Leverandørkontroll 8. oktober 2026 – standardvilkår

[Supabase Terms of Service](https://supabase.com/terms) blir effektive ved
aksept eller bruk av tjenesten og inkluderer gjeldende DPA.
[DPA, versjon 1 av 1. august 2026](https://supabase.com/legal/customer-resources/data-processing-addendum)
punkt 11.2 angir sletting av dekkede data etter en 30 dagers periode ved
avtalens utløp. Dette er ikke en slettefrist for individuelle appkontoer.
Vurderingen forutsetter vanlig nettpåmelding under standardvilkår; en særavtale
kan ha andre bestemmelser. En separat signert DPA er derfor ikke et eget
pilotkrav ut fra de kontrollerte standardvilkårene. Tidligere formuleringer om
uavklart DPA-status skal leses med denne presiseringen.

[Underleverandørlisten av 1. juni 2026](https://supabase.com/legal/subprocessor-list/June-1-2026.pdf)
er kontrollert. Den omfatter blant annet AWS og Cloudflare (hosting),
Sentry og Braintrust (overvåking), samt støtte-, analyse- og AI-tjenester.
Listen alene beviser ikke at hver tjeneste mottar MatLogg-appbrukeres data.
Stockholm-regionen beviser heller ikke at all behandling skjer i EØS:
DPA punkt 6.1 åpner for behandling andre steder, og punkt 12/Schedule 2
beskriver SCC-er. Faktiske dataflyter og overføringsvurdering gjenstår.

Brukerskjermbildet bekrefter databasebasert Auth-audit av; Supabases
[Auth-dokumentasjon](https://supabase.com/docs/guides/auth/audit-logs)
bekrefter at plattformlogger er en separat lagringsvei. Historiske poster og
full lagringstid for driftslogger er ikke verifisert. Ingen avtale akseptert,
abonnement opprettet, innstilling endret eller data slettet i denne kontrollen.

Ekstern pilot er fortsatt no-go inntil de øvrige dokumenterte personvern- og
releaseportene er avklart. Neste leverandørkontroll er aggregert kontroll av
eldre audit-poster og dokumentasjon fra Supabase av driftsloggenes lagring og
sletting. Egen auth-SMTP er utsatt sammen med e-postinnlogging.
Skill: nutrition-privacy (tidligere releasevurdering: qa-release).
Kun dokumentasjon; ingen ny kodeverifisering nødvendig.

Oppfølging 8. oktober: read-only `count(*)` i staging-tabellen
`auth.audit_log_entries` returnerte **0**. Historiske database-auditposter
er dermed ikke et åpent kontrollfunn på dette tidspunktet. Full retensjon
for plattformlogger er fortsatt uavklart; forespørsel til Supabases
personvernkontakt er klargjort i `docs/production-readiness.md`, ikke sendt.


## Avgrenset personverngjennomgang – 19. oktober 2026

Gjennomgått kode ved `55e513b`; eksisterende lokale endringer i
`Config/Debug-Info.plist` og Xcode-prosjektet er ikke del av denne gjennomgangen.
Dette er beslutningsgrunnlag og lokale tekstforslag, ikke juridisk godkjenning,
ny distribusjonskontroll eller godkjenning av ekstern pilot.

### Teknisk kontroll og mottakere

| Flyt | Kontrollert adferd | Åpent punkt / neste handling |
| --- | --- | --- |
| Lokal logging | App-roten velger `.localOnly`; `backendSyncEnabled=false`. Konto gir ingen opplasting av domenehistorikk. | Behold grensen ved senere release; lokal behandlingsrolle må vurderes selv om utvikler ikke har tilgang. |
| Konto | `SupabaseService` sender Apple ID-token og nonce til Supabase. Apple-navneforslag håndteres lokalt. `emailAuthenticationEnabled=false`; e-postimplementasjonen finnes fortsatt. | Kontroller faktisk kandidatarkiv og provideroppsett separat; UI-flagget stenger ikke serverens e-post-API. |
| Råvaresøk | Medfølgende Matvaretabellen søkes lokalt. | Ingen nettmottaker i denne flyten. |
| Merkevaresøk | `APIService` sender søketekst som URL-parameter til `no.openfoodfacts.org` eller `world.openfoodfacts.org`; strekkode går til world-hostens v3-endepunkt. GET har appversjon og utviklerkontakt i User-Agent, ingen MatLogg-Bearer-token satt i denne kallbanen. | Mottaker ser også IP og tekniske metadata; søkeord i URL kan inngå i tilgangslogger. Faktisk lagring er ikke demonstrert. |
| Oppdatering av katalogtreff | `BarcodeLookupRepository` kan revalidere et gammelt cachetreff i bakgrunnen etter 30 dager; brukeren kan også oppdatere manuelt. | Erklæringen må beskrive bakgrunnsoppdatering, ikke bare aktive søk. |
| Produktbilder | `CachedProductImageRepository` henter HTTPS-URL fra produktdata ved cachebom. Eksempelressursene peker til `images.openfoodfacts.org`; kode krever HTTPS, men ingen fast hostliste, og redirect-mål er ikke avgrenset i denne klassen. Ingen egen auth-header; cookie-/credential-storage er satt til nil. | Komplett runtime-domene-/redirectoversikt er ikke verifisert. URL og tidspunkt kan røpe hvilket produkt som vises. |
| Katalogtransport | `URLSessionHTTPClient` bruker `.shared`; eksplisitt fravær av cookies er bare verifisert for bildetransporten. | Ikke påstå at alle katalogkall er cookiefrie. Kontroller med syntetisk trafikk før slik påstand eller transportendring. |
| Bildecache | Opptil 50 MB diskcache, separat fra profileiers SQLite-data; ingen eksplisitt tømming i undersøkt `deleteLocalData`-kallbane. | Vurder rester av offentlige produktbilder/URL-er på delt telefon. Dette er ikke bevis på at private SQLite-bilder blir liggende. |
| Personlige detaljer | `PersonalDetailsViewModel.save` godtar manglende fødselsdato; lokal profilavgrenset lagring. `GoalCalculator` støtter beregning for 18–120 år. | Rett tekst som kaller fødselsdato obligatorisk. 16+-målgruppe er ikke det samme som 18+-grense for målforslag. |
| Deling | Måltidskort rendres lokalt og deles med iOS eller lagres i Bilder. Ingen produkt-tokenlenke funnet i gjennomgått appkode. | Fjern udokumentert løfte om produktimport via delingslenke. Kopier i Bilder/delingsmål følger brukerens valgte tjeneste. |

Dette er statisk kodekontroll, ikke en opptakslogg over faktisk nettverkstrafikk.
Auth-SDK-ens interne transport, alle bildeverter og OS-/App Store-diagnostikk
er ikke uttømmende kontrollert. GitHub Pages/nettside og henvendelser til
kontaktadressen må inngå i den samlede leverandør-/behandlingsprotokollen;
denne runden kartlegger primært appens aktive kallbaner.

Read-only kontroll av faktisk MatLogg Staging bekreftet `ACTIVE_HEALTHY`,
`eu-north-1`, `sync_enabled=false` og **0** rader i `auth.audit_log_entries`.
Kun prosjektmetadata og dette aggregatet ble hentet; ingen brukerinnhold,
rå logger, tokens, sletting eller konfigurasjonsendring. Null rader bekrefter
ikke dagens audit-toggle eller fravær av separate plattformlogger.

### Leverandørbevis og avgrensninger

- [Supabases standardvilkår](https://supabase.com/terms) inkluderer DPA;
  [DPA](https://supabase.com/legal/customer-resources/data-processing-addendum)
  beskriver også SCC-er. Dette bekrefter standardgrunnlaget, ikke en eventuell
  særavtale eller fullført overføringsvurdering for MatLogg.
- [Supabases dataresidens-FAQ](https://supabase.com/legal/privacy-resources/data-residency-and-transfers-faq)
  beskriver internasjonal support/drift og viser til SCC/TIA. MatLoggs konkrete
  vurdering må omfatte dette, selv med Stockholm-region. FAQ-en gir ikke en
  full frist for appbrukernes tekniske logger.
- [Auth Audit Logs](https://supabase.com/docs/guides/auth/audit-logs) skiller
  database-audit fra ekstern logglagring. Konto-hard-delete og null audit-rader
  beviser derfor ikke sletting av identifikatorer hos hele leverandørkjeden.
- [OFFs API-dokumentasjon](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/docs/api/index.md)
  bekrefter appidentifiserende User-Agent og IP-basert trafikkbegrensning;
  den fastsetter ikke retensjon for MatLoggs søk eller bildetrafikk.
  [Infrastrukturoversikten](https://openfoodfacts.github.io/openfoodfacts-infrastructure/explanation/infrastructure-overview/)
  viser flere server-/proxyroller, men beviser ikke dagens fulle behandlingskjede.
  Personvernsiden på `world.openfoodfacts.org/privacy` lot seg ikke lese
  meningsfullt i nettverktøyet; ingen lagringsfrist er utledet fra dette.

Beslutningen fra 8. oktober om **ikke å sende Supabase-henvendelsen** beholdes.
Full loggretensjon er uavklart, ikke påvist regelbrudd eller automatisk ny
releaseblokkering. Behandlingsansvarlig må dokumentere hvordan usikkerheten
håndteres i vurderingen. OFF-rolle og nødvendige opplysninger er fortsatt åpne.

### Grunnlag per formål – forslag til avklaring

| Formål | Foreløpig vurderingsgrunnlag | Beslutning som mangler |
| --- | --- | --- |
| Valgfri konto | Eksisterende erklæring bruker art. 6(1)(b), avgrenset til autentisering/kontofunksjoner. | Dokumenter nødvendighet, aktive mottakere og lagring; konto krever ikke matopplasting. |
| Lokal mat-/vekt-/målbehandling | Dataminimering og brukerens kontroll reduserer eksponering. | Avklar MatLoggs rolle og om/hvilket art. 6-grunnlag og art. 9-unntak som gjelder. Lokal lagring alene avgjør ikke dette. |
| Eksterne katalog-/bildeoppslag | Formålet er produktinformasjon, med IP, forespørsel og appidentifikasjon. | Vurder mottakerrolle, nødvendighet og grunnlag; ikke anta databehandlerforhold eller at aktivt trykk er GDPR-samtykke. |
| Sikkerhetslogger og support | Driftsformål må skilles fra logging av matvaner. | Dokumenter eget grunnlag og eventuell interesseavveining, mottakere, tilgang og frister. Ikke innfør helseinnhold i vanlig supportlogg. |
| Deling/eksport | Brukeren velger innhold og mottaker; MatLogg oppretter lokal kopi. | Beskriv grensen mot eksterne kopier; det er ikke et generelt samtykke til andre dataflyter. |

### DPIA-vurdering – grunnlag til beslutning, ikke signert konklusjon

Utgangspunkt: lokal mat-/helsehistorikk, valgfri konto, eksterne produktoppslag,
ingen aktiv domeneopplasting eller analyse-SDK. Antall testere, pilotvarighet
og datamengde er ikke fastsatt her. Vurderingen følger temaene i
[Datatilsynets veiledning](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/vurdering-av-personvernkonsekvenser/nar-er-risiko-hoy/).

| Kriterium | Foreløpig vurdering for MatLogg |
| --- | --- |
| Evaluering/poengsetting | Personlige målforslag er relevante å vurdere; lokal beregning utelukker ikke kriteriet. |
| Betydelige automatiske avgjørelser | Ingen slik avgjørelse identifisert; appen gir veiledende mål. |
| Systematisk monitorering | Brukerinitiert daglig logging kan gi detaljert historikk; utvikler har ingen aktiv historikktilgang. Må avgrenses konkret. |
| Sensitive/personlige opplysninger | Ja i produktets datamodell: vekt, mål og spisehistorikk. Rettslig rolle for lokal behandling er fortsatt åpen. |
| Stor skala | Ikke dokumentert. Fastsett testerantall, varighet, volum og geografisk omfang. |
| Sammenstilling | Bekreftet lokal kontokobling finnes; ingen annonsedatasett eller ekstern helsedatasammenstilling identifisert. |
| Sårbare registrerte | 16+-målgruppen inkluderer mindreårige; også brukere med sårbarhet rundt mat/vekt må vurderes. |
| Ny teknologi | Vanlig SwiftUI/SQLite/produkt-API gir ikke alene grunnlag for å krysse av. |
| Hindring av rettigheter/tjenester | Lokal bruk er tilgjengelig uten konto. Eksport har ingen import; faktisk eksport og konsekvenser ved enhetstap må inngå. |

Foreløpig faglig anbefaling: **ikke konkluder med at DPIA er unødvendig** før
helsebehandling, profilering, mindreårige og omfang er vurdert samlet. Flere
risikomomenter foreligger. Behandlingsansvarlig må dokumentere beslutningen,
og fullføre DPIA med tiltak dersom den er påkrevd. Ingen endring til 18+-målgruppe,
nytt samtykke eller aksept av restrisiko er vedtatt i denne gjennomgangen.

### Konkrete neste avklaringer

1. Operativ sikkerhets-/personvernkontakt er bekreftet. Behandlingsansvarlig
   fastsetter videre pilotomfang og håndtering av 16–17-åringer og eksisterende yngre profiler.
   16+-beslutningen beholdes; full fødselsdato er ikke en implementert aldersport.
2. Avklar lokal behandlingsrolle/grunnlag og sluttfør DPIA-beslutningen.
3. Dokumenter loggfrister, leverandørroller og overføringsvurdering med
   tilgjengelige leverandørbevis. Supabase-henvendelsen sendes ikke.
4. OFF-spørsmål klargjort for eventuell senere godkjenning: «For requests from
   a third-party iOS app to no/world.openfoodfacts.org and image hosts: which
   search terms, barcodes, image URLs, IPs, User-Agents and cookies are retained,
   for how long, for what purposes, in which countries and by which providers?
   Can data be associated with users or used beyond serving/security of the
   request, and what deletion options apply?» Kontaktpunktet
   `privacy@openfoodfacts.org` er oppgitt på
   [OFFs egen kontoslettingsside](https://blog.openfoodfacts.org/en/account-deletion).
   Ingen e-post eller e-postutkast i ekstern tjeneste er opprettet.
5. Samordne lokal erklæring, nettsidens `PrivacyPage.tsx`, App Privacy og
   kandidatarkiv etter avklaring. Endelig App Privacy-innsending er ikke utført.
6. Gjennomfør eksisterende rettighets-/hendelsesrutine som bordøvelse med
   fiktiv sak; dokumenter mottaker og faktisk resultat. Rutinen er fortsatt uøvd.

Verifisering: målrettet statisk kodekontroll, offentlige primærkilder,
read-only staging-aggregat og `git diff --check`. Ingen build/testkjøring er
nødvendig for disse dokumentendringene. Ingen ny runtime-verifisering.
Skills: nutrition-privacy, backend-api og qa-release. Arkitekturkontroll:
ingen implementeringsendring; MVVM-retning, local-first, atomisk lokal
skriving, JWT-eierskap og injiserte IO-grenser er uendret. Ingen arkitekturavvik.


## Ansvar og personvernvurdering – oppfølging 19. oktober 2026

Brukeren har bekreftet begge operative kontaktroller som beskrevet i rutinen
over. Ansvarsavklaringen er ført i `decisions.md`. Ingen automatisk utnevnelse
som personvernombud, fraværsdekning eller 24/7-beredskap følger av dette.

Personvernvurderingen er utvidet med nødvendighet, alternative behandlingsgrunnlag,
ombudsbehov og en risikomatrise som skiller eksisterende tiltak fra manglende
bevis. I tråd med prosjektets regel om juridiske arbeidsdokumenter ligger
arbeidsversjonen utenfor repoet, i lokalt QA-område:
`/Users/nithu/MatLogg-QA/privacy-2026-10-19/personvernvurdering.md`.
Dokumentet inneholder ingen brukerdata eller faktiske hendelsessaker.

Arbeidskonklusjon: gjennomfør full DPIA for planlagt 16+-produkt fremfor å
avslutte med «ikke nødvendig». Dette er en anbefaling, ikke et bekreftet vedtak
fra brukeren eller ferdig juridisk godkjenning. Helseopplysninger, personlige
målforslag og mindreårige må vurderes samlet, inkludert relevansen av
[Datatilsynets obligatoriske liste](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/vurdering-av-personvernkonsekvenser/nar-ma-man-gjennomfore-en-vurdering-av-personvernkonsekvenser/).

Manglende tilgang til lokale data avgjør ikke alene behandlingsansvar;
se [EDPB 07/2020, punkt 45](https://www.edpb.europa.eu/system/files/documents/2023-10/EDPB_guidelines_202007_controllerprocessor_final_en.pdf).
MatLoggs lokale rolle og grunnlag er fortsatt ikke endelig avgjort. Mulig
uttrykkelig helsesamtykke er vurdert som alternativ, ikke valgt eller implementert.
En ny samtykkeflyt krever egen produkt-/design-/tilgangsavklaring.
Ombudsplikt må også vurderes separat mot faktisk omfang; produktansvarlig
skal ikke automatisk være formelt ombud, jf.
[EDPBs ombudsveiledning](https://www.edpb.europa.eu/sme/be-compliant/data-protection-officer_nb).

Ingen pilotstørrelse, varighet eller endret målgruppe er besluttet. Eksisterende
16+-målgruppe og beslutningen om ikke å sende Supabase-henvendelsen beholdes.
Gjenværende hull er konkret listet i arbeidsversjonen; ingen restrisiko er
signert eller nye releaseporter godkjent. Skills: nutrition-privacy og qa-release.
Kun dokumentarbeid; diffkontroll, ingen ny build/test eller miljøendring.
