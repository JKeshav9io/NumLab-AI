'use strict';

const express = require('express');
const solversController = require('./solvers.controller');
const { asyncHandler } = require('../../common/utils');

const router = express.Router();

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

module.exports = router;
