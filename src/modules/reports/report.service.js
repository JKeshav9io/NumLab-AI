'use strict';

const PDFDocument = require('pdfkit');
const logger = require('../../config/logger');
const { AppError, errorCodes } = require('../../common/errors');
const { renderBasicTemplate } = require('./templates/basic.template');

/**
 * Generates a PDF lab report buffer for a given solver run record.
 * @param {Object} run - SolverRun database record (including aiExplanations)
 * @returns {Promise<Buffer>} Generated PDF binary buffer
 */
async function generateSolverReportBuffer(run) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margins: { top: 40, bottom: 40, left: 40, right: 40 },
        bufferPages: true,
        info: {
          Title: `NumLab AI Report - ${run.method || 'Solver Run'}`,
          Author: 'NumLab AI',
          Subject: 'Numerical Method Lab Report',
          CreationDate: new Date(),
        },
      });

      const chunks = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => {
        const resultBuffer = Buffer.concat(chunks);
        logger.info(
          { runId: run.id, sizeBytes: resultBuffer.length },
          'PDF report successfully generated'
        );
        resolve(resultBuffer);
      });
      doc.on('error', (err) => {
        logger.error({ runId: run.id, err: err.message }, 'PDFKit document error during generation');
        reject(
          new AppError(
            'Failed to generate PDF report',
            500,
            errorCodes.REPORT_GENERATION_ERROR,
            { originalError: err.message }
          )
        );
      });

      // Render document template
      renderBasicTemplate(doc, run);

      // Finalize document stream
      doc.end();
    } catch (error) {
      logger.error({ runId: run?.id, err: error.message }, 'Error in report generation service');
      reject(
        new AppError(
          'Failed to generate PDF report',
          500,
          errorCodes.REPORT_GENERATION_ERROR,
          { originalError: error.message }
        )
      );
    }
  });
}

module.exports = {
  generateSolverReportBuffer,
};
