import { Link } from 'react-router-dom';
import Icon from '../components/Icon.jsx';
import useMeta from '../hooks/useMeta.js';
import { SUPPORT } from '../lib/site.js';

export default function NotFound() {
  useMeta({
    title: 'Page not found',
    description: 'That page is not here. Try the home page, the features page or just call us.',
  });

  return (
    <section className="section notfound">
      <div className="wrap">
        <p className="notfound__code">404</p>
        <h1>That page is up on blocks.</h1>
        <p className="lede">
          The link is wrong, or the page has moved. Here is the way back.
        </p>
        <div className="btn-row">
          <Link className="btn btn--primary" to="/">
            Home
            <Icon name="i-arrow" size={18} className="arrow" />
          </Link>
          <Link className="btn btn--ghost" to="/features">Features</Link>
          <a className="btn btn--ghost" href={SUPPORT.phoneHref}>Call us</a>
        </div>
      </div>
    </section>
  );
}
