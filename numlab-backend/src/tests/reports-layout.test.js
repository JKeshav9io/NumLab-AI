'use strict';

const { execFileSync } = require('node:child_process');
const path = require('node:path');
const { generateSolverReportBuffer } = require('../modules/reports/report.service');

const runId = '00000000-0000-4000-8000-000000000001';
const longTitle = 'Bisection Method - ' + 'A detailed numerical convergence analysis '.repeat(7).trim();

function reportRun({ rows = 0, title = 'Bisection Method', explanation = '' } = {}) {
  return {
    id: runId,
    createdAt: '2026-10-28T00:00:00.000Z',
    method: 'root/bisection',
    inputPayload: { equation: 'x - 2', lowerBound: 1, upperBound: 3 },
    outputPayload: {
      method: title,
      status: 'converged',
      executionTimeMs: 3,
      finalAnswer: { root: 2, converged: true },
      iterations: Array.from({ length: rows }, (_, index) => ({ iteration: index + 1, root: 2 })),
      warnings: [],
    },
    aiExplanations: explanation ? [{ focusMode: 'steps', responseText: explanation }] : [],
  };
}

function text(page) {
  return page.items.map((item) => item.text).join(' ').replace(/\s+/g, ' ');
}

function verifyPages(report) {
  report.pages.forEach((page, index) => {
    const footer = page.items.filter((item) => item.text.startsWith('NumLab AI Platform'));
    expect(footer).toHaveLength(1);
    expect(footer[0].text).toContain(`Page ${index + 1} of ${report.pages.length}`);
    expect(footer[0].top).toBeGreaterThanOrEqual(page.height - 40);
    expect(footer[0].bottom).toBeLessThan(page.height);
    const body = page.items.filter((item) => !footer.includes(item));
    expect(body.length).toBeGreaterThan(0);
    body.forEach((item) => {
      expect(item.left).toBeGreaterThanOrEqual(39.9);
      expect(item.right).toBeLessThanOrEqual(page.width - 39.9);
      expect(item.top).toBeGreaterThanOrEqual(39.9);
      expect(item.bottom).toBeLessThanOrEqual(page.height - 39.9);
    });
    expect(Math.max(...body.map((item) => item.bottom))).toBeLessThan(footer[0].top);
  });
}

describe('Generated PDF report layout', () => {
  let reports;
  const boundaryRows = [24, 25, 26, 27, 28, 29];

  beforeAll(async () => {
    const fixtures = [
      { name: 'short', run: reportRun() },
      { name: 'long-title', run: reportRun({ title: longTitle }) },
      { name: 'multi', run: reportRun({ rows: 90, explanation: 'The computed interval isolates the root.\n'.repeat(60) }) },
      ...boundaryRows.map((rows) => ({ name: `boundary-${rows}`, run: reportRun({ rows }) })),
    ];
    const input = [];
    for (const fixture of fixtures) {
      const bytes = await generateSolverReportBuffer(fixture.run);
      input.push({ name: fixture.name, pdf: bytes.toString('base64') });
    }
    reports = Object.fromEntries(JSON.parse(execFileSync(process.execPath, [
      path.join(__dirname, 'helpers/inspectPdf.cjs'),
    ], { input: JSON.stringify(input), encoding: 'utf8', timeout: 20000, maxBuffer: 4 * 1024 * 1024 }))
      .map(({ name, ...report }) => [name, report]));
  });

  test('a short report stays on one page with its inputs, answer and footer', () => {
    const report = reports.short;
    expect(report.pages).toHaveLength(1);
    verifyPages(report);
    expect(text(report.pages[0])).toContain('Equation: x - 2');
    expect(text(report.pages[0])).toContain('Root: 2');
    expect(text(report.pages[0])).toContain('Converged: true');
  });

  test('branding and complete metadata are inside the banner and above the body', () => {
    const page = reports.short.pages[0];
    const title = page.items.find((item) => item.text === 'NumLab AI');
    const subtitle = page.items.find((item) => item.text.includes('Numerical Computation Lab Report'));
    const metadata = page.items.filter((item) => item.text.includes('Generated:') || item.text.includes(runId));
    const bodyTitle = page.items.find((item) => item.text === 'Bisection Method');
    expect(title).toBeDefined();
    expect(subtitle).toBeDefined();
    expect(metadata.length).toBeGreaterThan(0);
    expect(text(page)).toContain(`Generated: Wed, 28 Oct 2026 00:00:00 GMT | ID: ${runId}`);
    [title, subtitle, ...metadata].forEach((item) => {
      expect(item.top).toBeGreaterThanOrEqual(40);
      expect(item.bottom).toBeLessThan(bodyTitle.top);
    });
  });

  test('a long report title wraps completely without overlapping banner or status', () => {
    const report = reports['long-title'];
    verifyPages(report);
    expect(text(report.pages[0])).toContain(longTitle);
    const page = report.pages[0];
    const metadata = page.items.find((item) => item.text.includes('Generated:'));
    const title = page.items.filter((item) => item.text.includes('Bisection Method -') || item.text.includes('convergence analysis'));
    const status = page.items.find((item) => item.text.startsWith('Status:'));
    expect(status).toBeDefined();
    expect(title.length).toBeGreaterThan(1);
    expect(Math.min(...title.map((item) => item.top))).toBeGreaterThan(metadata.bottom);
    expect(Math.max(...title.map((item) => item.bottom))).toBeLessThan(status.top);
  });

  test('multi-page body content has one correctly numbered footer per actual page', () => {
    const report = reports.multi;
    expect(report.pages.length).toBeGreaterThanOrEqual(3);
    verifyPages(report);
    expect(report.pages.map(text).join(' ')).toContain('90');
    expect(report.pages.map(text).join(' ')).toContain('5. AI Pedagogical Analysis');
    expect(report.pages.at(-1).items.some((item) => item.text.includes('computed interval'))).toBe(true);
  });

  test.each(boundaryRows)('a %i-row report has no footer-only page at a page boundary', (rows) => {
    verifyPages(reports[`boundary-${rows}`]);
  });

  test('boundary fixtures actually exercise content near the body bottom margin', () => {
    const gaps = boundaryRows.flatMap((rows) => reports[`boundary-${rows}`].pages.map((page) => {
      const body = page.items.filter((item) => !item.text.startsWith('NumLab AI Platform'));
      return page.height - 40 - Math.max(...body.map((item) => item.bottom));
    }));
    expect(Math.min(...gaps)).toBeGreaterThanOrEqual(0);
    expect(Math.min(...gaps)).toBeLessThan(20);
  });
});
