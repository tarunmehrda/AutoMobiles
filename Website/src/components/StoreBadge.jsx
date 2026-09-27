import Icon from './Icon.jsx';

/**
 * Play and App Store badges.
 *
 * Passing `href={null}` renders the "coming soon" state as a plain span rather
 * than a dead link, so nothing on the page is clickable and then silent — which
 * is the thing people actually complain about.
 */
export default function StoreBadge({ store = 'android', href, invert = false, label }) {
  const android = store === 'android';
  const icon = android ? 'i-play' : 'i-apple';
  const top = href ? 'Get it on' : 'Coming soon to';
  const name = android ? 'Google Play' : 'App Store';

  const classes = ['store-badge', invert && 'store-badge--invert', !href && 'store-badge--soon']
    .filter(Boolean)
    .join(' ');

  const inner = (
    <>
      <Icon name={icon} size={android ? 26 : 24} />
      <span className="store-badge__text">
        <small>{top}</small>
        <strong>{name}</strong>
      </span>
    </>
  );

  if (!href) {
    return (
      <span className={classes} role="note" aria-label={`${name}, coming soon`}>
        {inner}
      </span>
    );
  }

  return (
    <a
      className={classes}
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={label || `${name}: download the app (opens in a new tab)`}
    >
      {inner}
    </a>
  );
}
