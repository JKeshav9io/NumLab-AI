# NumLab AI

NumLab AI is a numerical scientific computing and educational mathematics platform. It combines 27 deterministic numerical algorithm solvers—spanning root-finding, linear systems, interpolation, ordinary differential equations, numerical differentiation, and numerical integration—with an LLM-assisted pedagogical explanation pipeline and PDF lab report generation. A cross-platform Flutter application interfaces with a Node.js and Express backend to provide interactive inputs, calculation history, and session management.

---

## Repository Structure

This repository is organized as a monorepo containing two primary workspace packages:

```text
NumLab AI/
├── numlab-backend/     # Node.js / Express REST API, Prisma 7 ORM, solvers, and reporting engine
└── numlab-frontend/    # Flutter mobile, web, and desktop client application
```

- **[`numlab-backend/`](numlab-backend/)**: Implements 27 numerical solvers, dual-token JWT authentication with single-use refresh token rotation, PostgreSQL persistence via Prisma 7, in-memory AI circuit breakers, and binary PDF report generation.
- **[`numlab-frontend/`](numlab-frontend/)**: Cross-platform client built using Clean Architecture and pure BLoC state management (`Bloc<Event, State>`) for solver configurations, interactive forms, authentication flows, and calculation history.

---

## Tech Stack

### Backend
- **Runtime & Framework**: Node.js, Express 5
- **Database & ORM**: PostgreSQL, Prisma 7 (`@prisma/client`, `pg`)
- **Mathematical Computation**: `mathjs`
- **Authentication & Security**: `jsonwebtoken`, `bcrypt`, `helmet`, `cors`, `express-rate-limit`
- **Data Validation**: `joi`
- **PDF Generation**: `pdfkit`
- **Logging & Utilities**: `pino`, `pino-pretty`, `uuid`, `dotenv`
- **Testing**: `jest`, `supertest`

### Frontend
- **Framework & Language**: Flutter SDK `^3.35.3`, Dart SDK `^3.9.2`
- **State Management**: `flutter_bloc` (Strictly pure event-driven BLoC)
- **Networking**: `dio` (with `QueuedInterceptor` for silent JWT rotation)
- **Routing**: `go_router` (with reactive authentication guards)
- **Persistence**: `flutter_secure_storage`
- **Dependency Injection**: `get_it`
- **Functional Architecture**: `fpdart`, `equatable`
- **Linting & Code Quality**: `very_good_analysis`, `flutter_lints`
- **Testing**: `flutter_test`, `bloc_test`

---

## Getting Started

### Prerequisites
- **Node.js**: v18 or higher
- **PostgreSQL**: PostgreSQL database instance (e.g. Neon)
- **Flutter SDK**: Flutter 3.35+ / Dart 3.9+

---

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd numlab-backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment variables (see [Environment Variables](#environment-variables)):
   ```bash
   cp .env.example .env
   ```

4. Run database migrations:
   ```bash
   npm run db:migrate
   ```

5. Start the server:
   - **Development mode (with auto-reload)**:
     ```bash
     npm run dev
     ```
   - **Production mode**:
     ```bash
     npm start
     ```

6. Run backend tests:
   ```bash
   npm test
   ```

---

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd numlab-frontend
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run static analysis:
   ```bash
   flutter analyze
   ```

4. Run automated tests:
   ```bash
   flutter test
   ```

5. Launch the application:
   - **Default Target**:
     ```bash
     flutter run
     ```
   - **Custom Backend Base URL**:
     ```bash
     flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
     ```

---

## Environment Variables

### Backend Configuration
Backend configuration variables are managed in `numlab-backend/.env`. Refer to [`numlab-backend/.env.example`](numlab-backend/.env.example) for required configuration keys:

- `PORT`: HTTP server port (default `3000`).
- `DATABASE_URL`: PostgreSQL connection string with SSL mode.
- `JWT_SECRET`: Secret key for signing access tokens.
- `JWT_EXPIRES_IN`: Access token duration.
- `AI_API_KEY`, `AI_MODEL`, `AI_BASE_URL`: OpenAI-compatible API parameters for pedagogical explanations.
- `STORAGE_BUCKET`, `STORAGE_REGION`: Storage bucket settings for generated PDF reports.

*(Never commit active `.env` files to source control).*

### Frontend Configuration
The frontend targets `http://10.0.2.2:3000/api/v1` on Android emulators and `http://localhost:3000/api/v1` on iOS simulators and desktop by default. Custom endpoints can be passed at compile/run time via `--dart-define=API_BASE_URL=<url>`.

---

## Branching & Development Workflow

All contributions follow a structured feature branch workflow. Development occurs on dedicated branches (e.g. `feature/<name>`, `chore/<name>`, `fix/<name>`) created off `main` and merged into `main` using `--no-ff` merge commits to preserve a clean, traceable history graph.
