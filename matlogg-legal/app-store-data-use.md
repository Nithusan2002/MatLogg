# App Store Connect – databruk

Sist oppdatert: 28. september 2026

Dette er arbeidsgrunnlaget for App Privacy-skjemaet og må kontrolleres mot den
faktiske produksjonskonfigurasjonen før innsending.

- Kontaktinformasjon: e-post ved kontoopprettelse; knyttet til brukeridentitet;
  brukes til appfunksjonalitet og autentisering.
- Brukerinnhold: matlogger, mål, favoritter, lagrede måltider og frivillig vekt;
  knyttet til brukeridentitet når konto/synk brukes; brukes til appfunksjonalitet.
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
