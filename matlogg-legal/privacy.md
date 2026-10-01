Personvernerklaering – MatLogg
Sist oppdatert: 30. september 2026

MatLogg er en norsk iOS-app for enkel mat- og naeringslogging. Vi tar personvern pa alvor og samler inn minst mulig data for at appen skal fungere.

1. Hvem er ansvarlig?

Behandlingsansvarlig: Matlogg
Kontakt: nithusank.2002@gmail.com

(Fyll inn dette for publisering.)

2. Hvilke data behandler vi?

Konto og innlogging
  - Du kan bruke MatLogg lokalt uten konto. Da lagres mat-, mål- og vektdata på enheten under en tilfeldig lokal profil-ID.
  - Nar du oppretter konto med e-post/passord, handterer Supabase Auth e-post, bruker-ID, e-postbekreftelse og en sikkert avledet passordhash. Vi lagrer aldri passordet i klartekst og krever ikke navn. Du kan valgfritt lagre et visningsnavn under Personlige detaljer. Det lagres lokalt per profil og synkroniseres ikke.
  - Ved Apple-innlogging handterer Supabase Apple sin stabile kontoidentifikator, e-postadressen Apple deler og en MatLogg-bruker-ID. Vi mottar ikke Apple-passordet ditt.
  - Hvis Apple og en bekreftet e-postkonto har samme verifiserte e-postadresse, kan Supabase automatisk koble identitetene til samme konto.

Det du logger i appen
  - Vannregistreringer: ett glass per registrering, med dato, tidspunkt og profileier. Ingen antatt mengde i ml.
  - Logginnslag (dato, maltid, produkt/ravare, mengde).
  - Lagrede maltider du oppretter for gjenbruk, inkludert navn, matvarer,
    mengder og lagret naeringsgrunnlag/kilde.
  - Mal (kalorier og makroer) og innstillinger (f.eks. haptics/lyd og kildevisning).
  - Valgfri fremgang/vektlogg dersom du velger a bruke den.
  - Skann-historikk (strekkoder du har skannet) for raskere gjenbruk.

Produktdata
  - Nar du skanner, sendes strekkoden til Open Food Facts for a hente produktinformasjon. For GS1 Data Matrix sendes bare produktnummeret (GTIN); dato, lotnummer og andre sporbarhetsfelt lagres eller sendes ikke.
  - Ravaredelen fra Matvaretabellen folger med appen og sokes lokalt pa enheten. Nar du aktivt sender inn et navnesok etter merkevarer, sendes soketeksten til Open Food Facts. Sok sendes ikke for hvert tastetrykk.
  - Eksterne katalogtreff kan lagres lokalt pa enheten for raskere oppslag. Brukeropprettede produkter kan lagres og synkroniseres separat nar synk er aktivert.
  - Du kan opprette egne matvarer og lagre ufullstendige utkast lokalt. Næringsgrunnlag (per 100 g eller per 100 ml), råverdier og datakilde bevares uten at manglende verdier gjettes.

Bilder, etikettavlesning og felleskatalog (valgfrie pilotfunksjoner)
  - Hvis du selv velger det, kan du ta eller velge et bilde av næringstabellen. Bildet rettes opp, komprimeres og lagres uten EXIF- eller posisjonsmetadata.
  - Tekstgjenkjenning skjer først lokalt på enheten. Når AI-avlesning er aktivert og du har en konto, lastes etikettbildet til privat, midlertidig lagring hos Supabase og behandles gjennom en MatLogg-styrt Edge Function hos OpenAI. OCR-tekst og bilde brukes bare til å foreslå strukturerte næringsverdier. Forslaget må kontrolleres og kan redigeres; manglende verdier skal ikke gjettes.
  - OpenAI-kallet bruker `store: false`. Før pilot skal MatLogg konfigurere tilgjengelig EØS-behandling og databehandleravtale. OpenAI kan beholde begrensede sikkerhetslogger i samsvar med leverandørens gjeldende vilkår; pilot skal ikke aktiveres før dette er kontrollert og kommunisert.
  - Etikettbildet publiseres aldri. Det slettes senest 30 dager etter at bidraget er avgjort. Ubehandlede bidrag og tilhørende midlertidige bilder utløper etter 90 dager.
  - Et forsidebilde er valgfritt for en privat vare. Hvis du uttrykkelig velger å bidra til felleskatalogen, kreves forsidebilde, merke, komplette obligatoriske næringsverdier og samtykke til deling. Forsidebildet beholdes bare hvis produktet publiseres; ellers slettes det etter avgjørelse.
  - Bidrag publiseres som «Felleskatalog · Ikke verifisert» eller sendes til kontroll. De blir aldri automatisk merket som verifisert. Hjemmelagde og personlige produkter forblir private.

