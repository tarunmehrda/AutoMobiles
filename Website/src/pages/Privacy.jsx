import { Link } from 'react-router-dom';
import useMeta from '../hooks/useMeta.js';
import { SITE, SUPPORT } from '../lib/site.js';

const UPDATED = '20 September 2026';

export default function Privacy() {
  useMeta({
    title: 'Privacy policy',
    description:
      'What Balaji Automobiles collects through the Balaji Car app, the Balaji Garage console and this website, why, how long it is kept, and how to have it deleted.',
    path: '/privacy',
  });

  return (
    <>
      <section className="page-head">
        <div className="wrap">
          <p className="crumb">
            <Link to="/">Home</Link> · Privacy
          </p>
          <h1>Privacy policy</h1>
          <p className="lede u-mt-lg">
            What we hold, why we hold it, and how to get rid of it. Last updated {UPDATED}.
          </p>
        </div>
      </section>

      <section className="section section--flush-top">
        <div className="wrap prose">
          <p>
            This policy covers the <strong>Balaji Car</strong> app, the{' '}
            <strong>Balaji Garage</strong> console and this website. {SITE.name} is the
            controller of the data described here.
          </p>

          <h2>What we collect</h2>
          <p>Only what the job needs. Nothing is collected to sell on, because we do not sell it.</p>
          <ul>
            <li><strong>Your name and mobile number</strong>, to identify you, to sign you in, and to tell you the car is ready.</li>
            <li><strong>Your email address</strong>, if you give us one, to send invoices and estimates.</li>
            <li><strong>Your vehicles</strong>: registration number, make, model, running kilometres, and insurance and PUC expiry dates, so the app can remind you before they lapse.</li>
            <li><strong>Service records</strong>: job cards, complaints, work done, parts fitted, photographs taken during the work, estimates and invoices.</li>
            <li><strong>Payment records</strong>: what was charged, what was paid and what is outstanding. Card and UPI credentials are handled by the payment provider and never reach us.</li>
            <li><strong>Enquiries</strong> you send through this website or WhatsApp.</li>
          </ul>

          <h2>What we do not do</h2>
          <ul>
            <li>We do not sell, rent or trade your data.</li>
            <li>We do not run advertising trackers, analytics profiling or third-party pixels on this website.</li>
            <li>We do not read your contacts, your photo library or your location in the background.</li>
            <li>We do not store your card number, UPI PIN or bank credentials. We never see them.</li>
          </ul>

          <h2>Why we are allowed to hold it</h2>
          <p>
            For a service you booked, we process your data to perform that contract. For
            reminders and offers, we rely on the consent you gave when you turned them on,
            and you can turn them off in the app at any time. For invoices and tax records,
            we are required by Indian law to keep them.
          </p>

          <h2>Who else sees it</h2>
          <p>
            Our staff, limited by role. A mechanic sees the job cards assigned to him and no
            financial detail; an accountant sees ledgers and not the workshop floor. Beyond
            that, only:
          </p>
          <ul>
            <li>Our hosting and database provider, which stores the data on our behalf.</li>
            <li>The payment provider, when you choose to pay in the app.</li>
            <li>A government authority, where the law requires us to hand something over.</li>
          </ul>

          <h2>How it is protected</h2>
          <ul>
            <li>Every read and write passes row-level security in the database, so a request for another customer's record returns nothing regardless of what the app asks for.</li>
            <li>Staff passwords are stored as salted hashes, never as text.</li>
            <li>Access is checked three times over: by the app's router, by the screen itself, and again by the database.</li>
            <li>Every change is written to an append-only activity log against the name of whoever made it.</li>
            <li>Traffic is encrypted in transit.</li>
          </ul>
          <p>
            No system is perfect. If you believe an account has been misused, tell us at{' '}
            <a href={SUPPORT.emailHref}>{SUPPORT.email}</a> and we will act on it.
          </p>

          <h2>How long we keep it</h2>
          <p>
            Service and invoice records are kept for eight years, which is what Indian tax law
            requires. Enquiries are kept for two years. Everything else is deleted when you
            ask, or when your account has been dormant for three years.
          </p>

          <h2>Your rights</h2>
          <ul>
            <li>Ask for a copy of everything we hold about you.</li>
            <li>Have anything wrong corrected.</li>
            <li>Have your account and its data deleted, except records the law obliges us to keep.</li>
            <li>Withdraw consent for reminders and offers, without losing the service itself.</li>
          </ul>
          <p>
            Write to <a href={SUPPORT.emailHref}>{SUPPORT.email}</a> or call{' '}
            <a href={SUPPORT.phoneHref}>{SUPPORT.phone}</a>. We answer within thirty days.
          </p>

          <h2>This website</h2>
          <p>
            This site sets no cookies and runs no analytics. Your light or dark preference is
            stored in your own browser and never leaves your device. Fonts are served by
            Google Fonts, which will see your IP address as part of serving them. If you use
            the contact form, the details you type are handed to WhatsApp so you can send
            them to us. They are not stored by this website.
          </p>

          <h2>Children</h2>
          <p>
            The apps are not intended for anyone under 18. We do not knowingly collect data
            from children.
          </p>

          <h2>Changes</h2>
          <p>
            If this policy changes in a way that matters, we will say so in the app before the
            change takes effect. The date at the top always reflects the current version.
          </p>

          <h2>Contact</h2>
          <p>
            {SITE.name}
            <br />
            <a href={SUPPORT.emailHref}>{SUPPORT.email}</a>
            <br />
            <a href={SUPPORT.phoneHref}>{SUPPORT.phone}</a>
          </p>
        </div>
      </section>
    </>
  );
}
