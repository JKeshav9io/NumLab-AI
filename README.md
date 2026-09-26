# NumLab AI Backend

NumLab AI Backend is a JavaScript Node.js/Express API for a numerical methods learning platform. It runs deterministic scientific computing solvers and returns structured results for students, including iteration data, final answers, warnings, optional graph data, and optional explanation text.

The project is focused on making numerical methods easier to inspect, visualize, and learn from step by step.

## Features

- Express REST API.
- Health check endpoint.
- Root-finding solvers:
  - Bisection
  - Newton-Raphson
  - Secant
  - Regula Falsi
- Linear algebra solvers:
  - Gauss Elimination
  - Jacobi
  - Gauss-Seidel
- Interpolation solvers:
  - Lagrange Interpolation
  - Newton Divided Difference
  - Newton Forward Interpolation
  - Newton Backward Interpolation
  - Central Difference Interpolation
  - Natural Cubic Spline
  - Quadratic Interpolation
- ODE solvers:
  - Euler Method
  - Heun / Improved Euler Method
  - RK4 Method
  - Milne Predictor-Corrector Method
- Numerical integration solvers:
  - Trapezoidal Rule
  - Simpson's 1/3 Rule
  - Simpson's 3/8 Rule
  - Gauss-Legendre Quadrature
- Numerical differentiation solvers:
  - Forward Difference
  - Backward Difference
  - Central Difference
  - Lagrange Differentiation
  - Function-based Finite Difference
- Joi request validation.
- Structured success and error responses.
- Stateless AI explanation endpoint for already-computed solver results.
- Request logging with pino.
- Rate limiting for solver and AI explanation routes.
- Safe math expression parsing with mathjs.
- Jest test suite.

## Tech Stack

- Node.js (CommonJS)
- Express 5
- PostgreSQL (Neon Serverless)
- Prisma 7 ORM (`@prisma/client`, `@prisma/adapter-pg`)
- mathjs
- Joi
- pino
- Jest
- helmet
- cors
- express-rate-limit
- dotenv

## Project Structure

```text
numlab-backend/
  src/
    app.js
    server.js
    config/
      env.js
      logger.js
    common/
      errors/
      middleware/
      utils/
      validators/
      types/
    modules/
      auth/
      explanations/
      problems/
      reports/
      solvers/
        solvers.routes.js
        solvers.controller.js
        solvers.service.js
        solvers.validator.js
        rootFinding/
        linearAlgebra/
        interpolation/
        ode/
        integration/
        differentiation/
      users/
    tests/
  .env.example
  package.json
```

Key files and folders:

- `src/app.js`: Express app factory and middleware setup.
- `src/server.js`: Starts the HTTP server.
- `src/config`: Environment validation and logger setup.
- `src/common`: Shared errors, middleware, and utilities.
- `src/modules/solvers`: Solver routes, controllers, service orchestration, and validation.
- `src/modules/solvers/rootFinding`: Root-finding solver implementations.
- `src/modules/solvers/linearAlgebra`: Linear algebra solver implementations.
- `src/modules/solvers/interpolation`: Interpolation solver implementations.
- `src/modules/solvers/ode`: ODE solver implementations.
- `src/modules/solvers/integration`: Numerical integration solver implementations.
- `src/modules/solvers/differentiation`: Numerical differentiation solver implementations.
- `src/tests`: Jest tests for configuration, API routes, and solver services.

## Database Setup (Neon & Prisma)