Deling
  - Hvis du deler et produkt, genererer vi en delingslenke (token) som gjor at mottaker kan se en forhandsvisning og importere produktet i appen.

3. Hvorfor behandler vi dataene?

Vi bruker data for a:
  - La deg logge mat og se historikk over tid.
  - La deg lagre og gjenbruke egne maltider uten a velge hver matvare pa nytt.
  - Vise garsdagens maltid som et valgfritt forslag til raskere logging. Dette beregnes lokalt pa enheten, uten a sende spisehistorikk til en ekstern AI-tjeneste. Et forslag lagres som et nytt maltid bare nar du velger a loggfore det.
  - Knytte lokale data til kontoen etter at du bekrefter det. Dagens synk støtter bare opplasting fra denne enheten; gjenoppretting og synk mellom enheter er ikke tilgjengelig ennå.
  - Gi raskere oppslag ved skanning (cache/historikk).
  - Forbedre datakvalitet (f.eks. markere kilde og handtere “ikke funnet”/brukeropprettede produkter).
  - Gjore appen stabil og sikker.

4. Rettslig grunnlag (GDPR)

Vi behandler data fordi:
  - Det er nodvendig for a levere tjenesten (konto, lagring, logging, synk).
  - Du kan gi samtykke til valgfrie funksjoner som analytics/krasjrapportering (se punkt 7).

5. Lagring og “offline-first”

MatLogg er “offline-first”, som betyr at data normalt lagres lokalt pa enheten din og synkroniseres nar nett er tilgjengelig (hvis synk er aktivert). Du kan bruke appen uten konstant nettilgang.

6. Deling med tredjepart

Vi kan dele begrensede data med:
  - Supabase som databehandler for konto, autentisering, database, Edge Functions, backup og opplastingssynk. Prosjektene skal ligge i en valgt EØS-region.
  - OpenAI som underleverandor for valgfri AI-avlesning av næringstabeller når pilotfunksjonen er aktiv og du starter den. MatLogg sender et midlertidig bilde, lokal OCR-tekst og språk, men ikke navn, e-post, matlogg eller mål.
  - Open Food Facts for oppslag av produktdata nar du aktivt soker etter merkevarer eller skanner. Foresporselen inneholder soketekst eller strekkode og vanlig teknisk tilkoblingsinformasjon som IP-adresse og appens identifikasjon. Sok i den medfolgende Matvaretabellen-katalogen skjer lokalt og deles ikke med Matvaretabellen.
  - Eventuelle leverandorer for drift (hosting/database) som behandler data pa vare vegne.

Vi selger ikke persondata.

7. Valgfrie data: analytics og krasjrapporter

Du kan velge a dele:
  - Anonym bruksstatistikk (for a forbedre appen).
  - Anonyme krasjrapporter (for a gjore appen mer stabil).

Disse er valgfritt og kan slas av/pa nar som helst i Profil → Personvern & valg.

8. Kamera og andre tillatelser
  - Kamera brukes kun nar du selv starter strekkodeskanning, dokumentkamera for næringstabell eller produktfotografering. iOS spor om tillatelse forste gang kameraet brukes.
  - Bilder du velger fra bildebiblioteket behandles etter de samme reglene. MatLogg bruker iOS sin bildevelger og ber ikke om generell tilgang til hele biblioteket.

9. Hvor lenge lagrer vi data?

Vi lagrer data sa lenge kontoen din er aktiv eller til du sletter dem. Nar du sletter kontoen, fjernes lokale data umiddelbart. Serverkontoen markeres for sletting, innlogging sperres og kontodata slettes permanent etter 30 dager. Brukeropprettede produktbidrag kan beholdes anonymisert for datakvalitet. Du kan nar som helst:
  - Laste ned dataene dine.
  - Slette konto og tilknyttede data (se punkt 10).

10. Dine rettigheter

Du har rett til:
  - Innsyn i data vi har om deg.
  - Retting av feil.
  - Sletting av data (“retten til a bli glemt”).
  - Dataportabilitet (eksport av data).
  - A trekke tilbake samtykke til valgfrie data nar som helst.

Du kan gjore dette i appen (Profil) eller ved a kontakte oss pa e-post.

11. Kontakt og klage

Kontakt oss pa nithusank.2002@gmail.com.
Du kan ogsa klage til Datatilsynet hvis du mener behandlingen bryter regelverket.
