# Implementeringsplan: lokal lagring ved første lansering

Dato: 3. oktober 2026. Status: implementert og målrettet fysisk QA bestått. Enhetsrestore og produksjonsutrulling er ikke utført.

## Beslutning og avgrensning

MatLogg lanseres foreløpig med lokale domenedata. Matlogger, vann, mål,
vekt, favoritter, egne produkter, lagrede måltider og bilder skal ikke lastes
opp gjennom synk. Skykopi, gjenoppretting fra konto og flerenhetssynk er senere
scope. Ingen stackendring eller abonnementskjøp inngår.

Arbeidsantakelse: valgfri konto beholdes med dagens Supabase Auth. Katalogsøk
og skanning bruker fortsatt Open Food Facts når brukeren ber om oppslag.
«Lokal lagring» betyr derfor ikke at appen aldri bruker nett eller eksterne
tjenester. Fjerning av konto eller endringer i auth/tilgang er eget scope.

Planen bygger på arkitekturprinsippene, offline-adferd, gjeldende kode,
releaseporten og den eksisterende personvernplanen. Sistnevnte består for
aktive behandlinger; lokal lagring er ikke en samlet personverngodkjenning.

## 1. Samordne scope og releasekrav

Oppdater produktbrief, MVP-scope, offline-adferd, prosjektstatus og
beslutningslogg med lokal lagring som den avtalte første lanseringen.

Del produksjonsberedskap i krav for aktiv lokal app/konto og senere krav før
opplasting åpnes. Backup/PITR for domenedata, synk-recovery og flerenhetsstøtte
skal ikke blokkere en lansering som ikke tilbyr disse tjenestene. Serverbasert
konto trenger fortsatt riktige avtaler, sikkerhet, sletting og driftsvurdering.
Ingen historiske testresultater eller kjente serverfunn fjernes.

**Ferdig når:** dokumentene beskriver samme scope, og ingen aktiv funksjon
lover serverkopi eller gjenoppretting fra konto.

## 2. Gjør lokal lagring til en eksplisitt opplastingspolicy

Behold begge eksisterende synkflagg av. Innfør en liten, testbar policy ved
app-roten som eksplisitt forbyr domeneopplasting i denne lanseringen.
SyncEngine og eventuell tilgjengelighets-/statusberegning bruker denne
policyen; views utfører ingen IO eller policylogikk. Kontroller også alternate
initializers og shared-oppsett, slik at de ikke omgår grensen.

Et framtidig flaggbytte alene skal ikke kunne sende historiske lokale data.
Når skysynk senere implementeres, må eksplisitt brukervalg, historikkvalg og
serverens nødvendige autorisasjons-/samtykkegrense designes og testes før
policyen åpnes. Kontoopprettelse eller lokal kontokobling er ikke godkjenning
av opplasting. Denne planen implementerer ikke framtidig samtykkeflyt.

Bevar atomisk lokal domeneskriving og synkhendelse som arkitekturen krever.
Ikke slett gamle køhendelser, merk dem som acked eller omdefiner quarantined
som lokal lagringsmodus. Køen forblir intern, uten opplasting eller aktive
retry-timere. Vurder lagringsvekst fra en langvarig, hvilende kø; destruktiv
komprimering eller migrasjon inngår ikke uten egen vurdering.

**Ferdig når:** automatisk og manuell synk, appstart, foreground, nett tilbake
og kontokobling gir null upload-kall, også når synkflagget settes på i en test.
Logging, redigering, sletting og angre fungerer fortsatt atomisk lokalt.

## 3. Tilpass brukerflyt og norsk tekst

Gå målrettet gjennom onboarding, konto/kontokobling, Profil, synkstatus på
Hjem og eksport-/slettebekreftelser. Gjenbruk eksisterende komponenter og
semantiske tokens. Ingen ny hovedskjerm eller påminnelsessystem er nødvendig.

- Primær lagringsstatus: «Lagret på denne enheten».
- Kontoforklaring: «Kontoen brukes til innlogging. Matloggene dine lagres
  foreløpig bare på denne enheten.»
- Kort datatapsinformasjon ved førstegangsbruk og i Profil:
  «Vi har ingen skybackup av matloggene dine. Data kan gå tapt hvis du sletter
  appen eller mister telefonen. Du kan eksportere en kopi under Profil.»
- Eksporthandling: «Eksporter data». Ikke kall eksporten en gjenopprettbar
  sikkerhetskopi dersom appen ikke støtter import.

Skjul utilgjengelige synk-/retry-handlinger og meldinger om ventende opplasting.
Skille tydelig mellom lokal lagringsfeil og en hvilende synkkø. Ikke skjul
faktiske lokale feil eller nettverksfeil fra produktkatalogen.

