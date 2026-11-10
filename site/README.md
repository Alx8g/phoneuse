# phoneuse.tech

The Phone Use website: static HTML and CSS in `src/`, built into `dist/` by `build.mjs`.

```sh
node build.mjs   # fills in the latest release's download links and the GitHub star count, writes dist/
./deploy.sh      # builds, then copies dist/ to the web server
```

- `src/`: the pages (home, privacy, terms, 404, the mailing-list confirmation page), styles, script, fonts and images.
- `src/img/`: the renders were made with Codex image generation; their prompts are in `.impeccable/gen/`.
- `tools/og.html`, `tools/og.mjs`: the 1200x630 link-preview image (`src/og.png`).
- `shots.mjs`: desktop and phone screenshots for review.
- `deploy/phoneuse.tech.conf`: a copy of the nginx config.
- `PRODUCT.md`, `DESIGN.md`: the product facts and the design system the pages follow.

Analytics are Plausible, and the bridge mailing list is a Kit form (`KIT_FORM` in `build.mjs`).
