import { Link } from 'react-router-dom';
import useMeta from '../hooks/useMeta.js';
import { SITE, SUPPORT } from '../lib/site.js';

const UPDATED = '20 September 2026';

export default function Terms() {
  useMeta({
    title: 'Terms of use',
    description:
      'The terms on which Balaji Automobiles provides the Balaji Car app, the Balaji Garage console and this website.',
    path: '/terms',
  });

  return (
    <>
      <section className="page-head">
        <div className="wrap">
          <p className="crumb">
            <Link to="/">Home</Link> · Terms
          </p>
          <h1>Terms of use</h1>
          <p className="lede u-mt-lg">
            Short, and in plain English. Last updated {UPDATED}.
          </p>
        </div>
      </section>

      <section className="section section--flush-top">
        <div className="wrap prose">
          <p>
            By using the <strong>Balaji Car</strong> app, the <strong>Balaji Garage</strong>{' '}
            console or this website, you agree to what follows. If you do not, please do not
            use them.
          </p>

          <h2>What the apps are</h2>
          <p>
            Balaji Car lets you book a service with us, follow the work and see your bills.
            Balaji Garage is the console our workshop runs on. Both are provided free of
            charge; you pay only for work carried out on your vehicle.
          </p>

          <h2>Your account</h2>
          <ul>
            <li>You sign in with your own mobile number, and the one-time code sent to it is yours alone. Do not pass it on.</li>
            <li>Keep your details accurate. A wrong number means we cannot tell you the car is ready.</li>
            <li>Tell us at once if you think somebody else is using your account.</li>
            <li>Add only vehicles you own or are authorised to manage.</li>
          </ul>

          <h2>Bookings, estimates and work</h2>
          <ul>
            <li>A booking is a request for a slot. It is confirmed when we confirm it.</li>
            <li>An estimate is an estimate. If the work turns out to need more than was quoted, we come back to you before spending it. That is what the approve step is for.</li>
            <li>Work begins only once you have approved the estimate.</li>
            <li>Parts availability and delivery dates are outside our control and may move.</li>
            <li>Warranty on parts is whatever the manufacturer gives. Warranty on our labour is stated on the invoice.</li>
          </ul>

          <h2>Payment</h2>
          <ul>
            <li>Charges are as shown on the approved estimate and the final invoice.</li>
            <li>Payment in the app is handled by a payment provider. Their terms apply to the transaction itself.</li>
            <li>Vehicles are released once the balance is settled, unless credit has been agreed in writing.</li>
            <li>GST is charged where it applies. If it does not apply to you, you receive a plain bill.</li>
          </ul>

          <h2>Fair use</h2>
          <p>You agree not to:</p>
          <ul>
            <li>Reverse-engineer, decompile or tamper with the apps.</li>
            <li>Try to reach data belonging to anyone else.</li>
            <li>Test, probe or overload the service without our written permission.</li>
            <li>Use the apps for anything unlawful.</li>
          </ul>
          <p>
            If you find a security problem, please report it to{' '}
            <a href={SUPPORT.emailHref}>{SUPPORT.email}</a> rather than publishing it. We will
            work with you and we will not pursue anyone who reports in good faith.
          </p>

          <h2>Availability</h2>
          <p>
            We aim to keep the apps running but cannot promise they will never be down. Both
            work offline and sync when a connection returns, so a temporary outage does not
            lose your work.
          </p>

          <h2>Liability</h2>
          <p>
            We are responsible for the work we carry out on your vehicle, as any workshop is.
            We are not liable for indirect or consequential loss arising from use of the
            apps, such as a missed appointment because a notification did not arrive.
            Nothing here limits any liability that cannot lawfully be limited.
          </p>

          <h2>Ending it</h2>
          <p>
            You may delete your account at any time by asking us. We may suspend an account
            that is being used to abuse the service or another person. Your rights over your
            data are set out in the <Link to="/privacy">privacy policy</Link>.
          </p>

          <h2>Governing law</h2>
          <p>
            These terms are governed by the laws of India, and the courts of Rajasthan have
            jurisdiction.
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
