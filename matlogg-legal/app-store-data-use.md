# App Store Connect – databruk

Sist oppdatert: 1. oktober 2026

Arbeidsgrunnlag, ikke bekreftelse på det innsendte App Privacy-skjemaet.
Kontroller faktisk releasekonfigurasjon, arkiv og leverandørers datalagring før innsending.
Apple regner innsamling som overføring fra enheten med tilgang utover det som
trengs for å betjene forespørselen i sanntid. Ren lokal behandling skal ikke
merkes som innsamling.

## Dagens app: skysynk deaktivert

- Email Address: e-post ved kontoopprettelse og innlogging; knyttet til bruker;
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
