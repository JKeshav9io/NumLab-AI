'use strict';

const { Router } = require('express');
const reportsController = require('./reports.controller');

const router = Router();

router.post('/:runId', reportsController.generateReport);

module.exports = router;
