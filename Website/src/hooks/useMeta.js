import { useEffect } from 'react';
import { SITE } from '../lib/site.js';

function set(selector, attr, value) {
  const el = document.head.querySelector(selector);
  if (el) el.setAttribute(attr, value);
}

/**
 * Per-route title, description and canonical.
 *
 * Crawlers that run JavaScript (Google among them) read this. The ones that do
 * not — WhatsApp, Facebook — read the static tags in index.html instead, which
 * is why the site-wide Open Graph card lives there and not here.
 */
export default function useMeta({ title, description, path, noindex = false }) {
  useEffect(() => {
    const full = title ? `${title} | ${SITE.name}` : `${SITE.name} | ${SITE.tagline}`;
    document.title = full;

    // A page that is somebody's private business — a shared job card — must
    // not be indexed. The tag is taken down again on the way out, because
    // this is a single-page app and the next route would otherwise inherit
    // it silently.
    //
    // The `X-Robots-Tag` in public/_headers is what actually holds this
    // line; the tag below is for crawlers that render the page and never
    // saw the header.
    let injected = null;
    if (noindex) {
      injected = document.createElement('meta');
      injected.setAttribute('name', 'robots');
      injected.setAttribute('content', 'noindex, nofollow');
      document.head.appendChild(injected);
    }

    if (description) {
      set('meta[name="description"]', 'content', description);
      set('meta[property="og:description"]', 'content', description);
      set('meta[name="twitter:description"]', 'content', description);
    }

    set('meta[property="og:title"]', 'content', full);
    set('meta[name="twitter:title"]', 'content', full);

    if (path) {
      const url = SITE.origin + path;
      set('link[rel="canonical"]', 'href', url);
      set('meta[property="og:url"]', 'content', url);
    }

    return () => injected?.remove();
  }, [title, description, path, noindex]);
}
