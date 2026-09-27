'use strict';

const {
  buildExplanation,
  buildFinalAnswer,
  buildFunctionGraphData,
  buildFunctionInput,
  buildResult,
  compileFunction,
  round,
} = require('./differentiation.utils');

function solveFunctionFiniteDifference(params) {
  const start = Date.now();
  const {
    targetX,
    h,
    variant,
    exactDerivative,
    includeExplanation,
    includeGraphData,
  } = params;
  const { compiled, evaluate } = compileFunction(params.equation);
  const values = evaluateStencil(evaluate, targetX, h, variant);
  const derivative = values.derivative;
  const iterations = [
    {
      step: 1,
      variant,
      x: round(targetX),
      h: round(h),
      ...values.publicValues,
      derivative: round(derivative),
      formulaTemplate: values.formulaTemplate,
      substitution: values.substitution,
    },
  ];

  return buildResult({
    method: 'Function-based Finite Difference',
    input: buildFunctionInput(params),
    iterations,
    finalAnswer: buildFinalAnswer(derivative, exactDerivative, `Completed ${variant} finite difference formula`),
    explanation: includeExplanation ? buildExplanation('Function-based Finite Difference', [
      'Evaluate the function at the stencil points selected by the variant.',
      'Substitute those function values into the finite-difference formula.',
      'Use h as the spacing between stencil points.',
    ]) : null,
    graphData: includeGraphData ? buildFunctionGraphData(compiled, targetX, h) : [],
    warnings: [],
    start,
  });
}

function evaluateStencil(evaluate, x, h, variant) {
  if (variant === 'forward') {
    const fX = evaluate(x);
    const fXPlusH = evaluate(x + h);
    const derivative = (fXPlusH - fX) / h;

    return {
      derivative,
      publicValues: {
        fX: round(fX),
        fXPlusH: round(fXPlusH),
      },
      formulaTemplate: "f'(x) = (f(x + h) - f(x)) / h",
      substitution: `f'(${round(x)}) = (${round(fXPlusH)} - ${round(fX)}) / ${round(h)} = ${round(derivative)}`,
    };
  }

  if (variant === 'backward') {
    const fXMinusH = evaluate(x - h);
    const fX = evaluate(x);
    const derivative = (fX - fXMinusH) / h;

    return {
      derivative,
      publicValues: {
        fXMinusH: round(fXMinusH),
        fX: round(fX),
      },
      formulaTemplate: "f'(x) = (f(x) - f(x - h)) / h",
      substitution: `f'(${round(x)}) = (${round(fX)} - ${round(fXMinusH)}) / ${round(h)} = ${round(derivative)}`,
    };
  }

  const fXMinusH = evaluate(x - h);
  const fXPlusH = evaluate(x + h);
  const derivative = (fXPlusH - fXMinusH) / (2 * h);

  return {
    derivative,
    publicValues: {
      fXMinusH: round(fXMinusH),
      fXPlusH: round(fXPlusH),
    },
    formulaTemplate: "f'(x) = (f(x + h) - f(x - h)) / (2h)",
    substitution: `f'(${round(x)}) = (${round(fXPlusH)} - ${round(fXMinusH)}) / (2 * ${round(h)}) = ${round(derivative)}`,
  };
}

module.exports = {
  evaluateStencil,
  solveFunctionFiniteDifference,
  functionFiniteDifference: solveFunctionFiniteDifference,
};
