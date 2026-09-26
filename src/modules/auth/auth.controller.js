'use strict';

const authService = require('./auth.service');
const {
  validateRegisterRequest,
  validateLoginRequest,
  validateRefreshRequest,
} = require('./auth.validator');
const { sendSuccess } = require('../../common/utils');

/**
 * Handles user registration.
 * POST /api/v1/auth/register
 */
async function register(req, res) {
  const validated = validateRegisterRequest(req.body);
  const result = await authService.register(validated.email, validated.password);

  return sendSuccess(res, result, req.id, 201);
}

/**
 * Handles user login.
 * POST /api/v1/auth/login
 */
async function login(req, res) {
  const validated = validateLoginRequest(req.body);
  const result = await authService.login(validated.email, validated.password);

  return sendSuccess(res, result, req.id, 200);
}

/**
 * Handles token refresh with rotation.
 * POST /api/v1/auth/refresh
 */
async function refresh(req, res) {
  const validated = validateRefreshRequest(req.body);
  const result = await authService.refresh(validated.refreshToken);

  return sendSuccess(res, result, req.id, 200);
}

/**
 * Handles session logout.
 * POST /api/v1/auth/logout
 */
async function logout(req, res) {
  const validated = validateRefreshRequest(req.body);
  const result = await authService.logout(validated.refreshToken);

  return sendSuccess(res, result, req.id, 200);
}

/**
 * Handles logout across all active devices for the authenticated user.
 * POST /api/v1/auth/logout-all
 */
async function logoutAll(req, res) {
  const result = await authService.logoutAllDevices(req.user.id);

  return sendSuccess(res, result, req.id, 200);
}

module.exports = {
  register,
  login,
  refresh,
  logout,
  logoutAll,
};
