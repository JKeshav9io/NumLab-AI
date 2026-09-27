# NumLab AI Backend

NumLab AI Backend is a production-ready Node.js/Express 5 API for a numerical scientific computing and educational platform. It provides 27 deterministic numerical solvers, secure JWT authentication with refresh token rotation, non-blocking user history persistence, resilient AI-powered pedagogical explanations with response caching, and downloadable PDF lab reports with vector charts.

---

## Features

- **27 Numerical Solvers**: Pure, deterministic mathematical computation engines across 6 domains:
  - **Root-Finding**: Bisection, Newton-Raphson, Secant, Regula Falsi.
  - **Linear Algebra**: Gaussian Elimination, Jacobi, Gauss-Seidel.
  - **Interpolation**: Lagrange, Newton Divided Difference, Newton Forward/Backward, Central Difference (Stirling/Bessel/Everett), Natural Cubic Spline, Quadratic.
  - **Ordinary Differential Equations (ODE)**: Euler, Heun (Improved Euler), 4th-Order Runge-Kutta (RK4), Milne Predictor-Corrector.
  - **Numerical Integration**: Trapezoidal Rule, Simpson's 1/3 Rule, Simpson's 3/8 Rule, Gauss-Legendre Quadrature.
  - **Numerical Differentiation**: Forward Difference, Backward Difference, Central Difference, Lagrange Differentiation, Function-Based Finite Difference.
- **Authentication & Security**:
  - Dual-token JWT authentication (short-lived 15m access token, stateful 7d refresh token).
  - Single-use refresh token rotation (RTR) with token hash revocation tracking.
  - Native `bcrypt` password hashing (cost factor 12) and anti-enumeration generic login responses.
- **Solve History & Persistence**:
  - Optional authentication on all solver endpoints: anonymous solving remains 100% public while authenticated runs are persisted in PostgreSQL.
  - Non-blocking asynchronous database writes that never delay mathematical calculation responses.
  - Paginated calculation history retrieval (`/api/v1/users/me/history`) and single run lookup with user ownership enforcement.
- **AI Pedagogical Explanations**:
  - Explains already-computed numerical results step by step without hallucinating math calculations.
  - Deterministic canonical SHA-256 prompt hashing and PostgreSQL response caching with TTL.
  - In-memory circuit breaker (fast-fails in <1ms during provider outages) and exponential backoff retries for transient errors.
  - Tiered cost-budget rate limiting and prompt injection defenses.
- **PDF Lab Report Generation**:
  - On-demand binary PDF generation (`pdfkit`) with structured problem inputs, convergence summaries, iteration tables, and AI explanations.
  - 2D vector coordinate plotting for ODE trajectories, interpolation polynomials, and integration areas without heavy external browser dependencies.
- **Performance & Reliability**:
  - Gzip payload compression for responses exceeding 1 KB (~75–98% bandwidth reduction).
  - Multi-tier rate limiting (`express-rate-limit`) preventing brute force and API abuse.
  - Structured request logging with `pino` and unique request ID tracing.
  - PostgreSQL connection pool tuning for serverless transaction poolers (Neon).
  - 100% automated test coverage (170 tests across 23 test suites).

---

## Tech Stack

- **Runtime & Framework**: Node.js, Express 5
- **Database & ORM**: PostgreSQL (Neon Serverless), Prisma 7 ORM (`@prisma/client`, `@prisma/adapter-pg`, `pg`)
- **Authentication & Security**: `jsonwebtoken`, `bcrypt`, `helmet`, `cors`, `express-rate-limit`
- **Math & Computing**: `mathjs`
- **Validation**: `joi`
- **Reporting**: `pdfkit`
- **Performance & Logging**: `compression`, `pino`, `pino-pretty`
- **Testing**: `jest`, `supertest`

---

## Project Structure

```text
numlab-backend/
├── prisma/
│   ├── schema.prisma              # Data models (User, SolverRun, AiExplanation, RefreshToken)
│   └── migrations/                # Database migrations
├── src/
│   ├── server.js                  # Entry point, DB healthcheck, graceful shutdown
│   ├── app.js                     # Express app factory, middleware, route mounting
│   ├── config/                    # Environment variable validation & Pino logger
│   ├── common/                    # Shared errors, middleware (auth, rate limits), utilities
│   ├── db/
│   │   ├── index.js               # Prisma client singleton & connection pooling
│   │   └── repositories/          # User, SolverRun, AiExplanation, RefreshToken repositories
│   ├── modules/
│   │   ├── auth/                  # Authentication routes, controllers, password & token logic
│   │   ├── users/                 # User profile & paginated history routes/controllers
│   │   ├── solvers/               # 27 numerical solvers, validators, and orchestration
│   │   │   ├── rootFinding/
│   │   │   ├── linearAlgebra/
│   │   │   ├── interpolation/
│   │   │   ├── ode/
│   │   │   ├── integration/
│   │   │   └── differentiation/
│   │   ├── explanations/          # AI explanation service, prompt builder, circuit breaker
│   │   └── reports/               # PDF report generation, vector layout template, streaming
│   └── tests/                     # 23 Jest test suites (unit & integration)
├── .env.example                   # Environment variable template
└── package.json
```

---

