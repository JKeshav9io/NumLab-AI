'use strict';

const jwt = require('jsonwebtoken');
const env = require('../config/env');
const optionalAuthenticate = require('../common/middleware/optionalAuthenticate');
const { generateAccessToken } = require('../modules/auth/token');

test('optional authentication accepts requests without credentials', () => {
  const req = { headers: {} };
  const next = jest.fn();
  optionalAuthenticate(req, {}, next);
  expect(req.user).toBeNull();
  expect(next).toHaveBeenCalledWith();
});

test.each([
  ['Basic invalid', 'UNAUTHORIZED'],
  ['Bearer invalid', 'INVALID_TOKEN'],
  ['Bearer ', 'UNAUTHORIZED'],
])('optional authentication rejects supplied invalid credentials: %s', (authorization, code) => {
  const req = { headers: { authorization } };
  const next = jest.fn();
  optionalAuthenticate(req, {}, next);
  expect(req.user).toBeNull();
  expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401, code }));
});

test('optional authentication returns 401 for expired access tokens', () => {
  const token = jwt.sign({ sub: 'user', type: 'access' }, env.JWT_SECRET, {
    issuer: 'numlab-backend', expiresIn: -1,
  });
  const req = { headers: { authorization: `Bearer ${token}` } };
  const next = jest.fn();
  optionalAuthenticate(req, {}, next);
  expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401, code: 'TOKEN_EXPIRED' }));
});

test('optional authentication attaches the owner of a valid access token', () => {
  const req = { headers: { authorization: `Bearer ${generateAccessToken('user')}` } };
  const next = jest.fn();
  optionalAuthenticate(req, {}, next);
  expect(req.user).toEqual({ id: 'user' });
  expect(next).toHaveBeenCalledWith();
});
