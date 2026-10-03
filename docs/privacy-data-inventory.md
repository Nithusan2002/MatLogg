# Datakart og kontrollstatus

Oppdatert: 3. oktober 2026. Behandlingsansvarlig oppgitt av bruker:
Nithusan Krishnasamymudali. Kontakt i eksisterende erklæring:
nithusank.2002@gmail.com.

Brukeravklaringer 3. oktober: målgruppen er 16 år og eldre. Aksept av
Supabase-DPA og SMTP-leverandør er ukjent; dette betyr uavklart, ikke at en avtale
mangler. Aldersgrensen er en produktbeslutning, ikke et artikkel 9-grunnlag.
Onboarding, vilkår og håndtering av eksisterende profiler under 16 må avklares
samlet før aldersgrensen regnes som implementert. Ingen profiler slettes på
grunnlag av denne beslutningen.

Dette er et teknisk arbeidsgrunnlag for behandlingsprotokoll og risikovurdering,
ikke en ferdig juridisk vurdering. Kode er undersøkt; driftsmiljø, avtaler,
leverandørlagring og fysisk enhet er ikke verifisert. Alle rader gjelder
appbrukere. Juridisk vurdering må avklare ansvaret for lokal behandling separat
fra konto-/serverbehandling; «lokalt» betyr ikke automatisk GDPR-unntak.

## Dagens dataflyter

| Data / formål | Lagring og mottaker | Rettsgrunnlag / status | Lagring og sletting sett i kode |
| --- | --- | --- | --- |
| E-post, konto-ID, Apple-identitet; autentisering | Supabase Auth; konto-/lokal profilsnapshot i UserDefaults, tokens i Keychain | Erklæringen angir art. 6(1)(b); avtale og faktisk konfigurasjon må kontrolleres | Kontosletting soft-deleter Auth og setter purge etter 30 dager. Faktisk cron, logger og backup er ikke kontrollert. |
| Visningsnavn, fødselsdato, kjønn, høyde, vekt og aktivitetsnivå; personlige detaljer/målforslag | Profilavgrenset UserDefaults; ikke aktiv skysynk | Nødvendighet, lokal behandlingsrolle, art. 6 og eventuell art. 9 må vurderes; særlig obligatorisk fødselsdato | `DatabaseService.deleteLocalData` fjerner profilens personalDetails-nøkkel. Ingen tidsstyrt sletting sett. |
| Matlogger, vann, mål, vekt; logging og oversikt | SQLite i Application Support, med profileier; lokal synkkø | Helseopplysninger i prosjektets klassifisering; grunnlag for fremtidig serverbehandling ikke ferdig avklart | Eieravgrenset lokal sletting er transaksjonell; ingen generell dokumentert ettårsfrist i undersøkt kode. |
| Lagrede måltider og egne produkter; gjenbruk | SQLite; måltids-/produktbilder lagres lokalt | Bilder og fritekst kan inneholde person-/helseopplysninger; må inngå i risikovurdering | Lokale eierdata slettes. Eksport er utvidet med egne produkter og produktbilder. |
| Favoritter og skannhistorikk; raske oppslag | SQLite per profil | Formål og nødvendig lagringstid må dokumenteres | Eieravgrenset sletting; begge inngår i eksporten. |
| Sist brukte mengde/porsjon og gjenbruksvalg | Profil-/produktavgrensede UserDefaults-nøkler (`lastAmount`, `useLastAmount`) | Kan avsløre matvalg/mengder; må omfattes av datakart og sletting | Profilavgrenset fjerning er lagt inn i `deleteLocalData`; verdiene inngår i eksporten. |
| Lokale innstillinger og analyse-/krasjvalg | UserDefaults; SDK-hookene utfører ingen innsamling | Ingen aktiv analyse-/krasjleverandør i undersøkt kode | Enhetsomfattende valg; må skilles fra profilens domeneinnhold. |
| Søketekst/GTIN, IP og appidentifikasjon; produktoppslag | HTTPS til Open Food Facts; lokal katalogcache | Vurder grunnlag, mottakerrolle og ekstern lagring; ikke kall mottakeren databehandler uten vurdering | Leverandørens lagring og tilgang er uavklart. Råvaresøk i medfølgende Matvaretabellen er lokalt. |
| Offentlige produktbilder; visning | HTTPS til URL i produktdata; egen URLSession/URLCache, opptil 50 MB diskcache | Eksterne bildemottakere og IP-overføring må kartlegges fra faktiske URL-er | Cache-policy er implementert; komplett domeneoversikt og sletting av bildecache er ikke verifisert. |
| JSON-eksport med helse-/kontoopplysninger og måltidsbilder | Midlertidig fil, deretter brukerens valgte delingsmottaker | Brukerinitiert eksport; mottaker velges av bruker | `ProfileExportViewModel` bruker `removeExport`. Vern ved krasj/avbrudd og filbeskyttelse er ikke verifisert. |
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
3. `purge_account_data_admin_v1` setter `products.owner_id = null`.
   Dette beviser ikke anonymisering av fritekst/produktinnhold. Kontroller hvilke
   bidrag som kan beholdes og grunnlaget; ikke lov anonymisering uten vurdering.
4. `LocalStore.openDatabase` setter ikke eksplisitt filbeskyttelsesklasse.
   Det betyr ikke at iOS-lagringen er ukryptert. Faktisk Data Protection for
   SQLite, sidefiler, UserDefaults, bilder og eksport må måles på fysisk enhet.
5. Eldre spesifikasjoner omtaler CoreData, ett års serverlagring og kassering av
   usynkede hendelser. Aktiv lokal lagring er SQLite; teksten er ikke grunnlag for
   å slette data eller erklære etterlevelse.
6. Personvernerklæringens delingslenker og App Privacy-opplysninger må kontrolleres
   mot faktisk tilgjengelig funksjon og releasekonfigurasjon.

## Første leveransestatus

| Planpunkt | Status | Neste steg |
| --- | --- | --- |
| P0-1 Ansvar | Juridisk navn oppgitt og erklæring oppdatert; delvis ferdig | Tildel operativ sikkerhetsansvarlig og vurder personvernombud. |
| P0-2 Datakart | Teknisk første kart ferdig; juridisk protokoll uferdig | Avklar grunnlag, lokal rolle, dataminimering, frister og leverandører per rad. |
| P0-3 Leverandører | Ikke verifisert | Kontroller gjeldende Supabase-DPA, underleverandører, SMTP og OFF-lagring i faktisk miljø. |
| P0-4 Risiko/DPIA | Ikke ferdig | Vurder barns bruk, fødselsdato, helseprofilering og omfang; dokumenter DPIA-beslutning. |
| P0-5/6 Lagring, eksport og sletting | Konkrete kontrollfunn identifisert | Rett og test eksport/sletting; kontroller fysisk enhet og staging med syntetiske data. |

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

Ansvarlig kontakt for mottak foreslås å være behandlingsansvarlig på oppgitt
e-post. Operativ stedfortreder og sikker lagring av sakene er ikke avklart.
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
