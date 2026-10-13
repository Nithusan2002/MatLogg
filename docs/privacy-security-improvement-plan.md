# Forbedringsplan: personvern og sikkerhet i Norge

Dato: 2. oktober 2026. Status: planlagt, ikke gjennomført eller juridisk godkjent.

Arbeidet er startet: [datakart og kontrollstatus](privacy-data-inventory.md).
Behandlingsansvarlig er oppgitt som Nithusan Krishnasamymudali og ført inn i
personvernerklæringen. Øvrige porter er fortsatt åpne.

Avklart 3. oktober 2026: MatLogg skal ha 16 års aldersgrense. Brukeren kjenner
ikke status for Supabase-DPA eller SMTP. Før pilot må 16+-målgruppen gjenspeiles
i onboarding og juridisk tekst, og eksisterende profiler håndteres uten
automatisk sletting. Leverandørpunktene krever kontroll av faktisk oppsett.

## Utgangspunkt og avgrensning

MatLogg er en norsk forbrukerapp for matlogging og oversikt, uten medisinsk
diagnose eller behandling. Personopplysningsloven/GDPR er hovedregelverket.
Vekt, ernæringsmål og tilknyttet spisehistorikk håndteres som helseopplysninger.
HIPAA er ikke dagens releasekrav. Medisinsk bruk og leveranser til helsetjenesten
krever en egen vurdering før scope utvides.

Kodegjennomgangen viser deaktivert klientsynk, Keychain for tokens, serverbasert
identitetskontroll, RLS og funksjoner for eksport og sletting. Dette er tiltak,
ikke bevis på samlet etterlevelse. Faktisk drift, avtaler og releasearkiv er ikke
kontrollert. Lokal lagring fjerner ikke behovet for å kartlegge ansvar og risiko.

Planen supplerer `production-readiness.md`; eksisterende releaseporter består.
Ingen autentisering, datamigrasjon, aldersgrense eller aktivering av synk er
autorisert av denne planen. Ansvarsrollene under er forslag; samme person kan
dekke flere roller, men en navngitt ansvarlig må tildeles hvert punkt.

## Prioritert arbeid

