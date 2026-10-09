---
name: ios-swiftui
description: Bruk ved endringer eller review av MatLoggs SwiftUI, navigasjon, UI-state, tilgjengelighet og iOS-tester.
---

# iOS og SwiftUI

Les berørte filer under `MatLogg/`, relevante UX-spesifikasjoner og eksisterende tester før endring.

- Plasser feature-UI under riktig mappe i `MatLogg/Views/`; delte visuelle primitives hører hjemme i `DesignSystem/Components/`.
- Bruk semantiske tokens fra `DesignSystem/Colors.swift` og `Typography.swift`. Kontroller Dynamic Type, kontrast, VoiceOver-labels, touchflater og reduced-motion der det er relevant.
- Følg `docs/architecture-principles.md`: Views viser state og videresender brukerhandlinger til feature-ViewModels. ViewModels bruker repositories ved datatilgang; services håndterer avgrenset infrastruktur. `AppState` koordinerer appomfattende state.
- Bruk Swift Concurrency for IO og respekter main-actor-grenser. Ikke blokker UI-tråden.
- Bevar local-first-adferd og tydelige loading-, tom-, offline- og feiltilstander.

Verifiser med relevante Swift Testing-tester og `xcodebuild` for riktig scheme/destinasjon når omfanget tilsier det. UI-tester prioriteres for kritiske ende-til-ende-flyter.

Velg installert QA-simulator med `xcrun simctl list devices available`. Målrettet test fra repo-roten (erstatt plassholderne med simulator og berørt suite):

```bash
xcodebuild test -project MatLogg.xcodeproj -scheme MatLogg \
  -destination 'platform=iOS Simulator,name=<QA-simulator>' \
  '-only-testing:MatLoggTests/<TestSuite>' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Se `docs/testing.md` for UI-testenes miljøkrav og flere testvalg. Ved synlige UI-endringer, inspiser berørt skjerm i simulator når mulig, inkludert relevante tekststørrelser og bunnmeny-klaring. Rapporter hvis visuell kontroll ikke kunne utføres.
