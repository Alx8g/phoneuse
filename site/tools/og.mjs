// Renders tools/og.html to src/og.png (1200x630) against a local server of dist/.
// Run after `node build.mjs`, with `python3 -m http.server 8811 --directory dist` up.
import { createRequire } from "node:module";
import { copyFileSync } from "node:fs";
const require = createRequire("/home/lxe/many-eval/site/package.json");
const { chromium } = require("playwright-core");
copyFileSync("tools/og.html", "dist/og-src.html");
const b = await chromium.launch({ executablePath: "/home/lxe/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome" });
const p = await (await b.newContext({ viewport: { width: 1200, height: 630 } })).newPage();
await p.goto("http://127.0.0.1:8811/og-src.html", { waitUntil: "networkidle" });
await p.evaluate(() => document.fonts.ready);
await p.screenshot({ path: "src/og.png" });
await b.close();
console.log("wrote src/og.png");
