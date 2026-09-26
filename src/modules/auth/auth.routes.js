'use strict';

const express = require('express');
const authController = require('./auth.controller');
const authenticate = require('../../common/middleware/authenticate');
const { authLimiter } = require('../../common/middleware/rateLimiter');
const { asyncHandler } = require('../../common/utils');

const router = express.Router();

router.post('/register', authLimiter, asyncHandler(authController.register));
router.post('/login', authLimiter, asyncHandler(authController.login));
router.post('/refresh', asyncHandler(authController.refresh));
router.post('/logout', asyncHandler(authController.logout));
router.post('/logout-all', authenticate, asyncHandler(authController.logoutAll));

module.exports = router;