| ID / port | Arbeid og konkret leveranse | Ansvar | Ferdig når |
| --- | --- | --- | --- |
| P0-1 Før ekstern pilot | Identifiser juridisk behandlingsansvarlig, kontakt og ansvar for personvern/sikkerhet. Vurder og dokumenter om personvernombud er påkrevd. | Produkteier + personvernfaglig rådgiver | Juridisk identitet er avklart og publiseringsplassholderen i personvernerklæringen er fjernet; ansvar er navngitt. |
| P0-2 Før ekstern pilot | Lag datakart og behandlingsprotokoll: konto, fødselsdato, mål, vekt, mat/vann, bilder, søk, enhets-ID, kø, eksport, logger og support. Beskriv formål, rettsgrunnlag, lokal/server/tredjepart, mottakere, lagringstid og sletting. Vurder også ansvaret for rent lokal behandling. | Produkteier + teknisk ansvarlig + rådgiver | Hver aktiv dataflyt er koblet til kode og faktisk miljø; artikkel 6 og eventuelt artikkel 9 er vurdert per formål. Uavklarte behandlinger tas ikke i bruk. |
| P0-3 Før ekstern pilot | Kontroller Supabase-avtale/DPA, Auth, SMTP og øvrige faktiske leverandører. Kartlegg region, underleverandører, supporttilgang, logger og backup. Avklar Open Food Facts sin rolle og lagring av søk/IP. | Driftsansvarlig + rådgiver | Gjeldende avtaler og databehandlerroller er dokumentert; eventuell tredjelandsoverføring har vurdert grunnlag og nødvendige tiltak. EØS-region alene regnes ikke som tilstrekkelig bevis. |
| P0-4 Før ekstern pilot | Dokumenter risikovurdering og DPIA-behov, særlig helseopplysninger, mulige mindreårige, kontokobling, feil eierskap og tap av enhet. Vurder nødvendigheten av obligatorisk full fødselsdato. | Produkteier + rådgiver | Begrunnet DPIA-beslutning foreligger; påkrevd DPIA er ferdig og tiltak gjennomført. Eventuell høy restrisiko håndteres etter artikkel 36 før behandling. Alders-/dataminimeringsvalg er avklart uten å innføre en vilkårlig grense. |
| P0-5 Før ekstern pilot | Kontroller iOS Data Protection for SQLite og journal/WAL/SHM, bilder, cache og midlertidige eksportfiler; Keychain-tilgjengelighet; enhetsbackup og sensitive appforhåndsvisninger. Fastsett beskyttelsesnivå som passer local-first. | iOS-ansvarlig | Fysisk enhet demonstrerer forventet oppførsel ved låsing, omstart, eksport og backup. Funn har målrettede rettelser; «SQLite/CoreData er kryptert» brukes ikke som udokumentert påstand. |
| P0-6 Før ekstern pilot | Lag og verifiser lagrings-/slettematrise for lokale profiler, konto, synkkø, serverdata, Auth, delingslenker, eksport, logger og backup. Begrunn 30-dagersperioden. Skill deaktivering fra permanent sletting. | iOS + backend + drift | Eksport og sletting er demonstrert med syntetiske data. Ingen andre profilers data slettes eller eksporteres; slettet konto mister tilgang; purge og backuphåndtering er dokumentert. Eventuell anonymisering er bevist, ikke bare fjerning av bruker-ID. |
| P0-7 Før ekstern pilot | Lag hendelsesrutine med ansvarlig mottaker, vurdering av risiko, sikring av bevis, nødstopp og beslutning om varsling. Etabler kanal for innsyn, retting, sletting og andre rettigheter. | Driftsansvarlig + produkteier | En bordøvelse er gjennomført. Meldepliktige brudd kan meldes uten ugrunnet opphold og om mulig innen 72 timer etter kjennskap; berørte varsles uten ugrunnet opphold ved høy risiko. Alle brudd og vurderinger dokumenteres. Rettighetskrav kan normalt behandles innen én måned. |
| P0-8 Før ekstern pilot | Sammenhold personvernerklæring, onboarding/personvernvalg, App Store-tekst, privacy manifest og faktisk nettverkstrafikk. Rett foreldede spesifikasjoner. | Produkteier + iOS + rådgiver | Tekst beskriver dagens funksjoner og faktiske mottakere. Ingen planlagte funksjoner fremstilles som aktive, og inaktive analysevalg forklares. Juridisk vurdering av identifiserte hull er dokumentert. |
| P1-1 Før offentlig lansering | Verifiser faktisk produksjonsoppsett: separate miljøer, minste privilegium, MFA for administratorer, secrets, TLS, rate limiting, avhengigheter og logging uten helse-/kontodata. | Backend + drift | Konfigurasjon og målrettede sikkerhetstester har dokumenterte resultater. Ingen uavklarte alvorlige funn; staging-eierskapstester dekker kryssbrukertilgang og slettet konto. |
| P1-2 Før offentlig lansering | Demonstrer backup/restore, overvåkning og varsling med syntetiske data; dokumenter hvem som reagerer og hvordan slettede kontoer håndteres ved restore. | Drift | Restore er utført i isolert miljø, slettinger gjenanvendes før åpning, og varsler når ansvarlig. Backup er ikke en skjult permanent kopi. |
| P1-3 Før offentlig lansering | Samle pilotresultater og etterlevelsesbevis i eksisterende releaseport. | QA + produkteier | P0, P1 og `production-readiness.md` har konkrete resultater, navngitt godkjenner og eksplisitt go/no-go. Ingen offentlig lansering på grunnlag av denne planen alene. |
| P2-1 Før helsedatasynk | Avklar artikkel 6-grunnlag og artikkel 9-unntak for opplasting. Hvis uttrykkelig samtykke velges: design separat, forståelig valg med formål, datatyper og tilbaketrekking; dokumenter versjon/tidspunkt. | Produkteier + rådgiver + iOS/backend | Ingen opplasting før gyldig valg. Avslag og tilbaketrekking lar lokal logging fortsette. Eksisterende kø kan ikke omgå tilbaketrekking; sletting og videre lagring etter tilbaketrekking er avklart og forklart. |
| P2-2 Før helsedatasynk | Implementer besluttet samtykke-/tilgangsgrense på klient og server, oppdater protokoll, DPIA, avtaler, personverntekst og App Privacy. Verifiser hele synkkontrakten. | iOS + backend + QA | Tester dekker manipulert klient, utløpt/tilbaketrukket samtykke der relevant, kontobytte, retry, idempotens, eierskap, eksport, purge og kill switch. Alle eksisterende synkporter er grønne før separat aktiveringsbeslutning. |

