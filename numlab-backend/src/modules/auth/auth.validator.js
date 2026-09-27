'use strict';

const Joi = require('joi');
const { validate } = require('../../common/validators');

// Modern NIST SP 800-63B Security Guidance:
// 1. Minimum 8 characters provides essential entropy against brute-force attacks.
// 2. We require at least one digit for baseline composition.
// 3. We deliberately avoid overly complex rules (e.g. requiring symbols + uppercase)
//    because research proves arbitrary complexity rules encourage predictable substitutions (e.g. 'P@ssword1!')
//    rather than truly high-entropy passphrases.
const registerSchema = Joi.object({
  email: Joi.string().email().trim().lowercase().max(255).required()
    .messages({
      'string.email': 'Please provide a valid email address',
      'string.empty': 'Email is required',
      'any.required': 'Email is required',
    }),
  password: Joi.string().min(8).max(128).pattern(/^(?=.*[0-9])/)
    .required()
    .messages({
      'string.min': 'Password must be at least 8 characters long',
      'string.max': 'Password cannot exceed 128 characters',
      'string.pattern.base': 'Password must contain at least one number',
      'string.empty': 'Password is required',
      'any.required': 'Password is required',
    }),
});

// For login, we only check presence and type.
// We NEVER validate password strength rules on login to prevent leaking policy rules to attackers.
const loginSchema = Joi.object({
  email: Joi.string().trim().lowercase().required()
    .messages({
      'string.empty': 'Email is required',
      'any.required': 'Email is required',
    }),
  password: Joi.string().required()
    .messages({
      'string.empty': 'Password is required',
      'any.required': 'Password is required',
    }),
});

const refreshSchema = Joi.object({
  refreshToken: Joi.string().trim().required()
    .messages({
      'string.empty': 'Refresh token is required',
      'any.required': 'Refresh token is required',
    }),
});

function validateRegisterRequest(body) {
  return validate(registerSchema, body);
}

function validateLoginRequest(body) {
  return validate(loginSchema, body);
}

function validateRefreshRequest(body) {
  return validate(refreshSchema, body);
}

module.exports = {
  validateRegisterRequest,
  validateLoginRequest,
  validateRefreshRequest,
};
