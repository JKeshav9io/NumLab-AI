'use strict';

const { canonicalize, canonicalJson, generatePromptHash } = require('../common/utils/cacheKey');

describe('Deterministic Cache Key Generation (canonicalize & generatePromptHash)', () => {
  test('canonicalJson produces identical strings for objects with different key insertion order', () => {
    const objA = {
      b: 2,
      a: 1,
      nested: { z: 26, y: 25, x: 24 },
      list: [{ d: 4, c: 3 }],
    };

    const objB = {
      a: 1,
      nested: { x: 24, z: 26, y: 25 },
      b: 2,
      list: [{ c: 3, d: 4 }],
    };

    expect(canonicalJson(objA)).toBe(canonicalJson(objB));
    expect(canonicalJson(objA)).toBe(
      '{"a":1,"b":2,"list":[{"c":3,"d":4}],"nested":{"x":24,"y":25,"z":26}}'
    );
  });

  test('generatePromptHash produces identical SHA-256 hashes for logically identical solver results with different key ordering', () => {
    const solverResult1 = {
      method: 'Bisection Method',
      status: 'converged',
      input: { equation: 'x^2 - 4', lowerBound: 0, upperBound: 3, tolerance: 0.001 },
      finalAnswer: { root: 2.0001, converged: true, iterationsCount: 14 },
      warnings: [],
      iterations: [
        { iteration: 1, a: 0, b: 3, c: 1.5, fc: -1.75 },
        { iteration: 2, a: 1.5, b: 3, c: 2.25, fc: 1.0625 },
      ],
      executionTimeMs: 12,
    };

    const solverResult2 = {
      status: 'converged',
      finalAnswer: { iterationsCount: 14, converged: true, root: 2.0001 },
      input: { tolerance: 0.001, upperBound: 3, lowerBound: 0, equation: 'x^2 - 4' },
      warnings: [],
      method: 'Bisection Method',
      executionTimeMs: 45, // Execution time difference should not break cache hit
      iterations: [
        { b: 3, a: 0, c: 1.5, iteration: 1, fc: -1.75 },
        { fc: 1.0625, iteration: 2, c: 2.25, b: 3, a: 1.5 },
      ],
    };

    const hash1 = generatePromptHash({ solverResult: solverResult1, focus: 'steps' });
    const hash2 = generatePromptHash({ solverResult: solverResult2, focus: 'steps' });

    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64); // Valid 256-bit hex
  });

  test('generatePromptHash produces different hashes when focus or mathematical parameters change', () => {
    const baseResult = {
      method: 'Bisection Method',
      status: 'converged',
      input: { equation: 'x^2 - 4' },
      finalAnswer: { root: 2 },
    };

    const hashSteps = generatePromptHash({ solverResult: baseResult, focus: 'steps' });
    const hashSummary = generatePromptHash({ solverResult: baseResult, focus: 'summary' });
    const hashDifferentRoot = generatePromptHash({
      solverResult: { ...baseResult, finalAnswer: { root: 3 } },
      focus: 'steps',
    });

    expect(hashSteps).not.toBe(hashSummary);
    expect(hashSteps).not.toBe(hashDifferentRoot);
  });
});
