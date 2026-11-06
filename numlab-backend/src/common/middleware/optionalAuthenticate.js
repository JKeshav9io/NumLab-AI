'use strict';

const authenticate = require('./authenticate');

function optionalAuthenticate(req, res, next) {
  req.user = null;
  if (req.headers.authorization === undefined) {
    return next();
  }
  return authenticate(req, res, next);
}

module.exports = optionalAuthenticate;
