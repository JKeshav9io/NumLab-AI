'use strict';

const {
  CORE_RULE,
  buildExplainMessages,
  summarizeGraphData,
  summarizeIterations,
} = require('../modules/explanations/promptBuilder');

describe('Explanation prompt builder', () => {
  test('builds prompts with solver output and AI safety boundary', () => {
    const messages = buildExplainMessages({
      solverResult: {
        method: 'Bisection Method',
        status: 'converged',
        input: { equation: 'x^2 - 4' },
        iterations: [{ iteration: 1, c: 2, fC: 0 }],
        finalAnswer: { root: 2, converged: true },
        warnings: ['test warning'],
        executionTimeMs: 2,
      },
      focus: 'steps',
      includeGraphSummary: false,
    });

    expect(messages).toHaveLength(2);
    expect(messages[0].role).toBe('system');
    expect(messages[0].content).toContain(CORE_RULE);
    expect(messages[0].content).toContain('Do not recalculate');
    expect(messages[1].content).toContain('Bisection Method');
    expect(messages[1].content).toContain('converged');
    expect(messages[1].content).toContain('root');
    expect(messages[1].content).toContain('test warning');
  });

  test('summarizes large iteration arrays', () => {
    const iterations = Array.from({ length: 8 }, (_value, index) => ({
      iteration: index + 1,
      value: index,
    }));

    const summary = summarizeIterations(iterations);

    expect(summary.totalRows).toBe(8);
    expect(summary.sampledRows).toHaveLength(5);
    expect(summary.sampledRows[0].iteration).toBe(1);
    expect(summary.sampledRows[4].iteration).toBe(8);
    expect(summary.omittedMiddleRows).toBe(3);
  });

  test('handles missing optional fields and graph summary', () => {
    const messages = buildExplainMessages({
      solverResult: {
        method: 'Gauss Elimination',
        status: 'converged',
        finalAnswer: { solution: [1, 2] },
      },
      focus: 'summary',
      includeGraphSummary: true,
    });

    expect(messages[1].content).toContain('Gauss Elimination');
    expect(messages[1].content).toContain('graphDataSummary');
    expect(summarizeGraphData(undefined)).toEqual({
      shape: 'none',
      value: null,
    });
  });
});
