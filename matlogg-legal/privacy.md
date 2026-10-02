Personvernerklaering – MatLogg
Sist oppdatert: 1. oktober 2026

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
  - Fødselsdato må fylles inn når du lagrer Personlige detaljer. Den lagres lokalt per profil og brukes som grunnlag for veiledende målforslag. Øvrige felt i Personlige detaljer er valgfrie.
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
  - Konto og autentisering behandles for å levere tjenesten (GDPR artikkel 6 nr. 1 bokstav b).
  - Vekt, ernæringsmål og tilknyttet spisehistorikk håndteres som helseopplysninger. Data som bare ligger på enheten, er ikke tilgjengelige for oss gjennom appen.
  - Skysynk er deaktivert i dagens versjon. Før opplasting av helseopplysninger åpnes, skal både grunnlag etter artikkel 6 og unntak etter artikkel 9 være avklart og dokumentert. Tjenestebehov alene er ikke tilstrekkelig etter artikkel 9. Dersom uttrykkelig samtykke brukes, skal det innhentes før opplasting, og brukeren skal kunne trekke det tilbake og fortsette lokal logging.
  - Det samles ikke inn bruksanalyse eller krasjrapporter gjennom et slikt SDK i dagens versjon.

5. Lagring og “offline-first”

MatLogg er “offline-first”. Mat-, mål- og vektdata lagres lokalt på enheten. Skysynk er deaktivert i dagens versjon; disse dataene lastes derfor ikke opp av synkfunksjonen. Konto og autentisering bruker Supabase når du velger å logge inn. Du kan bruke lokal logging uten konto eller nettilgang.

6. Deling med tredjepart

Vi kan dele begrensede data med:
  - Supabase som databehandler for konto og autentisering. Database, Edge Functions, backup og opplastingssynk er del av serverplattformen, men opplastingssynk er deaktivert i dagens appversjon. Prosjektene skal ligge i en valgt EØS-region.
  - Open Food Facts for oppslag av produktdata nar du aktivt soker etter merkevarer eller skanner, inkludert nar du ber om oppdaterte produktdata. Foresporselen inneholder soketekst eller strekkode og vanlig teknisk tilkoblingsinformasjon som IP-adresse og appens identifikasjon. Sok i den medfolgende Matvaretabellen-katalogen skjer lokalt og deles ikke med Matvaretabellen.
  - Eventuelle leverandorer for drift (hosting/database) som behandler data pa vare vegne.

Vi selger ikke persondata.

7. Valgfrie data: analytics og krasjrapporter

Det er ikke koblet inn et SDK for bruksanalyse eller krasjrapportering i dagens appversjon. Bryterne under Profil → Personvern & valg lagrer bare valget lokalt; de starter ingen slik innsamling.

Før en eventuell tjeneste tas i bruk, skal leverandør, datatyper, formål, lagring og nødvendige valg eller samtykker beskrives. Opplysninger skal ikke omtales som anonyme uten dokumentert anonymisering. Matlogger, vekt, mål, synkpayloads og kontoidentifikatorer skal ikke sendes til analyse- eller krasjrapportering.

8. Kamera og andre tillatelser
  - Kamera brukes når du selv starter skanning eller velger «Ta bilde» ved manuell produktregistrering. iOS spør om kameratilgang før første bruk.
  - Måltidsbilder er valgfrie og velges gjennom iOS sin bildevelger uten tilgang til hele biblioteket. Bildet komprimeres uten original fotometadata og lagres bare lokalt med det lagrede måltidet. Det lastes ikke opp eller synkroniseres. Bildet er med i lokal dataeksport og fjernes ved sletting av måltidet eller lokale profildata.
  - Produktbilder er valgfrie. Du kan ta et bilde eller velge ett bilde gjennom iOS sin bildevelger uten å gi tilgang til hele bildebiblioteket. Bildet komprimeres uten original fotometadata og lagres med produktet i den lokale databasen. Det lastes ikke opp eller synkroniseres. Ved sletting av lokale profildata fjernes også de lagrede produktbildene.

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

## Valgfri Apple Helse-integrasjon

Integrasjonen er foreløpig bare tilgjengelig i særskilt aktivert pilot/utviklingsversjon.
Den ordinære Release-versjonen har funksjonen deaktivert. Under Profil → Apple Helse
velger du separat om MatLogg skal dele kalorier og makronæringsstoffer, hente vekt
eller dele vekt du registrerer i MatLogg. Apple Helse ber om tilgang til de valgte
datatypene. Du kan endre tilgangene i Helse-appen.

Ved tilkobling hentes siste 90 dagers vekt, deretter nye og slettede målinger.
Disse lokale kopiene lagres med filbeskyttelse uten automatisk backup og sendes
ikke til MatLoggs server, analyse eller krasjrapportering. Dine mål endres ikke
automatisk. Mat og manuell vekt deles bare når du registrerer eller endrer dem
etter aktivering; eldre historikk deles ikke automatisk.

Frakobling stopper overføring og fjerner hentet vekt fra MatLogg. Data som allerede
er delt med Helse beholdes der. Andre apper du har gitt tilgang i Helse kan lese
dem. MatLogg beholder et minimalt lokalt register over egne overføringer slik
at du kan velge «Slett data MatLogg har delt med Helse». Dette valget sletter bare
MatLoggs egne overføringer fra profilen, og rapporterer dersom sletting ikke lykkes.
Profilsletting fjerner MatLoggs lokale kopier/register, men sletter ikke automatisk
data i Helse. Rydd der før profilsletting, eller slett dataene direkte i Helse-appen.
