# MatLogg landingsside

Selvstendig kopi av MatLoggs Lovable-prototype. React, Vite og Tailwind; ingen Lovable-konto, runtime, database, analyse eller betapåmelding kreves. De statiske appvisningene er faktiske simulatorbilder fra den lokale utviklingsversjonen, tatt 2026-10-01 med verifisert demomodus (fiktive data). Bildene ligger i `public/screenshots/`. Den klikkbare nettdemoen er en merket illustrasjon og bruker kun midlertidig state.

Krever Node.js 22.12 eller nyere.

```sh
cd matlogg-web
npm ci
npm run dev
npm run build
```

Prototypen er publisert på https://nithusan.no/MatLogg/ via GitHub Pages. Workflowen `.github/workflows/landing-pages.yml` bygger og publiserer kun denne siden ved endringer i `matlogg-web/` på `main`, eller via manuell kjøring. Før lansering: koble inn godkjent personvern/kontakt og valgt beta- eller App Store-lenke, og fjern `noindex` når siden skal indekseres. Betaknappene viser foreløpig kun en prototypemelding.

Designkilde: Lovable-prosjekt `84794cb2-b1b1-4308-a80f-f740a521b073`, commit `900d926778abd72bc2a5fddf2dddffc906487660`. Kopiert via fil-API, tilpasset til statisk bygging uten plattformkode.

