import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

/**
 * A single-page app has to do for itself what the browser does for free:
 * land at the top of a new page, and at the right heading for a #hash.
 */
export default function ScrollManager() {
  const { pathname, hash } = useLocation();

  useEffect(() => {
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const behavior = still ? 'auto' : 'smooth';

    if (!hash) {
      window.scrollTo({ top: 0, behavior: 'auto' });
      return undefined;
    }

    /* The target may be one paint away on a fresh route, so try again next frame. */
    let raf = requestAnimationFrame(() => {
      const el = document.getElementById(hash.slice(1));
      if (el) el.scrollIntoView({ behavior, block: 'start' });
      else window.scrollTo({ top: 0, behavior: 'auto' });
    });

    return () => cancelAnimationFrame(raf);
  }, [pathname, hash]);

  return null;
}
