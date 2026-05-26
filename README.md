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

This repository currently contains an early Node.js backend scaffold.

Implemented so far:

- Basic backend project structure.
- CommonJS-based Node.js entry files.
- Placeholder modules for solvers, explanations, reports, auth, users, and problems.
- Placeholder root-finding and linear algebra service files.

Still planned:

- Solver algorithm implementations.
- Express API routes.
- Request validation and structured error handling.
- Database integration.
- AI provider integration.
- PDF report generation.
- Unit and integration tests.
- Flutter frontend application.

## Tech Stack

Current backend:

- Node.js
- Express
- CommonJS modules

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

These endpoints describe the intended API design. They are not implemented yet.

```text
POST /api/v1/solve/root/newton
POST /api/v1/solve/root/bisection
POST /api/v1/compare/root
POST /api/v1/explain/:runId
POST /api/v1/reports/:runId
```

### Example Future Request

```json
{
  "function": "x^3 - x - 2",
  "initialGuess": 1.5,
  "tolerance": 0.0001,
  "maxIterations": 20
}
```

### Example Future Response

```json
{
  "status": "converged",
  "finalAnswer": {
    "root": 1.52138,
    "finalError": 0.000001
  },
  "iterations": [],
  "warnings": [],
  "executionTimeMs": 8
}
```

## How to Run

From the backend project directory:

```bash
npm install
node src/server.js
```

Or from the parent project directory:

```bash
cd numlab-backend
npm install
node src/server.js
```

The current server starts a placeholder response on port `3000` unless `PORT` is set in the environment.

Testing is not ready yet. The current `npm test` script is still a placeholder.

## Roadmap

1. Implement root-finding solvers and unit tests.
2. Add REST endpoints and request validation.
3. Add graph data generation and method comparison.
4. Add the AI explanation service using verified solver results only.
5. Add PDF reports and saved history.
6. Build the Flutter frontend.

## Product Rule

AI must not calculate roots, matrix solutions, interpolation values, ODE tables, or integration values. The deterministic solver engine owns the computation. AI only explains the computed payload, convergence behavior, warnings, and lab-report wording.

## Intended Audience

NumLab AI is aimed at engineering, mathematics, physics, computer science, and data science students studying Numerical Methods or Scientific Computing.
