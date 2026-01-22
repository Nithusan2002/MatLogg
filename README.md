# MatLogg - Norwegian Calorie Tracker

A production-ready iOS calorie tracking app built with SwiftUI and offline-first architecture.

## Features

### MVP (Current)
- ✅ User authentication (email/password signup & login)
- ✅ Barcode scanning with AVFoundation
- ✅ Product logging with custom amounts (100g prefill)
- ✅ Daily calorie & macro tracking
- ✅ Meal type selection (breakfast, lunch, dinner, snack)
- ✅ Haptic & audio feedback
- ✅ Favorites management
- ✅ Settings (haptics/sound toggle, logout)

### Coming Soon
- SQLite persistent storage
- Offline sync queue
- Product sharing via links
- Product not found flow
- Scan history panel
- Backend integration

## Architecture

**Stack:**
- SwiftUI for UI
- Combine for reactive state
- AVFoundation for barcode scanning
- Keychain for secure auth storage
- (SQLite coming soon)

**State Management:**
- Centralized `AppState` observable
- Service layer: Auth, API, Database, Barcode, Haptics, Sound

## Project Structure

```
MatLogg/
├── App/
│   ├── AppState.swift (reactive state container)
│   └── Models.swift (domain models)
├── Services/
│   ├── AuthService.swift
│   ├── APIService.swift
│   ├── DatabaseService.swift
│   ├── BarcodeScanner.swift
│   ├── HapticFeedbackService.swift
│   └── SoundFeedbackService.swift
├── Views/
│   ├── Auth/ (LoginView, SignUpView, OnboardingView)
│   └── Home/ (HomeView, ProductDetailView, ReceiptView)
└── MatLoggApp.swift (root)
```

## Getting Started

### Requirements
- iOS 17+
- Xcode 15+
- Swift 5.9+

### Build & Run
1. Open `MatLogg.xcodeproj` in Xcode
2. Select target device/simulator
3. Press ▶️ (Run)

## Documentation

- [MVP Scope & KPIs](SPEC_1_MVP_SCOPE.md)
- [User Stories & Flows](SPEC_2_USER_STORIES_FLOWS.md)
- [Wireframes & Screens](SPEC_3_WIREFRAMES_SCREENS.md)
- [Microinteractions](SPEC_4_MICROINTERACTIONS.md)
- [Data Model & Sync](SPEC_5_DATA_MODEL_SYNC.md)
- [API Endpoints](SPEC_6_API_ENDPOINTS.md)
- [Edge Cases](SPEC_7_EDGE_CASES.md)
- [Roadmap](SPEC_8_ROADMAP.md)
- [Risks & Mitigations](SPEC_9_RISKS_MITIGATION.md)

## Design system usage

Use semantic tokens from `MatLogg/DesignSystem/Colors.swift` and `MatLogg/DesignSystem/Typography.swift` instead of hardcoded colors.

Reusable components live under `MatLogg/DesignSystem/Components/`:
- `CardContainer`
- `PrimaryButton`
- `MealChip`
- `ProgressRow`

Debug-only theme preview is available in Settings → Debug → Theme Preview.

## Development Status

**Current:** MVP barcode scanning flow
- Auth → Onboarding → Home (TabView)
- Scan barcode → ProductDetailView (100g prefill) → Log → Receipt
- All views + services implemented

**Next:** SQLite + Backend integration

## License

Private

---

**Built with ❤️ for Norwegian users** 🇳🇴
