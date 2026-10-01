# MatLogg landingsside

Selvstendig kopi av MatLoggs Lovable-prototype. React, Vite og Tailwind; ingen Lovable-konto, runtime, database, analyse eller betapåmelding kreves. Alle appvisninger er illustrasjoner, ikke faktiske skjermbilder. Demoen bruker kun midlertidig state.

Krever Node.js 22.12 eller nyere.

```sh
cd matlogg-web
npm ci
npm run dev
npm run build
```

Publiser innholdet i `dist/` på en statisk vert når siden er godkjent. Ingen produksjonsutrulling er gjort. Før lansering: erstatt illustrasjoner med ekte appskjermbilder, koble inn godkjent personvern/kontakt og valgt beta- eller App Store-lenke, og fjern `noindex` når siden skal indekseres. Betaknappene viser foreløpig kun en prototypemelding.

Designkilde: Lovable-prosjekt `84794cb2-b1b1-4308-a80f-f740a521b073`, commit `900d926778abd72bc2a5fddf2dddffc906487660`. Kopiert via fil-API, tilpasset til statisk bygging uten plattformkode.

