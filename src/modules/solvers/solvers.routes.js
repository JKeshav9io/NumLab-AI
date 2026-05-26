'use strict';

const express = require('express');
const solversController = require('./solvers.controller');
const { asyncHandler } = require('../../common/utils');

const router = express.Router();

router.post('/root/bisection', asyncHandler(solversController.solveBisection));
router.post('/root/newton', asyncHandler(solversController.solveNewtonRaphson));
router.post('/root/secant', asyncHandler(solversController.solveSecant));
router.post('/root/regula-falsi', asyncHandler(solversController.solveRegulaFalsi));

module.exports = router;
