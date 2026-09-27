'use strict';

/**
 * Renders the basic NumLab AI lab report layout into a PDFKit document.
 * @param {PDFDocument} doc - PDFKit document instance
 * @param {Object} run - SolverRun database record with inputPayload, outputPayload, and aiExplanations
 */
function renderBasicTemplate(doc, run) {
  const primaryColor = '#1e3a8a'; // Dark blue
  const secondaryColor = '#3b82f6'; // Light blue
  const textColor = '#1f2937'; // Dark gray
  const lightGray = '#f3f4f6';
  const borderGray = '#d1d5db';
  const accentGreen = '#16a34a';
  const accentRed = '#dc2626';

  const output = run.outputPayload || {};
  const input = run.inputPayload || {};
  const explanations = run.aiExplanations || [];
  const latestExplanation = explanations.length > 0 ? explanations[explanations.length - 1] : null;

  const pageWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;

  // ----------------------------------------------------
  // 1. Header Banner & Branding
  // ----------------------------------------------------
  doc
    .rect(doc.page.margins.left, doc.y, pageWidth, 55)
    .fill(primaryColor);

  doc
    .fillColor('#ffffff')
    .font('Helvetica-Bold')
    .fontSize(18)
    .text('NumLab AI', doc.page.margins.left + 15, doc.y - 45, { continued: true })
    .font('Helvetica')
    .fontSize(11)
    .fillColor('#93c5fd')
    .text('   Numerical Computation Lab Report');

  doc
    .fontSize(9)
    .fillColor('#bfdbfe')
    .text(`Generated: ${new Date(run.createdAt || Date.now()).toUTCString()}  |  ID: ${run.id || 'N/A'}`, doc.page.margins.left + 15, doc.y - 2);

  doc.moveDown(2);

  // ----------------------------------------------------
  // 2. Executive Summary / Run Overview
  // ----------------------------------------------------
  const statusColor = output.status === 'converged' ? accentGreen : accentRed;

  doc
    .font('Helvetica-Bold')
    .fontSize(14)
    .fillColor(primaryColor)
    .text(output.method || run.method || 'Numerical Method Solution');

  doc.moveDown(0.3);

  // Status & Timing summary badges
  const startY = doc.y;
  doc
    .rect(doc.page.margins.left, startY, pageWidth, 28)
    .fillAndStroke(lightGray, borderGray);

  doc
    .font('Helvetica-Bold')
    .fontSize(9)
    .fillColor(textColor)
    .text('Status: ', doc.page.margins.left + 10, startY + 9, { continued: true })
    .fillColor(statusColor)
    .text((output.status || 'completed').toUpperCase(), { continued: true })
    .fillColor(textColor)
    .text('   |   Execution Time: ', { continued: true })
    .font('Helvetica')
    .text(`${output.executionTimeMs ?? 0} ms`, { continued: true })
    .font('Helvetica-Bold')
    .text('   |   Iterations: ', { continued: true })
    .font('Helvetica')
    .text(`${output.iterations?.length ?? 0}`);

  doc.moveDown(2);

  // ----------------------------------------------------
  // 3. Problem Parameters & Inputs
  // ----------------------------------------------------
  renderSectionHeading(doc, '1. Problem Input & Parameters', primaryColor);

  doc.font('Helvetica').fontSize(9).fillColor(textColor);
  const inputEntries = Object.entries(input).filter(([k]) => !['includeExplanation', 'includeGraphData'].includes(k));

  if (inputEntries.length > 0) {
    inputEntries.forEach(([key, val]) => {
      let formattedVal = typeof val === 'object' ? JSON.stringify(val) : String(val);
      if (formattedVal.length > 90) {
        formattedVal = formattedVal.slice(0, 87) + '...';
      }
      doc
        .font('Helvetica-Bold')
        .text(`• ${formatKeyName(key)}: `, { continued: true })
        .font('Courier')
        .text(formattedVal);
    });
  } else {
    doc.text('No input parameters recorded.');
  }

  doc.moveDown(1.5);

  // ----------------------------------------------------
  // 4. Final Answer & Results
  // ----------------------------------------------------
  renderSectionHeading(doc, '2. Final Solution & Results', primaryColor);

  if (output.finalAnswer) {
    const finalAnswerEntries = Object.entries(output.finalAnswer);
    doc
      .rect(doc.page.margins.left, doc.y, pageWidth, 20 + finalAnswerEntries.length * 15)
      .fillAndStroke('#eff6ff', '#bfdbfe');

    const answerBoxTop = doc.y + 8;
    finalAnswerEntries.forEach(([key, val], idx) => {
      let displayVal = typeof val === 'object' ? JSON.stringify(val) : String(val);
      doc
        .font('Helvetica-Bold')
        .fontSize(9)
        .fillColor(primaryColor)
        .text(`  ${formatKeyName(key)}: `, doc.page.margins.left + 10, answerBoxTop + idx * 15, { continued: true })
        .font('Courier-Bold')
        .fillColor(textColor)
        .text(displayVal);
    });
    doc.y = answerBoxTop + finalAnswerEntries.length * 15 + 12;
  } else {
    doc.font('Helvetica').fontSize(9).fillColor(textColor).text('No structured final answer recorded.');
  }

  doc.moveDown(1.5);

  // ----------------------------------------------------
  // 5. Warnings (if any)
  // ----------------------------------------------------
  if (output.warnings && output.warnings.length > 0) {
    renderSectionHeading(doc, 'Warnings & Convergence Notices', '#b45309');
    output.warnings.forEach((warn) => {
      doc
        .font('Helvetica')
        .fontSize(9)
        .fillColor('#92400e')
        .text(`⚠️  ${warn}`);
    });
    doc.moveDown(1.5);
  }

  // ----------------------------------------------------
  // 6. Step-by-Step Iteration Table
  // ----------------------------------------------------
  if (output.iterations && output.iterations.length > 0) {
    checkPageSpace(doc, 140);
    renderSectionHeading(doc, '3. Step-by-Step Iterations', primaryColor);

    renderIterationTable(doc, output.iterations, pageWidth);
    doc.moveDown(1.5);
  }

  // ----------------------------------------------------
  // 7. Vector Visualization / Graph (if graphData exists)
  // ----------------------------------------------------
  if (output.graphData) {
    checkPageSpace(doc, 180);
    renderSectionHeading(doc, '4. Graphical Visualization', primaryColor);
    renderVectorChart(doc, output.graphData, pageWidth);
    doc.moveDown(1.5);
  }

  // ----------------------------------------------------
  // 8. AI Pedagogical Explanation (if present)
  // ----------------------------------------------------
  if (latestExplanation && latestExplanation.responseText) {
    checkPageSpace(doc, 140);
    renderSectionHeading(doc, '5. AI Pedagogical Analysis', primaryColor);

    const explanationText = String(latestExplanation.responseText).trim();
    const focusMode = latestExplanation.focusMode || 'steps';

    doc
      .font('Helvetica-Bold')
      .fontSize(9)
      .fillColor(secondaryColor)
      .text(`Focus Mode: ${focusMode.toUpperCase()}`);

    doc.moveDown(0.5);

    // Callout box for AI text
    const textStartY = doc.y;
    doc
      .rect(doc.page.margins.left, textStartY, 4, 30) // Left accent stripe
      .fill(secondaryColor);

    doc
      .font('Helvetica')
      .fontSize(9)
      .fillColor(textColor)
      .text(explanationText, doc.page.margins.left + 12, textStartY, {
        width: pageWidth - 16,
        align: 'left',
        lineGap: 2,
      });

    doc.moveDown(1.5);
  }

  // ----------------------------------------------------
  // 9. Page Numbers in Footer
  // ----------------------------------------------------
  const range = doc.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i++) {
    doc.switchToPage(i);
    doc
      .font('Helvetica')
      .fontSize(8)
      .fillColor('#9ca3af')
      .text(
        `NumLab AI Platform  •  Page ${i + 1} of ${range.count}`,
        doc.page.margins.left,
        doc.page.height - 30,
        {
          width: pageWidth,
          align: 'center',
        }
      );
  }
}

