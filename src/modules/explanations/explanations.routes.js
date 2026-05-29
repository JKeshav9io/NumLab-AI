'use strict';

const express = require('express');
const { asyncHandler } = require('../../common/utils');
const explanationsController = require('./explanations.controller');

const router = express.Router();

router.post('/', asyncHandler(explanationsController.explain));

module.exports = router;
