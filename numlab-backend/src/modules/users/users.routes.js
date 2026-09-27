'use strict';

const express = require('express');
const usersController = require('./users.controller');
const authenticate = require('../../common/middleware/authenticate');
const { asyncHandler } = require('../../common/utils');

const router = express.Router();

// All user profile and history routes require authentication
router.get('/me', authenticate, asyncHandler(usersController.getMe));
router.get('/me/history', authenticate, asyncHandler(usersController.getHistory));
router.get('/me/history/:runId', authenticate, asyncHandler(usersController.getRunById));

module.exports = router;