/**
 * Draws a section header with an underline rule.
 */
function renderSectionHeading(doc, title, color) {
  doc
    .font('Helvetica-Bold')
    .fontSize(11)
    .fillColor(color)
    .text(title);

  doc
    .strokeColor('#e5e7eb')
    .lineWidth(1)
    .moveTo(doc.page.margins.left, doc.y + 2)
    .lineTo(doc.page.margins.left + (doc.page.width - doc.page.margins.left - doc.page.margins.right), doc.y + 2)
    .stroke();

  doc.moveDown(0.8);
}

/**
 * Formats camelCase object keys into human readable labels.
 */
function formatKeyName(key) {
  const result = key.replace(/([A-Z])/g, ' $1');
  return result.charAt(0).toUpperCase() + result.slice(1);
}

/**
 * Ensures there is sufficient vertical space remaining on the page, or creates a new page.
 */
function checkPageSpace(doc, requiredSpace) {
  const bottomMargin = doc.page.margins.bottom;
  const availableSpace = doc.page.height - bottomMargin - doc.y;
  if (availableSpace < requiredSpace) {
    doc.addPage();
  }
}

/**
 * Renders iteration table data cleanly with column headers.
 */
function renderIterationTable(doc, iterations, pageWidth) {
  if (!iterations || iterations.length === 0) return;

  const sampleRow = iterations[0];
  const rawKeys = Object.keys(sampleRow).filter((k) => !['formulaTemplate', 'substitution'].includes(k));
  const keys = rawKeys.slice(0, 6); // Max 6 columns for clean PDF fitting
  const colWidth = Math.floor(pageWidth / keys.length);

  // Table header
  const headerY = doc.y;
  doc
    .rect(doc.page.margins.left, headerY, pageWidth, 18)
    .fill('#e2e8f0');

  doc.font('Helvetica-Bold').fontSize(8).fillColor('#334155');
  keys.forEach((key, idx) => {
    doc.text(
      formatKeyName(key),
      doc.page.margins.left + idx * colWidth + 4,
      headerY + 5,
      { width: colWidth - 8, truncate: true }
    );
  });

  doc.y = headerY + 18;

  // Table rows (cap rendering at 100 rows to prevent run-away PDF bloat while showing full data)
  const displayRows = iterations.slice(0, 100);
  displayRows.forEach((row, rowIdx) => {
    checkPageSpace(doc, 20);
    const rowY = doc.y;
    const isEven = rowIdx % 2 === 0;

    if (isEven) {
      doc
        .rect(doc.page.margins.left, rowY, pageWidth, 16)
        .fill('#f8fafc');
    }

    doc.font('Courier').fontSize(7.5).fillColor('#1e293b');
    keys.forEach((key, colIdx) => {
      let cellVal = row[key];
      if (typeof cellVal === 'number') {
        cellVal = Number.isInteger(cellVal) ? String(cellVal) : cellVal.toFixed(6);
      } else if (typeof cellVal === 'object' && cellVal !== null) {
        cellVal = JSON.stringify(cellVal);
      } else {
        cellVal = String(cellVal ?? '');
      }

      doc.text(
        cellVal,
        doc.page.margins.left + colIdx * colWidth + 4,
        rowY + 4,
        { width: colWidth - 8, truncate: true }
      );
    });

    doc.y = rowY + 16;
  });

  if (iterations.length > 100) {
    doc
      .font('Helvetica-Oblique')
      .fontSize(8)
      .fillColor('#64748b')
      .text(`... and ${iterations.length - 100} more iterations truncated for document readability.`);
  }
}

