'use strict';

const userRepository = require('../../db/repositories/userRepository');
const solverRunRepository = require('../../db/repositories/solverRunRepository');
const { sanitizeUser } = require('../auth/auth.service');
const { validateHistoryQuery, validateRunIdParam } = require('./users.validator');
const { sendSuccess } = require('../../common/utils');
const { AppError, errorCodes } = require('../../common/errors');

/**
 * Returns the currently authenticated user profile.
 * GET /api/v1/users/me
 */
async function getMe(req, res) {
  const user = await userRepository.findById(req.user.id);
  if (!user) {
    throw new AppError('User not found', 404, errorCodes.NOT_FOUND);
  }

  return sendSuccess(res, sanitizeUser(user), req.id, 200);
}

/**
 * Returns paginated solver runs history for the authenticated user.
 * GET /api/v1/users/me/history?limit=20&offset=0
 */
async function getHistory(req, res) {
  const { limit, offset } = validateHistoryQuery(req.query);
  const { runs, total } = await solverRunRepository.findByUserId(req.user.id, { limit, offset });

  return sendSuccess(
    res,
    {
      runs,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + runs.length < total,
      },
    },
    req.id,
    200
  );
}

/**
 * Returns a specific solver run by UUID, verifying ownership.
 * GET /api/v1/users/me/history/:runId
 */
async function getRunById(req, res) {
  const { runId } = validateRunIdParam(req.params);
  const run = await solverRunRepository.findById(runId);

  // Return 404 if not found or if the run belongs to a different user (prevents enumeration)
  if (!run || run.userId !== req.user.id) {
    throw new AppError('Solver run not found', 404, errorCodes.NOT_FOUND);
  }

  return sendSuccess(res, { run }, req.id, 200);
}

module.exports = {
  getMe,
  getHistory,
  getRunById,
};
