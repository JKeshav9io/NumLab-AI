'use strict';

const express = require('express');
const { asyncHandler } = require('../../common/utils');
const optionalAuthenticate = require('../../common/middleware/optionalAuthenticate');
const explanationsController = require('./explanations.controller');

const router = express.Router();

router.use(optionalAuthenticate);

router.post('/', asyncHandler(explanationsController.explain));

module.exports = router;
