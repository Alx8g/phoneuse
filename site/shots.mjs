// Captures the built site for review: node shots.mjs [baseURL]
// Uses playwright-core from the pocketmodel site checkout (no install here).
import { createRequire } from "node:module";
const require = createRequire("/home/lxe/many-eval/site/package.json");
const { chromium } = require("playwright-core");
const base = process.argv[2] || "http://127.0.0.1:8811";
const browser = await chromium.launch({ executablePath: "/home/lxe/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome" });
const shots = [
  { name: "desktop", w: 1440, h: 900, path: "/" },
  { name: "mobile", w: 390, h: 844, path: "/", mobile: true },
  { name: "privacy-mobile", w: 390, h: 844, path: "/privacy/", mobile: true },
];
for (const s of shots) {
  const ctx = await browser.newContext({ viewport: { width: s.w, height: s.h }, deviceScaleFactor: s.mobile ? 2 : 1, isMobile: !!s.mobile, hasTouch: !!s.mobile, reducedMotion: "reduce" });
  const page = await ctx.newPage();
  await page.goto(base + s.path, { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  const over = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
  await page.screenshot({ path: `.impeccable/review/${s.name}.png`, fullPage: true });
  console.log(s.name, "horizontal overflow:", over);
  await ctx.close();
}
await browser.close();
