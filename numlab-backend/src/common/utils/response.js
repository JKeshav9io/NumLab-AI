'use strict';

function buildSuccessResponse(data, requestId) {
  return {
    success: true,
    data,
    meta: {
      requestId,
      timestamp: new Date().toISOString(),
    },
  };
}

function sendSuccess(res, data, requestId, statusCode = 200) {
  return res.status(statusCode).json(buildSuccessResponse(data, requestId));
}

module.exports = {
  buildSuccessResponse,
  sendSuccess,
};
