'use strict';

const express = require('express');
const solversController = require('./solvers.controller');
const { asyncHandler } = require('../../common/utils');

const router = express.Router();

router.post('/root/bisection', asyncHandler(solversController.solveBisection));

module.exports = router;
