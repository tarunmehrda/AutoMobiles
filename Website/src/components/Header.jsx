import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import Icon from './Icon.jsx';
import useTheme from '../hooks/useTheme.js';
import { NAV, SITE, asset } from '../lib/site.js';

const MOBILE = 900;

export default function Header() {
  const { theme, toggle } = useTheme();
  const { pathname, hash } = useLocation();
  const [open, setOpen] = useState(false);
  const [stuck, setStuck] = useState(false);
  const navRef = useRef(null);
  const toggleRef = useRef(null);

  const close = useCallback(() => setOpen(false), []);

  /* Hairline under the header only once the page has moved. */
  useEffect(() => {
    const onScroll = () => setStuck(window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  /* Any navigation closes the panel — including one to the page you are on. */
  useEffect(close, [pathname, hash, close]);

  /* Escape, a click outside, and growing past the mobile layout all close it. */
  useEffect(() => {
    if (!open) return undefined;

    const onKey = (e) => {
      if (e.key !== 'Escape') return;
      close();
      toggleRef.current?.focus();
    };
    const onClick = (e) => {
      if (navRef.current?.contains(e.target) || toggleRef.current?.contains(e.target)) return;
      close();
    };
    const onResize = () => {
      if (window.innerWidth > MOBILE) close();
    };

    document.addEventListener('keydown', onKey);
    document.addEventListener('click', onClick);
    window.addEventListener('resize', onResize);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('click', onClick);
      window.removeEventListener('resize', onResize);
    };
  }, [open, close]);

  /* The panel covers the page on a phone, so the page behind it must not scroll. */
  useEffect(() => {
    const lock = open && window.innerWidth <= MOBILE;
    document.body.style.overflow = lock ? 'hidden' : '';
    return () => {
      document.body.style.overflow = '';
    };
  }, [open]);

  const current = (to) => (to === pathname || (to !== '/' && pathname.startsWith(to)) ? 'page' : undefined);

  return (
    <header className={`header${stuck ? ' is-stuck' : ''}`}>
      <div className="wrap header__bar">
        <Link className="brand" to="/" aria-label={`${SITE.name}, home`}>
          <img src={asset('/assets/img/brand/logo-badge.png')} alt="" width="34" height="34" />
          <span>
            {SITE.name}
            <small>{SITE.tagline}</small>
          </span>
        </Link>

        <nav
          className={`nav${open ? ' is-open' : ''}`}
          id="site-nav"
          ref={navRef}
          aria-label="Main"
        >
          {NAV.map((item) => (
            <Link key={item.to} to={item.to} aria-current={current(item.to)}>
              {item.label}
            </Link>
          ))}
          <Link className="btn btn--primary nav__cta" to="/#download">
            Get the app
          </Link>
        </nav>

        <div className="header__actions">
          <button
            className="icon-btn theme-toggle"
            type="button"
            onClick={toggle}
            aria-pressed={theme === 'dark'}
            aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            <Icon name="i-sun" size={19} className="sun" />
            <Icon name="i-moon" size={19} className="moon" />
          </button>

          <Link className="btn btn--primary btn--sm btn--nav" to="/#download">
            Get the app
          </Link>

          <button
            className="icon-btn nav-toggle"
            type="button"
            ref={toggleRef}
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-controls="site-nav"
            aria-label={open ? 'Close menu' : 'Open menu'}
          >
            <Icon name={open ? 'i-close' : 'i-menu'} size={20} />
          </button>
        </div>
      </div>
    </header>
  );
}