## Gjennomføring og avhengigheter

1. Start med P0-1 og P0-2: ansvar og datakart styrer resten av arbeidet.
2. Gjennomfør leverandørkontroll og risiko-/DPIA-vurdering før tekniske tiltak
   fastsettes. P0-5 og P0-6 kan undersøkes mens avtalene avklares.
3. Rett konkrete funn i små endringer med relevante fag-skills og målrettede
   tester. Bruk eksisterende services/repositories; ikke legg personvern-IO i views
   eller ny domenelogikk i AppState. Bevar atomisk lokal lagring og synkkø.
4. Ferdigstill tekster og rutiner ut fra faktisk adferd. Kjør ekstern pilot først
   når P0 og øvrige pilotporter er oppfylt. GDPR gjelder også pilotbrukere.
5. Gjennomfør P1 og ta eksplisitt beslutning om offentlig lansering.
6. Behandle P2 som en separat leveranse. Synk forblir av til denne er godkjent.

Avtaledokumenter, identitetsopplysninger og juridiske arbeidsdokumenter lagres i
et tilgangsstyrt område utenfor det offentlige repoet. Repoet kan inneholde
anonymiserte kontrollresultater og referanser, aldri tokens eller brukerdata.

## Målrettet verifisering

- iOS: syntetiske profiler A/B; offline logging; kontobytte og kobling; komplett
  eksport av egne data; sletting; beskyttelse av database, bilder og eksportfiler.
- Supabase: eksisterende pgTAP/Deno-kontroller for eierskap og kontrakt, supplert
  med risikobaserte tilfeller for deaktivering, purge og tilbakeføring fra backup.
- Release: kontroller et faktisk arkiv, releaseflagg og nettverkstrafikk fra
  oppstart, innlogging, søk, skanning, eksport og sletting. Kontroller at matlogger,
  vekt og bilder ikke lastes opp når synk er av.
- Registrer per ID: ansvarlig, dato, miljø/commit, kontroll, pass/fail,
  bevisreferanse, restfunn og neste steg. Planlagte tester er ikke beståtte tester.

## Dokumentasjon som må korrigeres

- `matlogg-legal/privacy.md`: identitet, bekreftede leverandører, lagringstider,
  sletting/backup og dagens funksjoner. Påstanden om anonymiserte produktbidrag
  må kontrolleres mot faktisk kode og anonymiseringsmetode.
- `matlogg-legal/app-store-data-use.md`: faktisk leverandørlagring og releasearkiv.
- `docs/specs/05-data-model-sync.md` §5.9: sammenhold ett års serverlagring,
  anonymiserte logger og kassering av usynkede hendelser med aktiv implementasjon.
  Ikke implementer eldre tekst blindt, særlig når det kan gi datatap.
- `docs/specs/09-risks-mitigation.md`: erstatt udokumenterte påstander om
  GDPR-kompatibilitet, CoreData-kryptering og databasebackup i Keychain/Secure
  Enclave med konkrete tiltak og verifisert status.

## Hvis scope senere blir medisinsk

Før pasientoppfølging eller medisinske beslutningsfunksjoner: kjør produkt-review
og faglig/juridisk vurdering av tiltenkt formål, markedsføringspåstander og faktisk
funksjon. Avklar MDR/medisinsk utstyr, eventuell klassifisering og CE-prosess.
Ved leveranse til helsetjenesten avklares pasientjournalloven,
helsepersonelloven, pasientjournalforskriften, roller og eventuelle avtalekrav fra
Normen. Normen er et rammeverk, ikke en generell sertifisering for forbrukerapper.
En ansvarsfraskrivelse alene avgjør ikke om programvaren er medisinsk utstyr.

