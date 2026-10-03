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

## Myndighetskilder

- [Personopplysningsloven og GDPR](https://lovdata.no/dokument/NL/lov/2018-06-15-38): særlig artikkel 5–9, 12–22, 25, 28, 30, 32–37 og 44–49.
- [EDPB: lovlig behandling og sensitive opplysninger](https://www.edpb.europa.eu/sme/be-compliant/process-personal-data-lawfully_en).
- [Datatilsynet: databehandleravtale](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/hvordan-lage-en-databehandleravtale/naar-maa-man-inngaa-databehandleravtale/).
- [Datatilsynet: overføringer utenfor EØS](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/overforing-av-personopplysninger-ut-av-eos/).
- [Datatilsynet: DPIA](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/vurdering-av-personvernkonsekvenser/).
- [Datatilsynet: melding av brudd](https://www.datatilsynet.no/rettigheter-og-plikter/virksomhetenes-plikter/avvik/meld-avvik-til-datatilsynet/).
- [Helsedirektoratet: journaldata og regelverk](https://www.helsedirektoratet.no/digitalisering-og-e-helse/nasjonal-arkitektur/pasientens-journaldokumenter).
- [DMP: programvare som medisinsk utstyr](https://www.dmp.no/medisinsk-utstyr/programvare-som-medisinsk-utstyr).