## Getting Started

### 1. Prerequisites
- Node.js (v18 or higher recommended)
- PostgreSQL database (e.g. [Neon](https://neon.tech))

### 2. Clone & Install
```bash
git clone https://github.com/JKeshav9io/NumLab-AI.git
cd NumLab-AI
npm install
```

### 3. Configure Environment Variables
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
*(On Windows Command Prompt: `copy .env.example .env`)*

Configure the following variables in `.env`:
- `DATABASE_URL`: PostgreSQL connection string (with SSL mode, e.g. Neon pooled URL).
- `JWT_SECRET`: A secure random string (at least 32 characters) for signing access tokens.
- `AI_API_KEY`: API key for OpenAI or OpenAI-compatible LLM provider.
- `AI_MODEL`: Model identifier (e.g. `gpt-4o-mini`, `deepseek-chat`).
- `AI_BASE_URL`: API base URL (e.g. `https://api.openai.com/v1`).

### 4. Database Setup & Migrations
Generate the Prisma Client and apply migrations to your database:
```bash
npm run prisma:generate
npm run db:migrate
```

*(Optional: Run `npm run prisma:studio` to visually inspect database tables in your browser).*

### 5. Run the Application
- **Development (with hot reload)**:
  ```bash
  npm run dev
  ```
- **Production**:
  ```bash
  npm start
  ```

---

## Testing

Run the full automated test suite:
```bash
npm test
```
The test suite executes 23 test suites and 170 unit and integration tests covering math solvers, database repositories, authentication, AI circuit breakers, history retrieval, and PDF report compilation.

---

## API Overview

All API endpoints are mounted under `/api/v1` (with the exception of `/health`).

### 1. Health Check
- `GET /health` — Service health status (Public)

### 2. Authentication (`/api/v1/auth`)
- `POST /api/v1/auth/register` — Register a new student account (`email`, `password`)
- `POST /api/v1/auth/login` — Authenticate and receive JWT access & refresh tokens
- `POST /api/v1/auth/refresh` — Single-use refresh token rotation
- `POST /api/v1/auth/logout` — Revoke single refresh token session
- `POST /api/v1/auth/logout-all` — Revoke all active sessions for authenticated user (Protected)

### 3. Users & Solve History (`/api/v1/users`)
- `GET /api/v1/users/me` — Get authenticated user profile (Protected)
- `GET /api/v1/users/me/history` — Paginated history of past solver runs (`limit`, `offset`) (Protected)
- `GET /api/v1/users/me/history/:runId` — Get single solver run by UUID with ownership verification (Protected)

### 4. Numerical Solvers (`/api/v1/solve`)
All 27 solver endpoints are **public** (no login required), with **optional authentication** (attaches run to user history if Bearer token is provided).

- **Root-Finding**:
  - `POST /api/v1/solve/root/bisection`
  - `POST /api/v1/solve/root/newton`
  - `POST /api/v1/solve/root/secant`
  - `POST /api/v1/solve/root/regula-falsi`
- **Linear Algebra**:
  - `POST /api/v1/solve/linear/gauss-elimination`
  - `POST /api/v1/solve/linear/jacobi`
  - `POST /api/v1/solve/linear/gauss-seidel`
- **Interpolation**:
  - `POST /api/v1/solve/interpolation/lagrange`
  - `POST /api/v1/solve/interpolation/newton-divided-difference`
  - `POST /api/v1/solve/interpolation/newton-forward`
  - `POST /api/v1/solve/interpolation/newton-backward`
  - `POST /api/v1/solve/interpolation/central-difference`
  - `POST /api/v1/solve/interpolation/natural-cubic-spline`
  - `POST /api/v1/solve/interpolation/quadratic`
- **Ordinary Differential Equations (ODE)**:
  - `POST /api/v1/solve/ode/euler`
  - `POST /api/v1/solve/ode/heun`
  - `POST /api/v1/solve/ode/rk4`
  - `POST /api/v1/solve/ode/milne`
- **Numerical Integration**:
  - `POST /api/v1/solve/integration/trapezoidal`
  - `POST /api/v1/solve/integration/simpson-13`
  - `POST /api/v1/solve/integration/simpson-38`
  - `POST /api/v1/solve/integration/gauss-legendre`
- **Numerical Differentiation**:
  - `POST /api/v1/solve/differentiation/forward`
  - `POST /api/v1/solve/differentiation/backward`
  - `POST /api/v1/solve/differentiation/central`
  - `POST /api/v1/solve/differentiation/lagrange`
  - `POST /api/v1/solve/differentiation/function-finite-difference`

### 5. AI Pedagogical Explanations (`/api/v1/explain`)
- `POST /api/v1/explain` — Generates or returns cached step-by-step explanations for solver results (`focus`: `summary` | `steps` | `warnings` | `lab-report`).

### 6. PDF Lab Reports (`/api/v1/reports`)
- `POST /api/v1/reports/:runId` — Generates and streams a downloadable binary PDF report with vector charts (Protected).

---

## Response Envelope Standard

### Success (`200 OK` / `201 Created`):
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-09-26T20:00:00.000Z"
  }
}
```

### Error (`4xx` / `5xx`):
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": { ... }
  }
}
```

---

## License

ISC
