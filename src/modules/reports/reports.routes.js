'use strict';

const { Router } = require('express');
const authenticate = require('../../common/middleware/authenticate');
const reportsController = require('./reports.controller');

const router = Router();

// All report generation endpoints require authenticated user login
router.use(authenticate);

router.post('/:runId', reportsController.generateReport);

module.exports = router;
