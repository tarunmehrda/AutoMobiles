import { Link } from 'react-router-dom';
import Icon from './Icon.jsx';
import { SITE, SOCIAL, STORE, SUPPORT, asset } from '../lib/site.js';

const PRODUCT = [
  { label: 'All features', to: '/features' },
  { label: 'For customers', to: '/features#customer' },
  { label: 'For workshops', to: '/features#workshop' },
  { label: 'How it works', to: '/#how' },
  { label: 'Security', to: '/#security' },
];

export default function Footer() {
  return (
    <footer className="footer">
      <div className="wrap">
        <div className="footer__grid">
          <div className="footer__about">
            <Link className="brand" to="/" aria-label={`${SITE.name}, home`}>
              <img src={asset('/assets/img/brand/logo-badge.png')} alt="" width="34" height="34" />
              <span>
                {SITE.name}
                <small>{SITE.tagline}</small>
              </span>
            </Link>
            <p>
              A workshop that keeps its records where you can read them. Two apps, one job
              card, no paper.
            </p>
            <div className="socials">
              {SOCIAL.map((s) => (
                <a
                  key={s.label}
                  href={s.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={`${s.label} (opens in a new tab)`}
                >
                  <Icon name={s.icon} size={18} />
                </a>
              ))}
            </div>
          </div>

          <div>
            <h4>Product</h4>
            <ul className="footer__links">
              {PRODUCT.map((l) => (
                <li key={l.to}>
                  <Link to={l.to}>{l.label}</Link>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <h4>Get the app</h4>
            <ul className="footer__links">
              <li>
                <a href={STORE.customer.android} target="_blank" rel="noopener noreferrer">
                  {STORE.customer.name} for Android
                </a>
              </li>
              <li>
                <a href={STORE.garage.android} target="_blank" rel="noopener noreferrer">
                  {STORE.garage.name} for Android
                </a>
              </li>
              <li>
                <Link to="/contact?topic=ios">Tell me when iOS lands</Link>
              </li>
              <li>
                <Link to="/contact?topic=console">Book a console demo</Link>
              </li>
            </ul>
          </div>

          <div>
            <h4>Talk to us</h4>
            <ul className="footer__links">
              <li>
                <a href={SUPPORT.phoneHref}>{SUPPORT.phone}</a>
              </li>
              <li>
                <a href={SUPPORT.whatsappHref} target="_blank" rel="noopener noreferrer">
                  WhatsApp
                </a>
              </li>
              <li>
                <a href={SUPPORT.emailHref}>{SUPPORT.email}</a>
              </li>
              <li>
                <Link to="/contact">Send an enquiry</Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="footer__bottom">
          <p>
            &copy; {new Date().getFullYear()} {SITE.name}. Built by {SITE.vendor}.
          </p>
          <nav aria-label="Legal">
            <Link to="/privacy">Privacy</Link>
            <Link to="/terms">Terms</Link>
            <Link to="/contact">Contact</Link>
          </nav>
        </div>
      </div>
    </footer>
  );
}
