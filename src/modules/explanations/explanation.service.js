'use strict';

const { buildExplainMessages } = require('./promptBuilder');
const { requestAiExplanation } = require('./openAiCompatibleClient');

async function explainSolverResult(params) {
  const { solverResult, focus, includeGraphSummary } = params;
  const messages = buildExplainMessages({
    solverResult,
    focus,
    includeGraphSummary,
  });
  const providerResult = await requestAiExplanation(messages);

  return {
    explanation: providerResult.explanation,
    focus,
    model: providerResult.model,
    usage: providerResult.usage,
    source: {
      method: solverResult.method,
      status: solverResult.status,
    },
  };
}

module.exports = {
  explainSolverResult,
};
