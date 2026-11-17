# Sentrert Loggfør og Profil fra toppfeltet

Status: implementeringsforslag, 17. november 2026. Ingen kodeendring i denne planen.

## Mål og avgrensning

Bunnmenyen skal være visuelt balansert: Hjem · Loggfør · Utvikling.
Loggfør beholder den store korallknappen og plasseres på skjermens horisontale
midtpunkt. Profil flyttes til et personikon øverst på Hjem og Utvikling.
Dette er en navigasjons- og designendring innen eksisterende funksjonalitet.
Ingen nye data, kontoendringer, nettverkskall eller endringer i logging/synk.

## Ønsket oppførsel

- Tre like brede plasser i bunnmenyen, med Hjem til venstre, Loggfør i midten
  og Utvikling til høyre. Behold eksisterende farger, ikoner og knappestil.
- Hjem og Utvikling er faner. Loggfør er fortsatt en handling; åpning/lukking
  skal beholde aktiv fane, rulleposisjon, valgt dato og måltidskontekst.
- Personikonet ligger øverst til høyre i begge hovedskjermenes toppområde,
  uten å fortrenge dagvelger, overskrifter eller eksisterende handlinger.
  Det har minst 44 × 44 pt trykkflate og VoiceOver-navn «Åpne profil».
- Profil åpnes som fullskjermsvisning med sin eksisterende NavigationStack.
  Ikke legg en ekstra NavigationStack rundt ProfileView. På profilroten vises
  «Lukk»; undersider beholder vanlig tilbakeknapp. Lukking returnerer til
  samme fane og bevarer underliggende skjermtilstand. Bunnmenyen vises ikke i Profil.
- Innstillinger, favoritter, lagrede måltider og øvrige profilfunksjoner
  forblir tilgjengelige. Interne snarveier som tidligere valgte Profil-fanen,
  skal åpne samme profilpresentasjon og riktig underside der det er relevant.

## Implementeringsrekkefølge

1. **Avklar eksisterende navigasjonskoblinger.** Finn alle brukere av
   `AppTab.profile`, profilvalg og profiltestenes hjelpefunksjoner. Kontroller
   `HomeNavigationViewModel`, app-roten og demoroten før fanen fjernes.
   Kartlegg bare koblinger som påvirkes av flyttingen.
2. **Tilpass Profil for modal presentasjon.** I `ProfileView.swift`, behold
   eksisterende stack og innhold. Legg til en synlig lukkehandling på roten.
   Fjern tabbar-klaring for denne presentasjonen; behold vanlig safe-area og
   rullbarhet på roten og undersidene. Unngå dobbel «Profil»-overskrift.
3. **Koble personikonene til én profilpresentasjon.** La HomeView/appens
   navigasjonskoordinator eie presentasjonen, og gi Hjem/Utvikling små
   `onOpenProfile`-callbacks. Gjenbruk en liten ikonknapp hvis nødvendig.
   View-lokal boolsk presentasjonsstate er tilstrekkelig hvis ingen eksisterende
   ruter krever mer. Ikke flytt featurelogikk eller IO til AppState.
4. **Endre bunnmenyen.** I `MatLoggTabBar.swift`, fjern Profil-knappen og bruk
   tre like brede kolonner. Behold Loggfør-handlingen og valgt-status for fanene.
   Ved tilgjengelighetstekst: Hjem/Utvikling i første rad og en sentrert,
   fullbredde Loggfør-handling under. Behold fulle etiketter og mål faktisk høyde
   gjennom eksisterende tabbar-klaring. Kontekstuell utvalgsmeny for matlogger
   skal fortsatt erstatte hele bunnmenyen som før.
5. **Rydd ruter og tester.** Fjern Profil fra TabView og `AppTab` når alle
   interne koblinger er flyttet. Oppdater berørte navigasjonsgrener, demo og
   UI-testhjelpere. Ikke endre persistente verdier uten å undersøke bruken først.
6. **Oppdater dokumentasjon.** Samordne `design-and-user-flow.md`,
   `design-system.md` og `current-state.md`; før valgt navigasjonsretning kort
   i `decisions.md`. Rapporter faktisk verifisering i `testing.md`.

## Målrettet verifisering og ferdigkriterier

- UI-test: Loggfør-knappens midtpunkt samsvarer med skjermens midtpunkt
  (maksimalt 1 pt avvik) ved vanlig tekststørrelse; bare tre innganger finnes.
- Hjem → Loggfør → Ferdig og Utvikling → Loggfør → Ferdig returnerer til
  opprinnelig fane med bevart kontekst. Eksisterende logging/Angre-test gjenbrukes.
- Personikonet åpner Profil fra begge faner. Profil → Innstillinger → tilbake
  → Lukk returnerer riktig. Kontroller også en eksisterende intern profilsnarvei.
- Visuell kontroll på smal iPhone og med største tilgjengelighetstekst:
  symmetri, fulle etiketter, trykkflater, toppfelt og nederste rullbare innhold.
  Kontroller at profilens siste innhold kan nås uten unødvendig tabbar-tomrom.
- Kontroller VoiceOver-navn, rekkefølge og fokus ved åpning/lukking. Oppgi
  eksplisitt hvis fysisk VoiceOver eller iOS 26-utseendet ikke er kontrollert.
- Kjør berørte navigasjons-/UI-tester, deretter én iPhone-build ved behov.
  Ingen full testpakke eller backendtester for denne presentasjonsendringen.
- Gjennomgå diff mot `architecture-principles.md`: ingen nye IO-grenser,
  domeneregler eller lagringsendringer; presentasjonsansvar holdes i UI/
  navigasjonskoordinator. Bevar urelaterte endringer på arbeidsbranchen.

Skills ved gjennomføring: product-review → product-design → ios-swiftui →
qa-release. Den særskilte tilgjengelighetslayouten er en foreslått tilpasning;
vanlig layout skal alltid ha Loggfør i midten.
