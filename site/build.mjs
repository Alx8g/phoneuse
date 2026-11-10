// Builds the static site into dist/: copies src/, fills in the release's asset
// URLs from the GitHub API (falling back to the releases page), and writes the
// sitemap. Run: node build.mjs   Deploy: ./deploy.sh
import { cpSync, rmSync, readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const RELEASES = "https://github.com/lxe/phoneuse/releases/latest";
const SITE = "https://phoneuse.tech";
// Kit form "phone use bridge" (double opt-in), in lxe's Kit account.
// Kit form "phone use bridge" (10169370), double opt-in, confirm redirects to /confirmed/.
const KIT_FORM = process.env.KIT_FORM || "10169370";

async function release() {
  try {
    const res = await fetch("https://api.github.com/repos/lxe/phoneuse/releases/latest", {
      headers: { Accept: "application/vnd.github+json", "User-Agent": "phoneuse-site-build" },
    });
    if (!res.ok) throw new Error(`GitHub answered ${res.status}`);
    const r = await res.json();
    const find = (re) => r.assets.find((a) => re.test(a.name));
    return { version: r.tag_name.replace(/^v/, ""), linux: find(/x86_64\.flatpak$/), mac: find(/\.dmg$/), bridge: find(/^phoneuse-bridge-.*\.bin$/) };
  } catch (err) {
    console.warn(`release lookup failed (${err.message}); linking the releases page`);
    return { version: "", linux: null, mac: null, bridge: null };
  }
}

const rel = await release();
// Star count for the header's GitHub link, read at build time (visitors' browsers never call GitHub).
const stars = await fetch("https://api.github.com/repos/lxe/phoneuse", { headers: { "User-Agent": "phoneuse-site-build" } })
  .then((r) => (r.ok ? r.json() : null)).then((r) => (r && typeof r.stargazers_count === "number" ? r.stargazers_count : null)).catch(() => null);
const fmtStars = (n) => (n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k" : String(n));
const asset = (a, fallback) => ({ url: a ? a.browser_download_url : RELEASES, name: a ? a.name : fallback });
const linux = asset(rel.linux, "Phone Use for Linux"), mac = asset(rel.mac, "Phone Use for macOS"), bridge = asset(rel.bridge, "Bridge firmware");
if (!KIT_FORM) console.warn("KIT_FORM is not set: the bridge sign-up will fail");
const vars = {
  VERSION: rel.version || "latest", BUILD: Date.now().toString(36),
  LINUX_URL: linux.url, LINUX_NAME: linux.name, MAC_URL: mac.url, MAC_NAME: mac.name, BRIDGE_URL: bridge.url, BRIDGE_NAME: bridge.name,
  KIT_FORM,
  STARS: stars == null ? "" : `<span class="stars" aria-label="${stars} stars"><svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true"><path fill="currentColor" d="M8 .8l2.2 4.6 5 .7-3.6 3.5.9 5L8 12.2 3.5 14.6l.9-5L.8 6.1l5-.7z"/></svg>${fmtStars(stars)}</span>`,
};

rmSync("dist", { recursive: true, force: true });
cpSync("src", "dist", { recursive: true });

const pages = [];
(function walk(dir) {
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) { walk(p); continue; }
    if (!/\.(html|txt|xml|webmanifest)$/.test(f)) continue;
    let s = readFileSync(p, "utf8").replace(/\{\{(\w+)\}\}/g, (m, k) => (k in vars ? vars[k] : m));
    const left = s.match(/\{\{\w+\}\}/);
    if (left) throw new Error(`${p}: unfilled ${left[0]}`);
    writeFileSync(p, s);
    if (f === "index.html" && !/robots" content="noindex/.test(s)) pages.push(p.slice("dist".length).replace(/index\.html$/, ""));
  }
})("dist");

const today = new Date().toISOString().slice(0, 10);
writeFileSync("dist/sitemap.xml", `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${pages.sort().map((p) => `  <url><loc>${SITE}${p}</loc><lastmod>${today}</lastmod></url>`).join("\n")}
</urlset>
`);
console.log(`built dist/ for Phone Use ${vars.VERSION}: ${pages.join(", ")}`);
console.log(`  linux  ${linux.url}\n  mac    ${mac.url}\n  bridge ${bridge.url}`);
