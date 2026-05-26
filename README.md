# NumLab AI

Interactive Scientific Computing & Numerical Methods Visual Lab

NumLab AI solves numerical methods problems using deterministic custom algorithms, then uses AI only to explain the verified results.

> Algorithm solves. AI explains. Graphs visualize. Reports document.

## Why This Project

Students studying numerical methods often need more than a final answer. They need iteration tables, formulas, substitutions, convergence behavior, graphs, and lab-report-ready explanations.

Most online calculators focus on the final result. Large language models can explain concepts, but they should not be trusted as the calculator for numerical work because they may skip steps or make arithmetic mistakes.

NumLab AI is designed as a practical scientific computing lab: accurate like a calculator, visual like a graphing tool, explanatory like a tutor, and structured like a lab-report generator.

## Planned Features

- Root finding methods: Bisection, Newton-Raphson, Secant, and Regula Falsi.
- Linear system solvers: Gauss Elimination, Jacobi, and Gauss-Seidel.
- Interpolation, ODE solvers, and numerical integration modules.
- Iteration tables with expandable formula, substitution, calculation, and decision steps.
- Graph data for function curves, convergence charts, interpolation curves, ODE curves, and method comparisons.
- AI explanations based only on verified solver output.
- PDF reports for lab records and assignment documentation.
- Saved history for rerunning, duplicating, and exporting previous problems.

## Current Status

This repository currently contains an early production-oriented Node.js backend scaffold with the first solver endpoint implemented.

Implemented so far:

- Express app factory and server bootstrap.
- CommonJS-based Node.js source files.
- Environment validation and structured pino logging.
- Standard error handling and success response envelopes.
- Health check endpoint.
- Bisection Method solver with validation, iteration data, explanation text, graph-ready points, and tests.
- Placeholder modules for solvers, explanations, reports, auth, users, and problems.

Still planned:

- Remaining solver algorithm implementations.
- Additional Express API routes.
- Request validation and structured error handling.
- Database integration.
- AI provider integration.
- PDF report generation.
- Broader unit and integration tests.
- Flutter frontend application.

## Tech Stack

Current backend:

- Node.js
- Express
- CommonJS modules
- Joi validation
- mathjs expression parsing
- Jest tests

Planned stack:

- Flutter mobile frontend
- Node.js backend APIs
- PostgreSQL database
- Explanation-only AI service
- PDF report generation

## Project Structure

```text
numlab-backend/
  src/
    app.js
    server.js
    modules/
      solvers/
      explanations/
      reports/
    common/
    config/
    tests/
  package.json
```

## Planned API Interfaces

Implemented:

```text
GET  /health
POST /api/v1/solve/root/bisection
```

Planned:

```text
POST /api/v1/solve/root/newton
POST /api/v1/compare/root
POST /api/v1/explain/:runId
POST /api/v1/reports/:runId
```

### Bisection Request

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

### Bisection Response Shape

```json
{
  "success": true,
  "data": {
    "method": "Bisection Method",
    "status": "converged",
    "input": {
      "equation": "x^3 - x - 2",
      "lowerBound": 1,
      "upperBound": 2,
      "tolerance": 0.0001,
      "maxIterations": 100
    },
    "iterations": [
      {
        "iteration": 1,
        "a": 1,
        "b": 2,
        "c": 1.5,
        "fA": -2,
        "fB": 4,
        "fC": -0.125,
        "formulaTemplate": "c = (a + b) / 2",
        "substitution": "c = (1 + 2) / 2 = 1.5",
        "error": 0.5,
        "tolerance": 0.0001,
        "decision": "Root lies in [c, b], continue"
      }
    ],
    "finalAnswer": {
      "root": 1.5214233398,
      "functionValue": 0.000246585,
      "iterationsUsed": 14,
      "converged": true,
      "reason": "Tolerance reached"
    },
    "explanation": {
      "summary": "The bisection method converged because the interval was repeatedly halved until tolerance reached.",
      "steps": []
    },
    "graphData": [{ "x": 1, "y": -2 }],
    "warnings": [],
    "executionTimeMs": 2
  },
  "meta": {
    "requestId": "request-id",
    "timestamp": "2026-05-26T00:00:00.000Z"
  }
}
```

## How to Run

From the backend project directory:

```bash
cp .env.example .env
npm install
npm start
```

Or from the parent project directory:

```bash
cd numlab-backend
cp .env.example .env
npm install
npm start
```

The backend validates required environment variables at startup. For local development, create `.env` from `.env.example` and update values as needed.

Run tests:

```bash
npm test
```

Run in development mode:

```bash
npm run dev
```

## Roadmap

1. Implement remaining root-finding solvers and unit tests.
2. Add database-backed history and stored runs.
3. Add graph data generation and method comparison.
4. Add the AI explanation service using verified solver results only.
5. Add PDF reports and saved history.
6. Build the Flutter frontend.

## Product Rule

AI must not calculate roots, matrix solutions, interpolation values, ODE tables, or integration values. The deterministic solver engine owns the computation. AI only explains the computed payload, convergence behavior, warnings, and lab-report wording.

## Intended Audience

NumLab AI is aimed at engineering, mathematics, physics, computer science, and data science students studying Numerical Methods or Scientific Computing.
