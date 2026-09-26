'use strict';

const asyncHandler = require('../../common/utils/asyncHandler');
const { AppError, errorCodes } = require('../../common/errors');
const solverRunRepository = require('../../db/repositories/solverRunRepository');
const reportService = require('./report.service');
const { validateReportParam } = require('./reports.validator');

/**
 * Controller to generate and download a PDF lab report for a solver run.
 * Route: POST /api/v1/reports/:runId
 */
const generateReport = asyncHandler(async (req, res) => {
  // 1. Validate route params
  const { runId } = validateReportParam(req.params);

  // 2. Fetch solver run with associated AI explanations
  const run = await solverRunRepository.findById(runId);

  // 3. Ownership check: Run must exist and belong to the authenticated user.
  // Return generic 404 NOT_FOUND to prevent ID enumeration across users.
  if (!run || run.userId !== req.user.id) {
    throw new AppError('Solver run not found', 404, errorCodes.NOT_FOUND);
  }

  // 4. Generate PDF report buffer
  const pdfBuffer = await reportService.generateSolverReportBuffer(run);

  // 5. Prepare download headers
  const sanitizedMethod = (run.method || 'solver-run').replace(/[^a-zA-Z0-9_-]/g, '-').toLowerCase();
  const dateStr = new Date().toISOString().split('T')[0];
  const filename = `numlab-report-${sanitizedMethod}-${runId.slice(0, 8)}-${dateStr}.pdf`;

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.setHeader('Content-Length', pdfBuffer.length);

  return res.end(pdfBuffer);
});

module.exports = {
  generateReport,
};
