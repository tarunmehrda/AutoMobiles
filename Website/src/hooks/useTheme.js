import { useCallback, useEffect, useState } from 'react';

const KEY = 'ba-theme';

function read() {
  if (typeof document === 'undefined') return 'light';
  return document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
}

/**
 * Light and dark, remembered per visitor.
 *
 * The first paint is already correct — public/theme-init.js runs before React —
 * so this hook only has to keep React in step and handle the toggle.
 */
export default function useTheme() {
  const [theme, setTheme] = useState(read);

  const apply = useCallback((next) => {
    document.documentElement.setAttribute('data-theme', next);
    const meta = document.head.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', next === 'dark' ? '#0B0C0E' : '#F4F5F7');
    setTheme(next);
  }, []);

  const toggle = useCallback(() => {
    const next = read() === 'dark' ? 'light' : 'dark';
    apply(next);
    try {
      localStorage.setItem(KEY, next);
    } catch {
      /* Storage blocked. The choice holds for this page view only. */
    }
  }, [apply]);

  /* Follow the operating system, but only while the visitor has not chosen. */
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = (e) => {
      let chosen = null;
      try {
        chosen = localStorage.getItem(KEY);
      } catch {
        /* ignore */
      }
      if (!chosen) apply(e.matches ? 'dark' : 'light');
    };
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, [apply]);

  return { theme, toggle };
}
