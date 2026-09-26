'use strict';

const express = require('express');
const solversController = require('./solvers.controller');
const optionalAuthenticate = require('../../common/middleware/optionalAuthenticate');
const { asyncHandler } = require('../../common/utils');

const router = express.Router();

router.use(optionalAuthenticate);

router.post('/root/bisection', asyncHandler(solversController.solveBisection));
router.post('/root/newton', asyncHandler(solversController.solveNewtonRaphson));
router.post('/root/secant', asyncHandler(solversController.solveSecant));
router.post('/root/regula-falsi', asyncHandler(solversController.solveRegulaFalsi));
router.post('/linear/gauss-elimination', asyncHandler(solversController.solveGaussElimination));
router.post('/linear/jacobi', asyncHandler(solversController.solveJacobi));
router.post('/linear/gauss-seidel', asyncHandler(solversController.solveGaussSeidel));
router.post('/interpolation/lagrange', asyncHandler(solversController.solveLagrangeInterpolation));
router.post('/interpolation/newton-divided-difference', asyncHandler(solversController.solveNewtonDividedDifference));
router.post('/interpolation/newton-forward', asyncHandler(solversController.solveNewtonForwardInterpolation));
router.post('/interpolation/newton-backward', asyncHandler(solversController.solveNewtonBackwardInterpolation));
router.post('/interpolation/central-difference', asyncHandler(solversController.solveCentralDifferenceInterpolation));
router.post('/interpolation/natural-cubic-spline', asyncHandler(solversController.solveNaturalCubicSpline));
router.post('/interpolation/quadratic', asyncHandler(solversController.solveQuadraticInterpolation));
router.post('/ode/euler', asyncHandler(solversController.solveEulerODE));
router.post('/ode/heun', asyncHandler(solversController.solveHeunODE));
router.post('/ode/rk4', asyncHandler(solversController.solveRK4ODE));
router.post('/ode/milne', asyncHandler(solversController.solveMilneODE));
router.post('/integration/trapezoidal', asyncHandler(solversController.solveTrapezoidalIntegration));
router.post('/integration/simpson-13', asyncHandler(solversController.solveSimpsonOneThirdIntegration));
router.post('/integration/simpson-38', asyncHandler(solversController.solveSimpsonThreeEighthIntegration));
router.post('/integration/gauss-legendre', asyncHandler(solversController.solveGaussLegendreIntegration));
router.post('/differentiation/forward', asyncHandler(solversController.solveForwardDifference));
router.post('/differentiation/backward', asyncHandler(solversController.solveBackwardDifference));
router.post('/differentiation/central', asyncHandler(solversController.solveCentralDifference));
router.post('/differentiation/lagrange', asyncHandler(solversController.solveLagrangeDifferentiation));
router.post('/differentiation/function-finite-difference', asyncHandler(solversController.solveFunctionFiniteDifference));

module.exports = router;
