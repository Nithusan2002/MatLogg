# MatLogg landingsside

Selvstendig kopi av MatLoggs Lovable-prototype. React, Vite og Tailwind; ingen Lovable-konto, runtime, database, analyse eller betapåmelding kreves. De statiske appvisningene er faktiske simulatorbilder fra den lokale utviklingsversjonen, tatt 2026-10-08 med verifisert demomodus (fiktive data). Bildene ligger i `public/screenshots/`. Søk/Mengde/Logg-knappene bytter mellom ekte bilder av én loggingflyt; siden simulerer ikke søk eller logging.

Krever Node.js 22.12 eller nyere.

```sh
cd matlogg-web
npm ci
npm run dev
npm run build
```

Prototypen er publisert på https://nithusan.no/MatLogg/ via GitHub Pages. Workflowen `.github/workflows/landing-pages.yml` bygger og publiserer kun denne siden ved endringer i `matlogg-web/` på `main`, eller via manuell kjøring. Personvern og kontaktadresse er tilgjengelig; bildekilder og lisenslenker finnes på personvernsiden og i `public/bildekilder.txt`. Primærhandlingen åpner en manuell bildedemo; siden tar ikke imot betapåmelding. Før lansering må faktisk drift og personverntekst godkjennes, beta- eller App Store-lenke velges og `noindex` vurderes. Personvernlenken med stor M er kontrollert med HTTP 200 den 8. oktober 2026; `/matlogg` med liten m svarte 404. Lokal redigering publiserer ikke; push til `main` utløser publiseringsworkflowen.

Designkilde: Lovable-prosjekt `84794cb2-b1b1-4308-a80f-f740a521b073`, commit `900d926778abd72bc2a5fddf2dddffc906487660`. Kopiert via fil-API, tilpasset til statisk bygging uten plattformkode.

