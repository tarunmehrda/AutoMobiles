# Balaji Automobiles — website

The public site for the two apps: **Balaji Car** (customers) and **Balaji Garage**
(the workshop console). Its whole job is to get the right app onto the right
phone, so every page ends in a download or a way to reach the counter.

React 19 + Vite. No CSS framework, no UI library, no analytics, no cookies.

```
npm install
npm run dev        # http://127.0.0.1:5173
npm run build      # -> dist/
npm run preview    # serves dist/ on http://127.0.0.1:4173
npm run check      # 47 functional tests against the preview server
npm run shots      # full-page screenshots of every route, both themes
```

---

## Where to change things

Almost everything a rebrand or a re-point needs is in **`src/lib/site.js`**:
contact numbers, the email, the Play Store URLs, the navigation and the contact
form's subject list. Those values mirror `User/lib/config/brand.dart` and
`Admin/lib/config/brand.dart` — if they change in the apps, change them here too.

| I want to change… | Edit |
|---|---|
| Phone, WhatsApp, email, address | `src/lib/site.js` → `SUPPORT` |
| Play Store / App Store links | `src/lib/site.js` → `STORE` |
| Navigation | `src/lib/site.js` → `NAV` |
| Contact form subjects | `src/lib/site.js` → `TOPICS` |
| Colours, spacing, type | `src/styles/site.css` → section 1, *Tokens* |
| Landing page copy | `src/pages/Home.jsx` (content is in arrays at the top) |
| Feature detail | `src/pages/Features.jsx` |
| Social preview image | `public/assets/img/og-cover.jpg` |

### Before launch

Three things are placeholders and should be filled in:

1. **`SUPPORT.address`** in `src/lib/site.js` — the workshop's real street address.
   It shows on the contact page and feeds the "Open in Maps" link.
2. **Social links** in `src/lib/site.js` → `SOCIAL` — Instagram and Facebook
   currently point at the sites' home pages.
3. **The app screenshots** in `public/assets/img/app/` were captured against a
   test workshop profile, so a few of them show a placeholder address in small
   print. Re-capture them once the real garage profile is set up.

The Play Store URLs are already correct for the two package names
(`com.balajiautomobiles.customer` and `…garage`) and will work the moment the
listings go live. iOS is not shipped: `STORE.*.ios` is `null`, which renders the
badge as a non-clickable "Coming soon to App Store" rather than a dead link.
Set the URL and the badge becomes a real link with no other change.

---

## The contact form

`FORM_ENDPOINT` at the top of `src/pages/Contact.jsx` is empty, and while it is
empty a valid submission opens WhatsApp with the message already written —
which is how the counter actually answers, and needs no backend at all.

Point it at an HTTPS collector (Formspree, Web3Forms, a Worker of your own) and
the same form POSTs JSON there instead. Nothing else changes; the note under the
button switches wording on its own.

Either way the form validates before it sends, marks bad fields with
`aria-invalid`, moves focus to the first one, and carries two quiet bot checks:
a field no human can see, and a rejection of any complete form filled in under
two and a half seconds.

---

## Deploying

The build is static. `dist/` can go on Cloudflare Pages, Netlify, Vercel, or any
web server.

- Build command `npm run build`, output directory `dist`.
- **`public/_redirects`** sends every unknown path to `index.html` so client-side
  routing works on a hard refresh. On a host that ignores it — Nginx, Apache,
  S3 — configure the same single-page fallback yourself, or `/features` will
  404 when somebody reloads it.
- **`public/_headers`** carries the Content-Security-Policy, HSTS, `nosniff`,
  a referrer policy, a permissions policy and immutable caching for hashed
  assets. Cloudflare Pages and Netlify read this file; other hosts need the same
  headers set their own way.

The CSP is deliberately tight: scripts only from this origin, no inline scripts,
no `eval`, styles from here and Google Fonts, images from here, and the page may
not be framed. It is set as a header rather than a `<meta>` tag so it does not
fight Vite's dev server.

---

## How it is put together

```
index.html            static shell: Open Graph, fonts, the pre-paint theme script
public/
  theme-init.js       sets light/dark before the first paint, so it never flashes
  _headers            security headers and cache policy
  _redirects          SPA fallback
  assets/img/app/     real screenshots from both apps, cropped and WebP
src/
  lib/site.js         the config everything else reads
  hooks/useTheme.js   light/dark, remembered, following the OS until you choose
  hooks/useMeta.js    per-route title, description and canonical
  components/         Header, Footer, Icon + sprite, Reveal, Phone, StoreBadge…
  pages/              Home, Features, Contact, Privacy, Terms, NotFound
  styles/site.css     the whole design system, numbered by section
tools/
  check.mjs           functional tests — links, theme, drawer, FAQ, form
  shoot.mjs           screenshots + broken-image and overflow audit
```

A few decisions worth knowing about:

**Open Graph is in `index.html`, not in React.** WhatsApp and Facebook do not run
JavaScript, so tags set from a component would never reach them. The site-wide
card is static; `useMeta()` updates the title and description in the browser for
people and for Google.

**The theme is set before React loads.** `public/theme-init.js` is a
render-blocking script in `<head>`. Anything later and a visitor on dark mode
gets a white flash on every page load.

**The design comes from the apps.** The palette, radii and the tinted card
colours in `src/styles/site.css` are the same values as the Flutter theme, and
the screenshots are the real product rather than mockups — the site and the
thing it is selling should look like one product.

**There are no testimonials or customer counts on this site.** Not because they
would not help, but because we do not have real ones yet, and inventing them is
how a site stops being trustworthy.

---

## Testing

`npm run check` needs a preview server running and drives a real Chrome. It
covers every link on every page, both themes and the reload that persists them,
the mobile drawer (open, Escape, outside click, scroll lock), the FAQ accordion,
back-to-top, `/#hash` navigation, and the contact form end to end — empty
submission, a bad mobile number, a valid hand-off to WhatsApp, and the honeypot.
It exits non-zero on failure, so it can gate a deploy.

`npm run shots` writes a full-page screenshot of every route at 390 px and
1440 px in both themes, and reports any console error, failed request, image
that did not load, or page that scrolls sideways.

If Chrome is somewhere else, set `CHROME_PATH`.