**Ferdig når:** konto ikke framstår som backup, status er konsistent også
offline og ved eksisterende dead-letter-hendelser, og tekst/handlinger fungerer
med stor tekst og VoiceOver. Faneskjermer følger eksisterende tabbar-clearance.

## 4. Verifiser eksport, filbeskyttelse og enhetsbackup

Kontroller SQLite og journal/WAL/SHM, måltidsbilder, produktbilder,
profil-ID/preferanser og eksportfiler. Kartlegg hva iOS-backup inkluderer,
hva som er ekskludert, og hvordan fil-/Keychain-beskyttelse påvirker restore.
Ikke lov at iCloud-/Finder-backup fungerer før det er demonstrert.

Verifiser eksport med syntetiske data: riktig profileier, historikk, mengde,
enhet, kilde, porsjonssnapshot, mål, vekt, vann og dokumenterte bildedata.
Kontroller midlertidige eksportfilers beskyttelse og opprydding.
Eksport og app-import er forskjellige funksjoner; ny import er ikke i scope.

En restore-øvelse må bruke disponibel QA-app/testenhet. Ikke slett brukerappen,
nullstill brukerens iPhone eller gjenopprett hele telefonen uten særskilt
avklaring. Kontroller at gjenopprettet profileier kan åpne egne lokale data,
også dersom kontotoken ikke følger backupen.

**Ferdig når:** eksportens faktiske innhold er testet, backup-/restore-status
er dokumentert med pass/fail eller konkret uverifisert punkt, og brukertexten
ikke lover mer enn kontrollene viser. Kritiske beskyttelsesfunn får målrettede
rettelser før release.

## 5. Samordne personvern og distribusjonsopplysninger

Oppdater personvernerklæring, datakart og aktuelle onboardingtekster for den
faktiske lagringen. Bevar beskrivelsen av Supabase Auth og eksterne katalogkall.
Kontroller konto-/lokalsletting, eksport og eksisterende juridiske åpne punkter.
Gjennomgå App Store-opplysninger og privacy manifest mot aktive tjenester;
ikke fjern reell datainnsamling fra opplysningene fordi domenesynk er av.

**Ferdig når:** tekster og distribusjonsopplysninger samsvarer med observerte
dataflyter. Uavklarte juridiske beslutninger markeres, ikke antas løst av kode.

## 6. Målrettet QA og ferdigvurdering

Kjør bare berørte auth-/policy-/synk-, lagrings-/migrasjons- og eksporttester.
Legg til regresjonstester for null opplasting og isolasjon mellom profiler.
Bruk syntetiske transportspioner; ikke send ekte helsedata til staging.

Kjør få UI-tester for lokal førstegangslogging, profilinformasjon, eksport og
gjenåpning på separat QA-app. Kontroller på fysisk iPhone at egne data består
ved omstart, bakgrunn/foreground og offline-bruk. Test oppgradering fra dagens
lokale skjema med syntetisk database, uten å resette ekte data.

Gjennomgå eksplisitt avhengighetsretning, app-root-injeksjon, eierskap,
local-first og atomiske transaksjoner mot architecture-principles.md.
Oppdater production-readiness.md med faktiske resultater og go/no-go for
lokal lansering. Produksjonsutrulling er en separat, eksplisitt beslutning.

## Rekkefølge, berørte områder og stoppunkter

Implementer i rekkefølgen 1 → 2 → 3 → 4 → 5 → 6, med relevante fag-skills.
Forventede områder: app-root/feature-policy, SyncEngine, smal status-state,
onboarding/Profil/Hjem, eksport/lokal filhåndtering og målrettede tester/docs.
Backend/synkformat endres bare dersom en konkret kontroll viser behov; ingen
deploy, ny databaseplattform, kontofjerning, import eller betalt tjeneste er
del av standardløpet.

Stopp før destruktiv kø-/datamigrasjon, endring av auth/tilgang, betalt
backupoppsett, full enhetsrestore eller produksjonsutrulling. Vis konkrete
konsekvenser og innhent nødvendig avklaring. Planen autoriserer ikke disse
handlingene eller automatisk framtidig opplasting.

## Ferdigvurdering

76 målrettede enhetstester og tre fysiske UI-flyter bestod. Eksport, filvern,
hvilende kø, status og scope er implementert. Se faktiske resultater og
avgrensede uverifiserte releasepunkter i [produksjonsberedskap](production-readiness.md).
Skills brukt: product-review, product-design, ios-swiftui, offline-sync,
nutrition-privacy og qa-release. Antakelsen om valgfri konto og eksterne
katalogoppslag er beholdt. Ingen nye arkitekturavvik eller backenddeploy.