/**
 * Draws a clean 2D line/scatter chart directly on the PDF using vector paths.
 */
function renderVectorChart(doc, graphData, pageWidth) {
  // Extract coordinate points
  let points = [];
  let scatterPoints = [];

  if (Array.isArray(graphData)) {
    points = graphData.filter((p) => p && typeof p.x === 'number' && typeof p.y === 'number');
  } else if (typeof graphData === 'object' && graphData !== null) {
    if (Array.isArray(graphData.sampledCurve)) {
      points = graphData.sampledCurve.filter((p) => p && typeof p.x === 'number' && typeof p.y === 'number');
    }
    if (Array.isArray(graphData.originalPoints)) {
      scatterPoints = graphData.originalPoints.filter((p) => p && typeof p.x === 'number' && typeof p.y === 'number');
    }
  }

  if (points.length < 2 && scatterPoints.length === 0) {
    doc.font('Helvetica').fontSize(9).fillColor('#6b7280').text('No plottable 2D coordinate points available.');
    return;
  }

  const chartHeight = 120;
  const chartWidth = Math.min(pageWidth, 420);
  const chartLeft = doc.page.margins.left + (pageWidth - chartWidth) / 2;
  const chartTop = doc.y;

  // Calculate coordinate domain & range
  const allX = [...points.map((p) => p.x), ...scatterPoints.map((p) => p.x)];
  const allY = [...points.map((p) => p.y), ...scatterPoints.map((p) => p.y)];
  const minX = Math.min(...allX);
  const maxX = Math.max(...allX);
  const minY = Math.min(...allY);
  const maxY = Math.max(...allY);

  const rangeX = maxX - minX || 1;
  const rangeY = maxY - minY || 1;

  // Draw chart background frame
  doc
    .rect(chartLeft, chartTop, chartWidth, chartHeight)
    .fillAndStroke('#f8fafc', '#cbd5e1');

  // Helper coordinate mapper
  const mapX = (x) => chartLeft + 25 + ((x - minX) / rangeX) * (chartWidth - 45);
  const mapY = (y) => chartTop + chartHeight - 20 - ((y - minY) / rangeY) * (chartHeight - 35);

  // Draw zero-axis lines if within range
  if (minY <= 0 && maxY >= 0) {
    const zeroY = mapY(0);
    doc
      .strokeColor('#e2e8f0')
      .lineWidth(0.8)
      .moveTo(chartLeft, zeroY)
      .lineTo(chartLeft + chartWidth, zeroY)
      .stroke();
  }

  // Draw sampled curve line
  if (points.length >= 2) {
    doc.save();
    doc.strokeColor('#2563eb').lineWidth(1.5);
    doc.moveTo(mapX(points[0].x), mapY(points[0].y));
    for (let i = 1; i < points.length; i++) {
      doc.lineTo(mapX(points[i].x), mapY(points[i].y));
    }
    doc.stroke();
    doc.restore();
  }

  // Draw scatter points (original nodes)
  if (scatterPoints.length > 0) {
    scatterPoints.forEach((pt) => {
      doc
        .circle(mapX(pt.x), mapY(pt.y), 3)
        .fillAndStroke('#dc2626', '#991b1b');
    });
  }

  // Axis bounds labels
  doc
    .font('Helvetica')
    .fontSize(7)
    .fillColor('#64748b')
    .text(`X: [${minX.toFixed(2)}, ${maxX.toFixed(2)}]`, chartLeft + 5, chartTop + chartHeight - 12)
    .text(`Y: [${minY.toFixed(2)}, ${maxY.toFixed(2)}]`, chartLeft + chartWidth - 85, chartTop + 5);

  doc.y = chartTop + chartHeight + 10;
}

module.exports = {
  renderBasicTemplate,
};
