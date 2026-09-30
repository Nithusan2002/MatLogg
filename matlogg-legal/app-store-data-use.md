# App Store Connect – databruk

Sist oppdatert: 30. september 2026

Dette er arbeidsgrunnlaget for App Privacy-skjemaet og må kontrolleres mot den
faktiske produksjonskonfigurasjonen før innsending.

- Kontaktinformasjon: e-post ved kontoopprettelse; knyttet til brukeridentitet;
  brukes til appfunksjonalitet og autentisering.
- Brukerinnhold: matlogger, mål, favoritter, lagrede måltider og frivillig vekt;
  knyttet til brukeridentitet når konto/synk brukes; brukes til appfunksjonalitet.
- Brukerinnhold/bilder: valgfrie bilder av næringstabell og produktforside.
  Etikettbilder er private og midlertidige; forsidebilder blir offentlige bare
  etter eksplisitt bidrag til felleskatalog. AI-avlesning og bidrag krever konto.
- Identifikatorer: Supabase bruker-ID og Apple-identitet; brukes til
  autentisering, sikkerhet og eierskap.
- Diagnostikk/analyse: kun dersom brukeren aktiverer de valgfrie bryterne og
  faktisk SDK er konfigurert. Ikke merk dette som samlet før implementasjonen
  er kontrollert.
- Data brukes ikke til sporing eller tredjepartsannonsering og selges ikke.

Supabase er databehandler for konto, autentisering, database, Edge Functions,
backup og opplastingssynk. Open Food Facts mottar aktivt innsendt søketekst
eller strekkode som beskrevet i personvernerklæringen. Matvaretabellen-søk skjer
lokalt i katalogen som følger med appen.

OpenAI er planlagt underleverandør for en valgfri AI-pilot som leser
næringstabeller via MatLoggs Edge Function med `store: false`. Piloten og App
Store-opplysningene skal ikke aktiveres før databehandleravtale, EØS-oppsett,
lagringspraksis og faktisk produksjonskonfigurasjon er kontrollert. Data brukes
ikke til sporing, annonsering eller profilering.
