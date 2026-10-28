'use strict';

// Keep the application and Jest suites CommonJS. PDF.js is ESM, so the parser
// runs in a plain Node subprocess instead of changing Jest's module runtime.
async function inspectPdf(bytes) {
  const { getDocument } = await import('pdfjs-dist/legacy/build/pdf.mjs');
  const task = getDocument({
    data: new Uint8Array(bytes),
    useSystemFonts: true,
    isEvalSupported: false,
    verbosity: 0,
  });
  const document = await task.promise;
  try {
    const pages = [];
    for (let number = 1; number <= document.numPages; number++) {
      const page = await document.getPage(number);
      const viewport = page.getViewport({ scale: 1 });
      const content = await page.getTextContent();
      const items = content.items.filter((item) => item.str?.trim()).map((item) => {
        const style = content.styles[item.fontName];
        const height = Math.hypot(item.transform[2], item.transform[3]);
        const baseline = viewport.height - item.transform[5];
        return {
          text: item.str,
          left: item.transform[4],
          right: item.transform[4] + item.width,
          top: baseline - style.ascent * height,
          bottom: baseline - style.descent * height,
        };
      });
      pages.push({ width: viewport.width, height: viewport.height, items });
      page.cleanup();
    }
    return { pages };
  } finally {
    await document.destroy();
  }
}

module.exports = { inspectPdf };

if (require.main === module) {
  const fs = require('node:fs');
  const fixtures = JSON.parse(fs.readFileSync(0, 'utf8'));
  Promise.all(fixtures.map(async ({ name, pdf }) => ({
    name,
    ...await inspectPdf(Buffer.from(pdf, 'base64')),
  }))).then((reports) => process.stdout.write(JSON.stringify(reports))).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