## Vedlikehold

Kontroller datakart, avtaler og risiko før hver release som endrer databruk, og
etter leverandørendringer eller sikkerhetsbrudd. Som intern arbeidsrutine foreslås
en kvartalsvis gjennomgang av tilgang og åpne funn, samt årlig øvelse for restore
og hendelser. Dette er anbefalt arbeidsrytme, ikke universelle lovbestemte frister.

## Teknisk oppfølging av sikkerhetsgjennomgang 12. oktober 2026

Status: planlagt. Gjennomgangen var av kildekode og migrasjoner i arbeidskopien,
inkludert eksisterende lokale endringer. Ingen hosted innstillinger eller
database-/RLS-tester ble verifisert. `npm run functions:test` stoppet fordi Deno
ikke var installert/tilgjengelig i PATH. En begrenset mønsterskann av 413 sporede
filer fant ingen gjenkjennelige private nøkler/tokens; dette erstatter ikke
hemmelighetsskann av Git-historikk. Eksisterende pilot- og releaseporter består.

Prioritetene nedenfor er teknisk gjennomføringsrekkefølge, ikke juridiske
risikoklassifiseringer. Backend/iOS/drift er foreslåtte roller; ansvarlig person
avklares ved oppstart. Første leveranse er små lokale rettelser. Hosted endringer
og synkaktivering krever en egen beslutning.

| ID / prioritet | Tiltak og berørte filer | Ferdig når / minste kontroll |
| --- | --- | --- |
| SEC-1 / Høy, før synkaktivering | Håndhev kvote ved den faktiske databasegrensen for `apply_sync_event_v1`, ikke bare i `functions/sync-events/index.ts`. Bruk ny versjonert migrasjon; ikke endre gamle migrasjoner. Avklar om kvoten måler kall eller nye events, retry-semantikk og om avviste transaksjoner skal belaste kvoten. Backend. | pgTAP i isolert lokal database viser at direkte authenticated RPC ikke omgår kvoten, parallelle kall ikke overskrider den, brukere har separate kvoter, og retry/idempotens og kill switch fortsatt fungerer. Kontroller også Edge-kall slik at samme handling ikke belastes utilsiktet to ganger. |
| SEC-2 / Høy, før synkaktivering | Gjør domeneregler like for Edge og direkte RPC. Start med tomt måltidsnavn og strukturen/typekravene i `nutrientsPer100g`; vurder endelige tall, feltlengder og øvrige kontraktsregler målrettet. Berører `_shared/sync-contract.ts` og ny SQL-migrasjon. Ikke gjett manglende næringsdata eller innfør nye verdigrenser uten kompatibilitetsvurdering. Backend. | Regresjonstilfeller viser dagens avvik før rettelse og avvises via både Edge-validator og RPC etterpå. Gyldige eksisterende klientpayloads består. Avvisning gir stabil feil og etterlater verken inbox- eller domenedata. Oppdater synkkontrakten dersom akseptert format endres. |
| SEC-3 / Middels, første lokale leveranse | Utvid `.gitignore` til miljøvarianter, med eksplisitte unntak for eksempel-/malfiler. Kjør tilgjengelig Gitleaks med redigert output mot arbeidskopi og historikk; ikke skriv hemmeligheter i rapporter. Drift. | `git check-ignore` bekrefter at `.env.production`, `.env.staging` og `.env.local` ignoreres, mens `backend/.env.example` fortsatt kan spores. Skannresultat er registrert. Ved ekte funn: separat rotasjon og eventuell historikkopprydding, ikke bare ignore-regel. |
| SEC-4 / Middels, første lokale leveranse | Begrens `APIService.endpointURL` til HTTPS utenfor eksplisitt lokal utvikling, i tråd med Supabase-klienten. Kartlegg berørte legacy-kall før rettelse. iOS. | Målrettet URL-test avviser ekstern HTTP, godtar HTTPS og tillater bare avtalt lokal utviklingsadresse. Ugyldig konfigurasjon gir typet feil. Ingen nettverkskall nødvendig i testen. |
| SEC-5 / Kontrollport, før synkaktivering | Gjør eksisterende Deno- og pgTAP-kontroller kjørbare. Kontroller RLS, grants, kryssbrukerlesing/-skriving/-sletting, deaktivert konto og transaksjonsrollback, inkludert SEC-1/2. Backend/QA. | Målrettede Deno-tester og relevante SQL-tester består mot bekreftet lokal, disponibel database. Registrer commit/arbeidskopi, miljø, antall tester og resultat. Ingen reset av utviklerens eneste data eller hosted miljø. |
| SEC-6 / Kontrollport, før ekstern pilot | Bekreft filbeskyttelse på fysisk iPhone for SQLite/journal/WAL/SHM, Keychain og eksport. Koden setter allerede eksplisitt beskyttelse; dette er verifisering, ikke et påvist fravær av kryptering. iOS/QA. | Dokumentert låsing-/omstart-/eksportkontroll på fysisk enhet bekrefter valgt beskyttelsesnivå og local-first-adferd. Oppdater P0-5 og datakartet med faktisk resultat. |
| SEC-7 / Kontrollport, før serverdata tas i bruk | Les faktisk hosted oppsett for TLS, kryptering, Auth-begrensninger, administratorrettigheter og logging; bruk eksisterende P1-1/P1-2 for backup/restore. Drift. | Konkrete miljøbevis er registrert uten hemmeligheter eller persondata. Ubefestede innstillinger merkes uavklart. Ingen påstand om hosted sikkerhet basert bare på lokal kode. |

