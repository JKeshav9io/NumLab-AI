'use strict';

const math = require('mathjs');
const { AppError, errorCodes } = require('../errors');

function compileExpression(expression) {
  try {
    return math.compile(expression);
  } catch (_err) {
    throw new AppError(
      `Invalid expression: ${expression}`,
      400,
      errorCodes.INVALID_EXPRESSION
    );
  }
}

function evaluateAt(compiled, scope) {
  try {
    const value = compiled.evaluate(scope);

    if (typeof value !== 'number' || !Number.isFinite(value)) {
      throw new Error('Expression did not evaluate to a finite number');
    }

    return value;
  } catch (_err) {
    throw new AppError(
      'Expression evaluation failed',
      400,
      errorCodes.EVAL_FAILED,
      { scope }
    );
  }
}

module.exports = {
  compileExpression,
  evaluateAt,
};
