# Apple Helse – første integrasjon

Dato: 2026-10-02. Godkjent scope-utvidelse; produksjon/pilot er ikke godkjent.

## Produkt og flyt

Profil → Apple Helse tilbyr tre uavhengige valg, avslått som standard:
kalorier/makroer ut, vekt inn og manuelt registrert vekt ut. iOS spør om akkurat
valgte datatyper. Appvalgene uttrykker ønsket overføring, ikke bevis på tillatelse.
Ingen tilgangsdialog åpnes automatisk ved oppstart eller retry.

Mat og manuell vekt eksporteres ved lokal opprettelse eller endring etter
aktivering; gamle registreringer eksporteres ikke ved tilkobling. En endring av
en gammel registrering kvalifiserer. Ved ny aktivering eksporteres ikke perioden
integrasjonen var avslått. Endring/sletting gjelder tidligere egne overføringer.
Enhetsbruk, kalorimål og personlige detaljer endres ikke av import.
Vann, aktivitet, søvn, dynamiske mål og import av mat er utenfor denne leveransen.

Første vektimport henter siste 90 dager. Det samme starttidspunktet brukes på
senere anchored queries; nye og slettede målinger hentes når appen åpnes, blir
aktiv, eller brukeren velger Oppdater nå. Ingen bakgrunnslevering. Importert
historikk beholdes til frakobling/profilsletting. Tom lesing kan bety manglende
tilgang eller manglende data; appen kan ikke skille dette sikkert.

Oversikt viser de siste registreringene med «Vis hele vekthistorikken» for eldre
dager. Historikken viser én vekt per dag: manuell vekt først, ellers siste Helse-måling.
Lik tid avgjøres stabilt av sample-ID. Kilde vises og import er skrivebeskyttet;
retting/sletting gjøres i Helse. Dager grupperes i gjeldende lokal tidssone.

## Arkitektur og lagring

View → HealthIntegrationViewModel → HealthIntegrationRepository → HealthKitClient
og lokal lagring. WeightHistoryRepository kombinerer manuelle og importerte
verdier uten å skrive import gjennom HealthProfileRepository. Avhengigheter
injiseres ved app-roten. AppState har ingen HealthKit-logikk.

SQLite-migrasjon 8 legger til profilinnstillinger og lokalt eksportregister/
outbox. Domeneskriving, eksisterende canonical synkhendelse og HealthKit-jobb
skrives atomisk. HealthKit-registeret sendes ikke gjennom sync_queue.
Hver jobb har stabil syncIdentifier, økende revisjon, event-ID, canonical type
(`health.upsert`/`health.delete`) og schemaVersion 1.
Retry beholder revisjon/event-ID; bekreftelse av gammel jobb fjerner ikke nyere
endringer. Køen samler siste ønskede verdi per sample; næringsstoffer behandles
uavhengig slik at delvis tilgang ikke blokkerer resten.

Eksport bruker lagrede loggverdier og tidspunkt, med kcal/g/kg. Lokal valgfri
nutritionSource bevares gjennom nye logger, retting, gjenbruk og angre; legacy
nil forblir ukjent. Mengde og enhet følger eksportgrunnlaget. Fullført register
beholder bare identitet/type/revisjon/status/tidspunkt; verdier/proveniens fjernes.
Ingen endring i Supabase-kontrakt eller backend. Produksjonssynk forblir av.

Helse-vekt og query-anchor lagres sammen i en separat atomisk JSON-cache med
NSFileProtectionComplete og isExcludedFromBackup. Ingen kopier i domenetabell,
Supabase, analyse eller krasjlogger. MatLoggs JSON-eksport inneholder manuell vekt,
ikke den disponible Helse-cachen; originalmålingene administreres i Helse. HealthKit returnerer HKQuantity; klienten
henter vekten i kg og lagrer dette eksplisitt som returnert enhet. Opprinnelig
brukerinnskrevet enhet er ikke tilgjengelig som eget offentlig HKQuantity-felt
og rekonstrueres ikke. Cachemodellen støtter eksplisitt kg/lb ved IO-grensen.

Alle native operasjoner serialiseres, også over profil-/tilkoblingsbytte.
Eier, kontekst og connection-ID kontrolleres før/etter asynkrone grenser.
En allerede sendt native operasjon kan fullføres ved frakobling, men videre
arbeid stoppes og gamle resultater får ikke endre aktiv profil eller gjenskape
cache. Eksportidentiteter beholdes når lokal profil knyttes til konto.

## Frakobling og sletting

Frakobling stopper jobber og fjerner import/anchor; manuelle data og tidligere
HealthKit-eksport beholdes. Et minimalt register bevares for separat, bekreftet
opprydding. Opprydding kobler fra og sletter bare egne samples identifisert av
registeret og HKSource.default(). Delvis feil beholdes som ventende og rapporteres;
brukeren kan gjenta oppryddingen eller slette i Helse.

Profilsletting fjerner lokal cache/innstillinger/register og domenedata, men
sletter ikke automatisk eksporterte Helse-data. Sletteflyten forklarer at brukeren
må rydde i Apple Helse før profilsletting eller i Helse-appen etterpå.

## Aktivering og QA

`FeatureFlags.healthIntegrationEnabled` er av som standard og alltid av i Release.
Debug kan aktiveres med `--enable-healthkit`. `--skip-auth`, demomodus,
`--healthkit-fake` og enhetstestvert bruker fake; disse åpner aldri HKHealthStore.
Ekte iPhone-test bruker vanlig lokal-/kontoflyt og bare `--enable-healthkit`.
Deaktivering stopper HealthKit-arbeid og ny køing, uten å slette brukerdata.

Målrettede tester ligger i HealthIntegrationTests og HealthIntegrationUITests.
Kjør sammen med berørte lagrings-/vektregresjoner. Før pilot kreves fysisk iPhone:
full/delvis tilgang, avslag, tilbakekalt tilgang, låst enhet, restart under
skriving/sletting, dataretting i Helse, VoiceOver og stor tekst. Kontroller
signering/capability, norske usage descriptions og personvern-/App Store-tekst.
Registrer resultat og eksplisitt go/no-go før Release-flagget endres.
Simulator/fake kan ikke bevise native HealthKit-rettigheter eller Apple-synk.
