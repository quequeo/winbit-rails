// Imprime cada HTML a PDF (A4 horizontal) con Chrome headless.
// Uso: node render_pdf.js '[{"html":"...","pdf":"..."}]'
// Requiere puppeteer (npm i puppeteer) o PUPPETEER_PATH apuntando a su carpeta.
const path = require("path");
let puppeteer;
try { puppeteer = require(process.env.PUPPETEER_PATH || "puppeteer"); }
catch (e) {
  puppeteer = require("/home/claude/.npm-global/lib/node_modules/@mermaid-js/mermaid-cli/node_modules/puppeteer");
}

(async () => {
  const trabajos = JSON.parse(process.argv[2]);
  const browser = await puppeteer.launch({
    headless: true,
    executablePath: process.env.CHROME_PATH || undefined,
    args: ["--no-sandbox", "--allow-file-access-from-files"],
  });
  const page = await browser.newPage();
  for (const t of trabajos) {
    await page.goto("file://" + path.resolve(t.html), { waitUntil: "networkidle0" });
    await page.evaluateHandle("document.fonts.ready");
    await page.pdf({
      path: t.pdf, printBackground: true, preferCSSPageSize: true,
      width: "297mm", height: "210mm", margin: { top: 0, right: 0, bottom: 0, left: 0 },
    });
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