Anbefalt rekkefølge: SEC-3/4 → SEC-1 → SEC-2 → SEC-5. SEC-6/7 kan undersøkes
uavhengig. Deno/SQL-testmiljø klargjøres før implementering av SEC-1/2, slik at
regresjonene kan demonstreres før rettelse. Dersom kontraktsregler strammes inn,
vurder ventende lokale events og utrullekkefølge før migrasjonen tas i bruk.

Arkitekturkrav: bevar `View → ViewModel → Repository → Service`, lokal atomisk
domeneskriving/synkkø, tokenbasert eierskap og atomisk inbox/domeneskriving.
Kvotens transaksjonssemantikk må dokumenteres særskilt. Bruk `backend-api` og
`offline-sync` for SEC-1/2, `nutrition-privacy` for næringsdata, `ios-swiftui` for
SEC-4 og `qa-release` ved sikkerhetskritiske endringer og før utrulling.

Synk forblir deaktivert til disse tekniske kontrollene og eksisterende
samtykke-, personvern- og releaseporter er oppfylt. Planen aktiverer ikke synk
og autoriserer ikke produksjonsutrulling eller endringer i tilgang.

## Myndighetskilder

- [Personopplysningsloven og GDPR](https://lovdata.no/dokument/NL/lov/2018-06-15-38): særlig artikkel 5–9, 12–22, 25, 28, 30, 32–37 og 44–49.
- [EDPB: lovlig behandling og sensitive opplysninger](https://www.edpb.europa.eu/sme/be-compliant/process-personal-data-lawfully_en).
- [Datatilsynet: databehandleravtale](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/hvordan-lage-en-databehandleravtale/naar-maa-man-inngaa-databehandleravtale/).
- [Datatilsynet: overføringer utenfor EØS](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/overforing-av-personopplysninger-ut-av-eos/).
- [Datatilsynet: DPIA](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/vurdering-av-personvernkonsekvenser/).
- [Datatilsynet: melding av brudd](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/avvik/meld-avvik-til-datatilsynet/).
- [Helsedirektoratet: journaldata og regelverk](https://www.helsedirektoratet.no/digitalisering-og-e-helse/nasjonal-arkitektur/pasientens-journaldokumenter).
- [DMP: programvare som medisinsk utstyr](https://www.dmp.no/medisinsk-utstyr/programvare-som-medisinsk-utstyr).
