# App Store Connect – databruk

Sist oppdatert: 19. oktober 2026

Arbeidsgrunnlag, ikke bekreftelse på det innsendte App Privacy-skjemaet.
Kontroller faktisk releasekonfigurasjon, arkiv og leverandørers datalagring før innsending.
Apple regner innsamling som overføring fra enheten med tilgang utover det som
trengs for å betjene forespørselen i sanntid. Ren lokal behandling skal ikke
merkes som innsamling.

## Dagens app: skysynk deaktivert

- Email Address: e-post som Apple deler ved innlogging (inkludert relay-adresse), samt eventuelle eksisterende e-postkontoer; knyttet til bruker;
  App Functionality (autentisering).
- User ID: Supabase bruker-ID og Apple-kontoidentitet; knyttet til bruker;
  App Functionality (autentisering og eierskap).
- Matlogger, vannregistreringer, mål, vekt, favoritter, lagrede måltider,
  personlige detaljer, produktbilder og måltidsbilder behandles lokalt. Ikke merk disse som
  innsamlet gjennom synk når synk er deaktivert.
- Ingen innsamling gjennom analyse- eller krasjrapporterings-SDK er implementert.
  De lokale bryterne endrer ikke dette.
- Data brukes ikke til sporing eller tredjepartsannonsering og selges ikke.
- Open Food Facts mottar aktivt innsendt søketekst eller strekkode, IP-adresse og
  appidentifikasjon. Avklar leverandørens faktiske lagring utover sanntidsoppslaget
  før skjemaet ferdigstilles; Search History og eventuell annen innsamling må
  vurderes dersom data beholdes. Matvaretabellen-søk skjer lokalt.

## Før opplastingssynk aktiveres

- Health: vekt, ernæringsmål og tilknyttet mat-/vannhistorikk; knyttet til bruker;
  App Functionality. Disse skal ikke bare føres som Other User Content.
- Other User Content: vurder øvrig opplastet brukerinnhold separat, som
  brukeropprettede produkter og lagrede måltider, med Health der innholdet
  inngår i brukerens helseoppfølging.
- Device ID: stabil synkenhets-ID overføres med hendelsesbatcher og er knyttet
  til kontoen; App Functionality. Denne kommer i tillegg til User ID.
- Oppdater skjema, manifest og personvernerklæring samlet etter faktisk databruk.
- Avklar artikkel 6-grunnlag og artikkel 9-unntak før opplasting av helseopplysninger.
  Eventuelt uttrykkelig samtykke og tilbaketrekking må være implementert før aktivering.

## Kilder

- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple App Review Guidelines 5.1.3](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research)


## Kandidatvurdering 19. oktober 2026 – fortsatt arbeidsgrunnlag

Kodekontroll ved `55e513b`: kontoskjermen er Apple-only, domeneopplasting er
sperret av `.localOnly`, og analyse-/krasj-SDK er ikke aktivert. Ingen ny
Release-arkivering eller App Store Connect-kontroll er gjort i denne runden.
Det eksisterende personvernmanifestet deklarerer e-post og bruker-ID, ikke
søkehistorikk eller diagnostikk. Manifestet er ikke bevis på et riktig utfylt
App Privacy-skjema.

| Flyt | Forslag / avklaring før innsending |
| --- | --- |
| Apple/Supabase Auth | Behold Email Address og User ID som knyttet til bruker, App Functionality. Skjult e-postskjerm fjerner ikke Apple-delt e-post. |
| Supabase tekniske logger | Avklar beholdte felt, bruk og varighet separat fra konto-ID. Eventuelle ytterligere kategorier og kobling til bruker må vurderes ut fra faktisk bruk. Ingen antatt fast frist. |
| OFF-søk/strekkode | Search History må vurderes dersom søk beholdes utover forespørselen. At MatLogg ikke sender konto-ID beviser ikke at data er uknyttet. |
| IP og bildetrafikk | IP er ikke automatisk Device ID eller Location; klassifiser etter faktisk bruk. Produktbilde-URL og tidspunkt kan også avsløre produktvisning. Retensjon hos bildeverter er uavklart. |
| Lokal mat/vekt/bilder/fødselsdato | Ikke merk ren lokal behandling som innsamling. Fødselsdato er valgfri i undersøkt kode. Vurder SDK-/kandidatadferd før endelig erklæring. |
| Måltidsdeling, Bilder og JSON | Lokalt generert og brukerinitiert. Kontroller Apples unntak og faktisk delingsflyt; ikke anta at all tredjepartsbehandling omfattes av et unntak. Ingen produkt-tokenlenke er funnet. |

[Apples definisjon av innsamling og datakategorier](https://developer.apple.com/app-store/app-privacy-details/)
er kontrollert 19. oktober. Retensjon utover sanntidsbetjening er sentralt;
opplysninger hos relevante tredjepartspartnere inngår. IP klassifiseres etter
bruken. Det er derfor ikke tilstrekkelig å sende inn bare de to eksisterende
manifestkategoriene uten å vurdere leverandørlogger og søk.

Neste steg: lukk mottaker-/retensjonsvurderingen i
`docs/privacy-data-inventory.md`, kontroller faktisk kandidatarkiv og samordne
App Privacy, manifest og publiserte tekster der vurderingen krever det.
Ingen kategorier er endret i manifest eller App Store Connect her.
