# NumLab AI — Flutter Mobile & Web Application

NumLab AI is a high-performance numerical computing, interactive graphing, and AI pedagogical companion built with Flutter and Dart.

---

## 🏛 Architecture Overview

The frontend follows strict **Clean Architecture** powered exclusively by **Pure BLoC (Business Logic Component)** — strictly event-driven (`Bloc<Event, State>`), with no Cubits, Riverpod, or third-party state managers:

```text
lib/
├── app.dart                    # MaterialApp & theme configuration
├── main.dart                   # DI bootstrap & entry point
├── injection_container.dart    # GetIt service locator setup
├── core/
│   ├── constants/              # API endpoints & environment constants
│   ├── error/                  # Domain Failures & Exception mappers
│   ├── network/                # Dio client & interceptors (logging, auth queue)
│   ├── router/                 # Declarative GoRouter routing
│   ├── storage/                # FlutterSecureStorage persistence wrapper
│   └── theme/                  # Design tokens (colors, typography, spacing, themes)
├── features/
│   ├── auth/                   # Authentication (Login, Register, Token Refresh)
│   ├── solvers/                # 27 Numerical Solvers & Interactive Charts
│   ├── explanations/           # AI Pedagogical Explanations
│   ├── history/                # Run history & saved computations
│   ├── reports/                # PDF Report generation & viewing
│   └── profile/                # User profile & preferences
└── shared/
    └── widgets/                # Reusable UI widgets & components
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.35.3` / Dart SDK `^3.9.2`
- Android Studio / Xcode / VS Code

### Run the App
```bash
# Get dependencies
flutter pub get

# Run analysis
flutter analyze

# Run unit & widget tests
flutter test

# Run on desktop / web / mobile
flutter run
```

### Backend Connectivity & Ports
- The **backend Express server** runs on port `3000` (`http://localhost:3000`).
- The **Flutter frontend** does not occupy port `3000`:
  - **Mobile (Android / iOS) & Desktop**: Runs as a compiled native application (no local listening port needed). It connects outbound to the backend.
    - Android Physical Device (Pixel 8 Pro over Wi-Fi / Wireless Debugging): `http://192.168.1.36:3000/api/v1`
    - Android Emulator target: `http://10.0.2.2:3000/api/v1` (resolved automatically)
    - iOS Simulator / Windows Desktop: `http://localhost:3000/api/v1` (resolved automatically)
  - **Flutter Web**: Runs on its own separate web server port (e.g. `flutter run -d chrome --web-port=8080`) and makes API calls to the backend on `http://localhost:3000/api/v1`.
- To override the backend endpoint or target the physical device at runtime, use `--dart-define` or `--dart-define-from-file`:
  ```bash
  # Target wireless physical device:
  flutter run --dart-define=API_BASE_URL=http://192.168.1.36:3000/api/v1
  # Or using .env configuration:
  flutter run --dart-define-from-file=.env
  # Target emulator:
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
  ```
