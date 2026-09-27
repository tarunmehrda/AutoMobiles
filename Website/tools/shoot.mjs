/**
 * Full-page screenshots of every route, at a phone width and a desktop width,
 * in both themes — plus a console-error and broken-link check.
 *
 *   node tools/shoot.mjs [baseUrl] [outDir]
 *
 * Needs a preview server already running (npm run preview).
 */
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import puppeteer from 'puppeteer-core';

const BASE = process.argv[2] || 'http://127.0.0.1:4173';
const OUT = process.argv[3] || 'shots';

const CHROME =
  process.env.CHROME_PATH ||
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const ROUTES = ['/', '/features', '/contact', '/privacy', '/terms', '/nope-404'];

const VIEWPORTS = [
  { name: 'mobile', width: 390, height: 844, deviceScaleFactor: 2, isMobile: true },
  { name: 'desktop', width: 1440, height: 900, deviceScaleFactor: 1, isMobile: false },
];

const problems = [];

/** Scroll the page end to end so lazy images and reveals actually fire. */
async function settle(page) {
  await page.evaluate(async () => {
    /* The site sets scroll-behavior: smooth. Each scrollTo would interrupt the
       last one's animation and the page would crawl instead of stepping. */
    const root = document.documentElement;
    const was = root.style.scrollBehavior;
    root.style.scrollBehavior = 'auto';

    await new Promise((resolve) => {
      let y = 0;
      const step = () => {
        y += window.innerHeight * 0.7;
        window.scrollTo(0, y);
        if (y < document.body.scrollHeight) setTimeout(step, 140);
        else setTimeout(resolve, 600);
      };
      step();
    });

    window.scrollTo(0, 0);
    root.style.scrollBehavior = was;
  });
  await new Promise((r) => setTimeout(r, 700));
}

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--hide-scrollbars', '--disable-gpu', '--no-sandbox'],
});

await mkdir(OUT, { recursive: true });

for (const vp of VIEWPORTS) {
  for (const theme of ['light', 'dark']) {
    for (const route of ROUTES) {
      const page = await browser.newPage();
      await page.setViewport(vp);
      await page.emulateMediaFeatures([
        { name: 'prefers-color-scheme', value: theme },
      ]);

      page.on('console', (m) => {
        if (m.type() === 'error') problems.push(`[console] ${route} ${vp.name}/${theme}: ${m.text()}`);
      });
      page.on('pageerror', (e) => problems.push(`[pageerror] ${route}: ${e.message}`));
      page.on('requestfailed', (r) =>
        problems.push(`[request] ${route}: ${r.url()} — ${r.failure()?.errorText}`),
      );

      await page.goto(BASE + route, { waitUntil: 'networkidle2', timeout: 30000 });
      await settle(page);

      /* Images that resolved but have no pixels, and any sideways page scroll. */
      const audit = await page.evaluate(() => {
        const broken = [...document.images]
          .filter((i) => !i.complete || i.naturalWidth === 0)
          .map((i) => i.currentSrc || i.src);
        return {
          broken,
          overflow: document.documentElement.scrollWidth > window.innerWidth + 1,
          scrollWidth: document.documentElement.scrollWidth,
          inner: window.innerWidth,
          title: document.title,
        };
      });

      if (audit.broken.length) problems.push(`[img] ${route} ${vp.name}/${theme}: ${audit.broken.join(', ')}`);
      if (audit.overflow) {
        problems.push(
          `[overflow] ${route} ${vp.name}/${theme}: scrollWidth ${audit.scrollWidth} > ${audit.inner}`,
        );
      }

      const slug = route === '/' ? 'home' : route.replace(/\//g, '') || 'home';
      const file = path.join(OUT, `${slug}-${vp.name}-${theme}.png`);
      await page.screenshot({ path: file, fullPage: true });
      console.log(`${file}  —  ${audit.title}`);

      await page.close();
    }
  }
}

await browser.close();

await writeFile(path.join(OUT, 'problems.txt'), problems.join('\n') || 'none', 'utf8');
console.log('\n--- problems ---');
console.log(problems.length ? problems.join('\n') : 'none');
