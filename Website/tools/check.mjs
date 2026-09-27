/**
 * Functional check: every link, every button, both themes, the mobile drawer
 * and the contact form's validation and submit path.
 *
 *   node tools/check.mjs [baseUrl]
 *
 * Needs a preview server already running (npm run preview).
 * Exits non-zero if anything fails, so it can gate a deploy.
 */
import puppeteer from 'puppeteer-core';

const BASE = process.argv[2] || 'http://127.0.0.1:4173';
const CHROME =
  process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const ROUTES = ['/', '/features', '/contact', '/privacy', '/terms'];

let pass = 0;
const fails = [];

function ok(name, condition, detail = '') {
  if (condition) {
    pass += 1;
    console.log(`  ok   ${name}`);
  } else {
    fails.push(`${name}${detail ? ` — ${detail}` : ''}`);
    console.log(`  FAIL ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--hide-scrollbars', '--disable-gpu', '--no-sandbox'],
});

const page = await browser.newPage();
await page.setViewport({ width: 1440, height: 900 });

/* ------------------------------------------------------------ 1. links */

console.log('\nLinks');
const internal = new Set();
const externalProblems = [];

for (const route of ROUTES) {
  await page.goto(BASE + route, { waitUntil: 'networkidle2' });

  const links = await page.$$eval('a[href]', (as) =>
    as.map((a) => ({
      href: a.getAttribute('href'),
      resolved: a.href,
      target: a.getAttribute('target'),
      rel: a.getAttribute('rel') || '',
      text: (a.textContent || '').trim().slice(0, 40),
      hasLabel: !!(a.textContent || '').trim() || !!a.getAttribute('aria-label'),
    })),
  );

  ok(`${route}: no empty or placeholder hrefs`,
    links.every((l) => l.href && l.href !== '#' && l.href !== 'javascript:void(0)'),
    links.filter((l) => !l.href || l.href === '#').map((l) => l.text).join(', '));

  ok(`${route}: every link has an accessible name`,
    links.every((l) => l.hasLabel));

  links.forEach((l) => {
    const u = new URL(l.resolved, BASE);
    const isHttp = u.protocol === 'http:' || u.protocol === 'https:';
    if (!isHttp) return; // tel: / mailto: are fine as they are

    if (u.origin === new URL(BASE).origin) {
      internal.add(u.pathname);
    } else {
      const rel = l.rel.split(/\s+/);
      if (l.target !== '_blank' || !rel.includes('noopener') || !rel.includes('noreferrer')) {
        externalProblems.push(`${route} → ${u.href} (target=${l.target} rel="${l.rel}")`);
      }
    }
  });
}

ok('every external link opens in a new tab with noopener noreferrer',
  externalProblems.length === 0, externalProblems.join(' | '));

/* Each internal path must render a real page, not the 404. */
console.log('\nInternal routes resolve');
for (const path of [...internal].sort()) {
  await page.goto(BASE + path, { waitUntil: 'networkidle2' });
  const title = await page.title();
  ok(`${path} → ${title}`, !title.startsWith('Page not found'));
}

/* Something that does not exist must still reach the 404 page, not a blank. */
await page.goto(`${BASE}/definitely-not-a-page`, { waitUntil: 'networkidle2' });
ok('unknown path shows the 404 page', (await page.title()).startsWith('Page not found'));

/* ------------------------------------------------------------ 2. theme */

console.log('\nTheme');
await page.goto(BASE, { waitUntil: 'networkidle2' });

const first = await page.$eval(':root', (r) => r.getAttribute('data-theme'));
await page.click('.theme-toggle');
const second = await page.$eval(':root', (r) => r.getAttribute('data-theme'));
ok('toggle flips the theme', first !== second, `${first} → ${second}`);

ok('the choice is remembered',
  (await page.evaluate(() => localStorage.getItem('ba-theme'))) === second);

const pressed = await page.$eval('.theme-toggle', (b) => b.getAttribute('aria-pressed'));
ok('aria-pressed matches the theme', pressed === String(second === 'dark'));

await page.reload({ waitUntil: 'networkidle2' });
ok('the theme survives a reload',
  (await page.$eval(':root', (r) => r.getAttribute('data-theme'))) === second);

/* The pre-paint script must have set it before React ever mounted. */
const noFlash = await page.evaluate(() => document.documentElement.hasAttribute('data-theme'));
ok('data-theme is set before paint', noFlash);

await page.evaluate(() => localStorage.removeItem('ba-theme'));

/* ------------------------------------------------------ 3. mobile menu */

console.log('\nMobile drawer');
await page.setViewport({ width: 390, height: 844, isMobile: true });
await page.goto(BASE, { waitUntil: 'networkidle2' });

const drawerOpen = () => page.$eval('#site-nav', (n) => n.classList.contains('is-open'));

ok('drawer starts closed', !(await drawerOpen()));
await page.click('.nav-toggle');
ok('the hamburger opens it', await drawerOpen());
ok('aria-expanded is true',
  (await page.$eval('.nav-toggle', (b) => b.getAttribute('aria-expanded'))) === 'true');
ok('the page behind is locked',
  (await page.evaluate(() => document.body.style.overflow)) === 'hidden');

await page.keyboard.press('Escape');
ok('Escape closes it', !(await drawerOpen()));
ok('scrolling is released',
  (await page.evaluate(() => document.body.style.overflow)) !== 'hidden');

await page.click('.nav-toggle');
await page.evaluate(() => [...document.querySelectorAll('#site-nav a')]
  .find((a) => a.textContent.trim() === 'Features').click());
await new Promise((r) => setTimeout(r, 400));
ok('following a link closes it', !(await drawerOpen()));
ok('and it navigated', (await page.title()).startsWith('Features'));

/* ------------------------------------------------------------- 4. FAQ */

console.log('\nFAQ');
await page.setViewport({ width: 1440, height: 900 });
await page.goto(BASE, { waitUntil: 'networkidle2' });

await page.evaluate(() => document.querySelectorAll('.faq summary')[0].click());
await new Promise((r) => setTimeout(r, 150));
ok('the first question opens',
  await page.$eval('.faq details', (d) => d.open));

await page.evaluate(() => document.querySelectorAll('.faq summary')[1].click());
await new Promise((r) => setTimeout(r, 150));
const open = await page.$$eval('.faq details', (ds) => ds.filter((d) => d.open).length);
ok('opening another closes the first', open === 1, `${open} open`);

/* -------------------------------------------------------- 5. back to top */

console.log('\nBack to top');
await page.evaluate(() => {
  document.documentElement.style.scrollBehavior = 'auto';
  window.scrollTo(0, 3000);
});
await new Promise((r) => setTimeout(r, 400));
ok('the button appears once scrolled',
  await page.$eval('.to-top', (b) => b.classList.contains('is-on')));

await page.click('.to-top');
await new Promise((r) => setTimeout(r, 2000));
ok('and it returns to the top', (await page.evaluate(() => window.scrollY)) < 50);

/* ---------------------------------------------------------- 6. hash nav */

console.log('\nIn-page navigation');
await page.goto(`${BASE}/features`, { waitUntil: 'networkidle2' });
await page.evaluate(() => [...document.querySelectorAll('.footer__links a')]
  .find((a) => a.textContent.includes('How it works')).click());
await new Promise((r) => setTimeout(r, 900));
const y = await page.evaluate(() => {
  const el = document.getElementById('how');
  return el ? Math.abs(el.getBoundingClientRect().top) : -1;
});
ok('a /#hash link lands on its section', y >= 0 && y < 200, `offset ${y}`);

/* -------------------------------------------------------------- 7. form */

console.log('\nContact form');
await page.goto(`${BASE}/contact?topic=console`, { waitUntil: 'networkidle2' });

ok('?topic= preselects the subject',
  (await page.$eval('#topic', (s) => s.value)) === 'console');

/* Submitting empty must not navigate, and must say what is wrong.
   Field validation runs before the bot time-trap, so no wait is needed here —
   that ordering is exactly what this asserts. */
await page.click('#form-submit');
await new Promise((r) => setTimeout(r, 200));

const errs = await page.$$eval('.err', (es) => es.map((e) => e.textContent).filter(Boolean));
ok('an empty form reports errors', errs.length >= 3, `${errs.length} shown`);
ok('the summary is announced',
  await page.$eval('#form-status', (s) => !s.hidden && s.getAttribute('role') === 'status'));
ok('focus moves to the first bad field',
  (await page.evaluate(() => document.activeElement?.id)) === 'name');
ok('bad fields are marked for assistive tech',
  (await page.$eval('#name', (i) => i.getAttribute('aria-invalid'))) === 'true');

/* A wrong mobile number must be caught; 12345 is not an Indian mobile. */
await page.type('#name', 'Ramesh Kumar');
await page.type('#phone', '12345');
await page.$eval('#message', (t) => t.blur());
await page.click('#form-submit');
await new Promise((r) => setTimeout(r, 200));
ok('a bad mobile number is rejected',
  (await page.$eval('#phone-err', (e) => e.textContent)).includes('10-digit'));

/* Fill it properly and intercept the post, so the test never sends a real
   enquiry to the counter. window.open is stubbed too, because a network
   failure is meant to fall back to WhatsApp rather than lose the message. */
await page.evaluate(() => {
  window.__posted = null;
  window.__opened = null;
  window.open = (url) => {
    window.__opened = url;
    return { focus() {} };
  };
  const realFetch = window.fetch;
  window.fetch = (url, opts = {}) => {
    if (opts.method === 'POST') {
      window.__posted = { url: String(url), body: String(opts.body || '') };
      return Promise.resolve(new Response('', { status: 200 }));
    }
    return realFetch(url, opts);
  };
});

await page.$eval('#phone', (i) => {
  i.value = '';
});
await page.type('#phone', '9876543210');
await page.type('#message', 'Please show me the workshop console on real job cards.');
await page.click('#consent');
/* The form refuses anything submitted within 2.5s of loading, as a bot would. */
await new Promise((r) => setTimeout(r, 2700));
await page.click('#form-submit');
await new Promise((r) => setTimeout(r, 400));

const posted = await page.evaluate(() => window.__posted);
ok('a valid form posts the enquiry', !!posted, JSON.stringify(posted));
ok('it posts to the site itself, for Netlify Forms',
  !!posted && new URL(posted.url, BASE).pathname === '/');
ok('it names the form Netlify registered',
  !!posted && posted.body.includes('form-name=enquiry'));

const body = posted ? decodeURIComponent(posted.body.replace(/\+/g, ' ')) : '';
ok('the submission carries the details',
  body.includes('Ramesh Kumar') && body.includes('9876543210') && body.includes('console'));
ok('the trap field is sent, empty, for a real visitor',
  !!posted && /(^|&)bot-field=(&|$)/.test(posted.body));

const statusText = await page.$eval('#form-status', (s) => s.textContent);
ok('the visitor is told it worked', /Thanks, Ramesh/.test(statusText), statusText);
ok('the form is cleared afterwards',
  (await page.$eval('#name', (i) => i.value)) === '');

/* A filled trap field is no longer dropped in the browser. It is sent along so
   Netlify can file the submission as spam server-side. This is the regression
   test for the bug where Chrome autofill filled the old "company" trap for a
   real customer and the form silently did nothing. */
await page.evaluate(() => {
  window.__posted = null;
  window.__opened = null;
  /* Set it the way autofill does: through the native setter plus an input
     event, so React's controlled state actually sees the value. */
  const el = document.getElementById('bot-field');
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, 'spam-bot');
  el.dispatchEvent(new Event('input', { bubbles: true }));
});
await page.type('#name', 'Bot');
await page.type('#phone', '9876543210');
/* The earlier send reset the form, which clears the subject too. */
await page.select('#topic', 'other');
await page.type('#message', 'buy cheap watches from this website today');
await page.click('#consent');
await new Promise((r) => setTimeout(r, 2700));
await page.click('#form-submit');
await new Promise((r) => setTimeout(r, 400));

const botStatus = await page.$eval('#form-status', (s) => s.textContent);
console.log(`       (page said: "${botStatus}")`);
const botPost = await page.evaluate(() => window.__posted);
ok('a filled trap field is still sent, never silently dropped', !!botPost);
ok('it carries the trap value so Netlify can file it as spam',
  !!botPost && /(^|&)bot-field=spam-bot(&|$)/.test(botPost.body));
ok('and the page responds, so nobody is left wondering',
  !(await page.$eval('#form-status', (s) => s.hidden)));

/* Autofill must have no reason to touch the trap. */
const trap = await page.$eval('#bot-field', (el) => ({
  name: el.name,
  label: document.querySelector('label[for="bot-field"]')?.textContent || '',
  ac: el.getAttribute('autocomplete'),
}));
ok('the trap is not named or labelled like a real address field',
  !/company|organi[sz]ation|business|firm|name$|email|phone|address/i.test(`${trap.name} ${trap.label}`)
    && trap.ac === 'off',
  JSON.stringify(trap));

/* --------------------------------------------------------- 8. keyboard */

console.log('\nKeyboard');
await page.goto(BASE, { waitUntil: 'networkidle2' });
await page.keyboard.press('Tab');
const firstStop = await page.evaluate(() => ({
  cls: document.activeElement?.className,
  text: document.activeElement?.textContent,
}));
ok('the first tab stop is the skip link',
  String(firstStop.cls).includes('skip-link'), JSON.stringify(firstStop));

await browser.close();

console.log(`\n${pass} passed, ${fails.length} failed`);
if (fails.length) {
  console.log('\nFailures:');
  fails.forEach((f) => console.log(` - ${f}`));
  process.exit(1);
}
