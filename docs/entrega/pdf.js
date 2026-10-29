// Imprime docs/entrega/entrega.html a entrega.pdf con el Chromium de Playwright.
// Uso: node docs/entrega/pdf.js
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const html = path.join(__dirname, 'entrega.html');
  const pdf = path.join(__dirname, 'entrega.pdf');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + html, { waitUntil: 'networkidle' });
  await page.pdf({ path: pdf, preferCSSPageSize: true, printBackground: true });
  await browser.close();
  console.log('ok', pdf);
})();