1. Create a PostgreSQL database on [Neon](https://neon.tech).
2. Copy your pooled connection string into `.env`:
   ```env
   DATABASE_URL="postgresql://user:password@ep-sample-123456.us-east-2.aws.neon.tech/neondb?sslmode=require"
   ```
3. Generate the Prisma Client and apply migrations:
   ```bash
   npm run prisma:generate
   npm run db:migrate
   ```
4. (Optional) Open Prisma Studio to inspect records visually:
   ```bash
   npm run prisma:studio
   ```

## Getting Started

Clone the repository:

```bash
git clone <repository-url>
cd numlab-backend
```

Install dependencies:

```bash
npm install
```

Create an environment file:

```bash
cp .env.example .env
```

On Windows:

```cmd
copy .env.example .env
```

Run the development server:

```bash
npm run dev
```

Run tests:

```bash
npm test
```

## Environment Variables

Environment variables are documented in `.env.example`. Create a local `.env` file before running the server.

Do not commit real secrets or production credentials.

AI explanation settings:

- `AI_API_KEY`: provider API key.
- `AI_MODEL`: OpenAI-compatible chat model name.
- `AI_BASE_URL`: provider base URL, for example `https://api.openai.com/v1`.
- `AI_MAX_TOKENS`: maximum provider response tokens for explanation text. Defaults to `700`.
- `AI_TIMEOUT_MS`: AI provider request timeout in milliseconds. Defaults to `15000`.

## API Endpoints

```text
GET  /health

POST /api/v1/solve/root/bisection
POST /api/v1/solve/root/newton
POST /api/v1/solve/root/secant
POST /api/v1/solve/root/regula-falsi

POST /api/v1/solve/linear/gauss-elimination
POST /api/v1/solve/linear/jacobi
POST /api/v1/solve/linear/gauss-seidel

POST /api/v1/solve/interpolation/lagrange
POST /api/v1/solve/interpolation/newton-divided-difference
POST /api/v1/solve/interpolation/newton-forward
POST /api/v1/solve/interpolation/newton-backward
POST /api/v1/solve/interpolation/central-difference
POST /api/v1/solve/interpolation/natural-cubic-spline
POST /api/v1/solve/interpolation/quadratic

POST /api/v1/solve/ode/euler
POST /api/v1/solve/ode/heun
POST /api/v1/solve/ode/rk4
POST /api/v1/solve/ode/milne

POST /api/v1/solve/integration/trapezoidal
POST /api/v1/solve/integration/simpson-13
POST /api/v1/solve/integration/simpson-38
POST /api/v1/solve/integration/gauss-legendre

POST /api/v1/solve/differentiation/forward
POST /api/v1/solve/differentiation/backward
POST /api/v1/solve/differentiation/central
POST /api/v1/solve/differentiation/lagrange
POST /api/v1/solve/differentiation/function-finite-difference

POST /api/v1/explain
```

## Example Requests

### Bisection

```json
{
  "equation": "x^3 - x - 2",
  "lowerBound": 1,
  "upperBound": 2,
  "tolerance": 0.0001,
  "maxIterations": 100,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Newton-Raphson

```json
{
  "equation": "x^3 - x - 2",
  "derivativeEquation": "3*x^2 - 1",
  "initialGuess": 1.5,
  "tolerance": 0.0001,
  "maxIterations": 100,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Gauss-Seidel

```json
{
  "matrix": [
    [10, -1, 2],
    [-1, 11, -1],
    [2, -1, 10]
  ],
  "constants": [6, 25, -11],
  "initialGuess": [0, 0, 0],
  "tolerance": 0.0001,
  "maxIterations": 100,
  "includeExplanation": true
}
```

### Lagrange Interpolation

```json
{
  "points": [
    { "x": 0, "y": 1 },
    { "x": 1, "y": 3 },
    { "x": 2, "y": 2 }
  ],
  "targetX": 1.5,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Newton Forward Interpolation

```json
{
  "points": [
    { "x": 0, "y": 1 },
    { "x": 1, "y": 2 },
    { "x": 2, "y": 5 },
    { "x": 3, "y": 10 }
  ],
  "targetX": 0.5,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Newton Backward Interpolation

```json
{
  "points": [
    { "x": 0, "y": 1 },
    { "x": 1, "y": 2 },
    { "x": 2, "y": 5 },
    { "x": 3, "y": 10 }
  ],
  "targetX": 2.5,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Central Difference Interpolation

```json
{
  "points": [
    { "x": 0, "y": 1 },
    { "x": 1, "y": 2 },
    { "x": 2, "y": 5 },
    { "x": 3, "y": 10 },
    { "x": 4, "y": 17 }
  ],
  "targetX": 2.25,
  "variant": "gauss-forward",
  "includeExplanation": true,
  "includeGraphData": true
}
```

### ODE Solvers

```json
{
  "equation": "x + y",
  "x0": 0,
  "y0": 1,
  "h": 0.1,
  "xn": 1,
  "includeExplanation": true,
  "includeGraphData": true
}
```

You can use `steps` instead of `xn`:

```json
{
  "equation": "x + y",
  "x0": 0,
  "y0": 1,
  "h": 0.1,
  "steps": 10,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Numerical Differentiation

Tabular finite-difference and Lagrange differentiation endpoints use points:

```json
{
  "points": [
    { "x": 0, "y": 1 },
    { "x": 1, "y": 4 },
    { "x": 2, "y": 9 }
  ],
  "targetX": 1,
  "exactDerivative": 4,
  "includeExplanation": true,
  "includeGraphData": true
}
```

Function-based finite difference uses an equation and spacing:

```json
{
  "equation": "x^2 + 2*x + 1",
  "targetX": 1,
  "h": 0.001,
  "variant": "central",
  "exactDerivative": 4,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### Numerical Integration

Composite Trapezoidal, Simpson's 1/3, and Simpson's 3/8 rules use `subintervals`:

```json
{
  "equation": "x^2",
  "lowerBound": 0,
  "upperBound": 1,
  "subintervals": 6,
  "exactValue": 0.3333333333,
  "includeExplanation": true,
  "includeGraphData": true
}
```

Gauss-Legendre Quadrature uses `points` from `2` through `5`:

```json
{
  "equation": "x^2",
  "lowerBound": 0,
  "upperBound": 1,
  "points": 3,
  "exactValue": 0.3333333333,
  "includeExplanation": true,
  "includeGraphData": true
}
```

### AI Explanation

The endpoint is stateless and explains only an already-computed solver result. It is protected by the `explainLimiter`, uses `AI_MAX_TOKENS` for the provider response cap, and times out provider calls after `AI_TIMEOUT_MS`.

```json
{
  "solverResult": {
    "method": "Bisection Method",
    "status": "converged",
    "input": {},
    "iterations": [],
    "finalAnswer": {
      "root": 2,
      "converged": true
    },
    "warnings": [],
    "executionTimeMs": 2
  },
  "focus": "steps",
  "includeGraphSummary": true
}
```

## Response Format

Success responses use this envelope:

```json
{
  "success": true,
  "data": {
    "method": "Bisection Method",
    "status": "converged",
    "input": {},
    "iterations": [],
    "finalAnswer": {},
    "explanation": null,
    "graphData": [],
    "warnings": [],
    "executionTimeMs": 2
  },
  "meta": {
    "requestId": "request-id",
    "timestamp": "2026-05-26T00:00:00.000Z"
  }
}
```

Error responses use this envelope:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {}
  }
}
```

## Current Status

- Implemented solver APIs for root finding, linear algebra, interpolation, ODE initial value problems, numerical integration, and numerical differentiation.
- Implemented stateless AI explanations for already-computed solver results.
- Other modules are planned but not implemented yet.

## Planned Improvements

- PDF reports.
- Saved history.
- Authentication.

## Safety And Numerical Integrity

- Solvers are deterministic and run in backend code.
- mathjs is used for expression parsing.
- `eval()` and `new Function()` should not be used for math evaluation.
- AI explanations only explain computed results and must not calculate numerical answers.
