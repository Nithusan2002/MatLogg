---
name: ios-swiftui
description: Implementer og vurder MatLoggs SwiftUI-skjermer, navigasjon, state, design system, tilgjengelighet og iOS-tester.
---

# iOS og SwiftUI

Les berørte filer under `MatLogg/`, relevante UX-spesifikasjoner og eksisterende tester før endring.

- Plasser feature-UI under riktig mappe i `MatLogg/Views/`; delte visuelle primitives hører hjemme i `DesignSystem/Components/`.
- Bruk semantiske tokens fra `DesignSystem/Colors.swift` og `Typography.swift`. Kontroller Dynamic Type, kontrast, VoiceOver-labels, touchflater og reduced-motion der det er relevant.
- Hold views deklarative. Flytt gjenbrukbar domenelogikk til avgrensede services; la `AppState` koordinere på tvers av features.
- Bruk Swift Concurrency for IO og respekter main-actor-grenser. Ikke blokker UI-tråden.
- Bevar local-first-adferd og tydelige loading-, tom-, offline- og feiltilstander.

Verifiser med relevante Swift Testing-tester og `xcodebuild` for riktig scheme/destinasjon når omfanget tilsier det. UI-tester prioriteres for kritiske ende-til-ende-flyter.
