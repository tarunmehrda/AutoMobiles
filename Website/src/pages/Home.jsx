import { Link } from 'react-router-dom';
import Icon from '../components/Icon.jsx';
import Phone from '../components/Phone.jsx';
import PhoneStage from '../components/PhoneStage.jsx';
import Reveal from '../components/Reveal.jsx';
import StoreBadge from '../components/StoreBadge.jsx';
import useMeta from '../hooks/useMeta.js';
import { STORE, SUPPORT, asset } from '../lib/site.js';

const MARKS = [
  {
    icon: 'i-check',
    title: 'Free for customers',
    body: 'No subscription and no charge. You pay for the work on the car, nothing else.',
  },
  {
    icon: 'i-offline',
    title: 'Works without signal',
    body: 'Book from a basement car park. It saves on the phone and syncs when you surface.',
  },
  {
    icon: 'i-bill',
    title: 'The bill you were quoted',
    body: 'A GST invoice or a plain bill, itemised, and approved by you before anything is spent.',
  },
  {
    icon: 'i-lock',
    title: 'Your records stay yours',
    body: 'Locked at the database, not just in the app. We do not sell or share any of it.',
  },
];

const CUSTOMER_FEATURES = [
  {
    icon: 'i-cal',
    title: 'Book without ringing up',
    body: 'Pick the car, the workshop, the services and a slot. Four steps, and the counter sees it the moment you finish.',
  },
  {
    icon: 'i-wrench',
    title: 'Watch the work',
    body: 'The job card updates as the car moves through the bay. Parts on order, work under way, ready for pickup.',
  },
  {
    icon: 'i-bill',
    title: 'Approve before it is spent',
    body: 'The estimate arrives itemised. Approve it, query a line, or ask for a revision. Nothing is done until you say so.',
  },
  {
    icon: 'i-pay',
    title: 'Pay from the app',
    body: 'Settle the balance by UPI when the work is done. Every invoice stays in the app, the same document the workshop printed.',
  },
  {
    icon: 'i-bell',
    title: 'Reminders that matter',
    body: 'Next service by date or by kilometres, insurance expiry and PUC. All flagged before they lapse, not after.',
  },
  {
    icon: 'i-car',
    title: 'Every car you own',
    body: 'Add the whole family’s vehicles. Full service history per car with the bills attached, which is worth real money at resale.',
  },
];

const STEPS = [
  {
    title: 'Add your car once',
    body: (
      <>
        Sign in with your mobile number and an OTP. Type the registration number,{' '}
        <span className="plate">RJ18CC1390</span>, and the app fills in the make and model.
        Nothing else is asked for.
      </>
    ),
    points: [
      'Mobile and OTP, no password to forget',
      'More than one car on the same login',
      'Odometer and a photo, if you want them',
    ],
    shot: asset('/assets/img/app/u_home2.webp'),
    alt: 'My Garage in the Balaji Car app, listing a Maruti Suzuki Alto K10 on RJ18CC1390 at 60,000 km, with its service three days overdue.',
  },
  {
    title: 'See what it will cost',
    body: 'Open the workshop and every service it offers is there with a price and a time against it, before you commit to anything and without ringing up to ask.',
    points: [
      'A price and a rough duration per service',
      'The workshop’s address and phone, one tap away',
      'Book straight from the same screen',
    ],
    shot: asset('/assets/img/app/u_services.webp'),
    alt: 'Workshop details for Balaji, showing a Full Service of oil and filters at ₹1,499 and about 60 minutes, with a Book Service button.',
  },
  {
    title: 'Book the slot',
    body: 'Four steps run across the top: vehicle, workshop, services, details. The step you are on is the only one on screen. Pick a date, pick a time, and say whether you are bringing it in or want it collected.',
    points: [
      'Direct visit, or pick up and drop back',
      'Real time slots, not "we will call you"',
      'The counter gets it instantly; no call needed',
    ],
    shot: asset('/assets/img/app/u_book4.webp'),
    alt: 'The last step of booking: direct visit or pick and drop, a date of 19 September 2026, a 10:00 am slot selected, and Confirm Booking.',
  },
  {
    title: 'Follow it, then keep the bill',
    body: 'Every booking sits in one list with its stage and its estimate. When the work is done, pay the balance by UPI or at the counter. The invoice stays under Jobcard History, the same PDF the workshop printed.',
    points: [
      'Approve or query the estimate before work starts',
      'Open, In Progress, Waiting for Parts, Ready',
      'GST bill or a plain bill, whichever applies',
      'Every past invoice stays, per car',
    ],
    shot: asset('/assets/img/app/u_booked.webp'),
    alt: 'My Bookings, with a Full Service scheduled for 19 September against a ₹1,769 estimate, and a Jobcard History tab alongside.',
  },
];

const CONSOLE_TILES = [
  { icon: 'i-bill', title: 'Job cards', body: 'One screen, not a four-step wizard. Found by name, mobile or plate.' },
  { icon: 'i-box', title: 'Parts & stock', body: 'Purchase entry, barcode scan, low-stock alerts, rack locations.' },
  { icon: 'i-chart', title: 'Money', body: 'Day book, expenses, receivables ageing, and profit if your role may see it.' },
  { icon: 'i-users', title: 'Staff', body: 'Five roles, attendance, payroll. A mechanic sees only his own cards.' },
];

const CONSOLE_SHOTS = [
  { src: asset('/assets/img/app/home_grid.webp'), alt: 'The Balaji Garage console home screen: three cars on the floor, one ready to go, ₹10,000 owed on an open invoice, and tiles for inventory, reports, analytics, staff and appointments.' },
  { src: asset('/assets/img/app/bill_ready.webp'), alt: 'The last step of a new job card: ₹2,325 quoted with a ₹500 advance and ₹1,825 balance, the mechanic on the floor, the promised delivery date and a note for the floor.' },
  { src: asset('/assets/img/app/a_revenue.webp'), alt: 'Revenue analytics for the last 30 days: ₹12,325 billed, ₹2,325 collected, ₹10,000 still owed, and a breakdown of where the money came from.' },
  { src: asset('/assets/img/app/a_reports.webp'), alt: 'The share sheet for a closed job card, offering a GST tax invoice or a simple bill and sending it by WhatsApp, email, print or PDF.' },
];

const SECURITY = [
  {
    icon: 'i-lock',
    title: 'Locked at the database',
    body: 'Every read and write passes row-level security in Postgres. A request for somebody else’s invoice returns nothing, whatever the app asks for.',
  },
  {
    icon: 'i-key',
    title: 'Passwords are never stored',
    body: 'Staff sign-in uses a salted hash. Two people who pick the same password get different hashes, and the password itself is never written down anywhere.',
  },
  {
    icon: 'i-shield',
    title: 'Checked three times',
    body: 'A screen you have no business on is refused by the router, refused again by the screen, and refused a third time by Postgres. The third one is the one that counts.',
  },
  {
    icon: 'i-users',
    title: 'Nobody sees everything',
    body: 'Five roles with a permission grid per module. A mechanic sees the cards assigned to him and no cost price; an accountant sees ledgers and not the workshop floor.',
  },
  {
    icon: 'i-clock',
    title: 'Every action is signed',
    body: 'Whoever is signed in is named on every line of the activity log. The log is append-only. There is no policy in the database that lets anyone edit or delete it.',
  },
  {
    icon: 'i-offline',
    title: 'No shipped test logins',
    body: 'The apps ship with no seeded accounts and no default password, deliberately. The first person to open the console creates the first user.',
  },
];

const FAQ = [
  {
    q: 'Does the app cost anything?',
    a: <p>No. Balaji Car is free for our customers, and it stays free. You pay for the work on your car and nothing else.</p>,
  },
  {
    q: 'Do I need an account before I can book?',
    a: <p>You sign in with your mobile number and a one-time code. There is no password to choose and no form to fill. Your name and car are added on the way to the first booking.</p>,
  },
  {
    q: 'What happens where there is no signal?',
    a: <p>Both apps work offline. Whatever you do is saved on the device and syncs the next time there is a connection, so a booking made in a basement car park still reaches us.</p>,
  },
  {
    q: 'Will I get a GST invoice?',
    a: <p>If you need one, yes. It carries HSN and SAC codes per line, CGST and SGST within the state or IGST across a state line, worked out from your state code and frozen onto the document when it is raised. If you do not need one you get a plain bill with no tax column anywhere.</p>,
  },
  {
    q: 'Is the iPhone version coming?',
    a: (
      <p>
        It is being built. Android is live first because that is what most of our customers
        carry. If you are on iPhone,{' '}
        <Link className="tlink" to="/contact?topic=ios">tell us</Link> and we will let you
        know the day it lands.
      </p>
    ),
  },
  {
    q: 'I run a workshop. Can I use the console?',
    a: (
      <p>
        Yes. Balaji Garage can be set up for another workshop under its own name and colours.{' '}
        <Link className="tlink" to="/contact?topic=console">Ask for a walkthrough</Link> and
        we will show you it running on real job cards.
      </p>
    ),
  },
];

export default function Home() {
  useMeta({
    description:
      'Book a car service, watch the work happen and pay the bill from your phone. Balaji Automobiles runs two free apps: Balaji Car for customers, and the Balaji Garage console for the workshop.',
    path: '/',
  });

  return (
    <>
      {/* ---------------------------------------------------------- Hero */}
      <section className="hero">
        <div className="hero__grid" aria-hidden="true" />
        <div className="hero__glow" aria-hidden="true" />

        <div className="wrap hero__inner">
          <div className="hero__copy">
            <p className="eyebrow">Two free apps · One workshop</p>
            <h1>
              Your car.
              <br />
              <em>Our care.</em>
            </h1>
            <p className="lede">
              Book a service, watch the work happen and pay the bill, all from your phone. The
              job card your mechanic fills in is the same one you are reading, updating as
              the car moves through the bay.
            </p>

            <div className="btn-row">
              <Link className="btn btn--primary" to="/#download">
                Get the app
                <Icon name="i-arrow" size={18} className="arrow" />
              </Link>
              <Link className="btn btn--ghost" to="/#how">
                See how it works
              </Link>
            </div>
          </div>

          <Reveal>
            <PhoneStage
              back={{
                src: asset('/assets/img/app/u_book4.webp'),
                alt: 'Booking an appointment in the Balaji Car app: pick and drop, a date and a time slot, with Confirm Booking.',
              }}
              front={{
                src: asset('/assets/img/app/u_home2.webp'),
                alt: 'The Balaji Car home screen, listing a Maruti Suzuki Alto K10 on RJ18CC1390 with its next service overdue by three days.',
              }}
            />
          </Reveal>
        </div>
      </section>

      {/* --------------------------------------------------------- Marks */}
      <section className="section section--tight">
        <div className="wrap">
          <Reveal as="ul" className="marks">
            {MARKS.map((m) => (
              <li key={m.title}>
                <span className="tile">
                  <Icon name={m.icon} size={19} />
                </span>
                <b>{m.title}</b>
                <span className="marks__body">{m.body}</span>
              </li>
            ))}
          </Reveal>
        </div>
      </section>

      {/* ------------------------------------------------------ Download */}
      <section className="section" id="download">
        <div className="wrap">
          <div className="section-head section-head--center">
            <p className="eyebrow">Download</p>
            <h2>Two apps. One workshop.</h2>
            <p className="lede">
              One is for the person whose car it is. The other is for the people working on
              it. They talk to each other, so nobody has to ring up and ask.
            </p>
          </div>

          <div className="grid apps">
            <Reveal as="article" className="app-card">
              <div className="app-card__top">
                <img src={asset('/assets/img/brand/logo-badge.png')} alt="" width="54" height="54" />
                <div>
                  <span className="app-card__for">For customers</span>
                  <span className="app-card__name">{STORE.customer.name}</span>
                </div>
              </div>
              <p>
                Your garage in your pocket. Add your car once, and every service, bill and
                reminder after that lands here.
              </p>
              <ul className="app-card__list">
                <li>Book a slot in four steps</li>
                <li>Watch the job card move from Open to Ready</li>
                <li>Approve or query the estimate before work starts</li>
                <li>Pay the balance by UPI, keep every invoice</li>
                <li>Service and insurance reminders before they lapse</li>
              </ul>
              <div className="app-card__cta">
                <StoreBadge store="android" href={STORE.customer.android} invert
                  label="Balaji Car on Google Play (opens in a new tab)" />
                <StoreBadge store="ios" href={STORE.customer.ios} />
              </div>
            </Reveal>

            <Reveal as="article" className="app-card app-card--dark" delay={1}>
              <div className="app-card__top">
                <img src={asset('/assets/img/brand/logo-badge.png')} alt="" width="54" height="54" />
                <div>
                  <span className="app-card__for">For the workshop</span>
                  <span className="app-card__name">{STORE.garage.name}</span>
                </div>
              </div>
              <p>
                The console the counter and the floor run on. Job cards, parts, staff and
                money, on the phone in the bay and on the desktop at the counter.
              </p>
              <ul className="app-card__list">
                <li>Job card from a registration number in two taps</li>
                <li>Kanban board: Open, In Progress, Ready, Delivered</li>
                <li>Counter sale, stock, purchase entry, barcode scan</li>
                <li>GST or plain bills, in six invoice designs</li>
                <li>Five staff roles, each seeing only their own work</li>
              </ul>
              <div className="app-card__cta">
                <StoreBadge store="android" href={STORE.garage.android} invert
                  label="Balaji Garage on Google Play (opens in a new tab)" />
                <Link className="btn btn--ghost btn--block" to="/contact?topic=console">
                  Ask for a console walkthrough
                </Link>
              </div>
            </Reveal>
          </div>
        </div>
      </section>

      {/* ------------------------------------------------------ Features */}
      <section className="section section--alt" id="features">
        <div className="wrap">
          <div className="section-head">
            <p className="eyebrow">What you get</p>
            <h2>Everything that used to be a phone call.</h2>
            <p className="lede">
              Six things the app does that a WhatsApp message and a paper slip never could.
            </p>
          </div>

          <div className="grid cards-3">
            {CUSTOMER_FEATURES.map((f, i) => (
              <Reveal as="article" className="card card--lift" key={f.title} delay={i % 3}>
                <span className="tile">
                  <Icon name={f.icon} size={22} />
                </span>
                <h3>{f.title}</h3>
                <p>{f.body}</p>
              </Reveal>
            ))}
          </div>

          <div className="btn-row u-mt-lg">
            <Link className="btn btn--ghost" to="/features">
              See every feature, step by step
              <Icon name="i-arrow" size={18} className="arrow" />
            </Link>
          </div>
        </div>
      </section>

      {/* --------------------------------------------------- How it works */}
      <section className="section" id="how">
        <div className="wrap">
          <div className="section-head section-head--center">
            <p className="eyebrow">How it works</p>
            <h2>From booking to bill, in four moves.</h2>
            <p className="lede">No account forms, no back and forth. Here is the whole thing.</p>
          </div>

          <div className="steps">
            {STEPS.map((s) => (
              <Reveal as="article" className="step" key={s.title}>
                <div className="step__body">
                  <span className="step__n" aria-hidden="true" />
                  <h3>{s.title}</h3>
                  <p>{s.body}</p>
                  <ul className="step__list">
                    {s.points.map((p) => (
                      <li key={p}>{p}</li>
                    ))}
                  </ul>
                </div>
                <div className="step__shot">
                  <Phone src={s.shot} alt={s.alt} />
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ------------------------------------------------------- Console */}
      <section className="section section--alt" id="workshop">
        <div className="wrap stack-lg">
          <div className="section-head section-head--flush">
            <p className="eyebrow">For the workshop</p>
            <h2>The console the floor actually runs on.</h2>
            <p className="lede">
              Balaji Garage replaces the register, the parts diary and the bill book. It runs
              on the phone in the bay and on Windows at the counter, on the same data.
            </p>
          </div>

          <div className="grid cards-4">
            {CONSOLE_TILES.map((t, i) => (
              <Reveal as="article" className="card card--lift" key={t.title} delay={i}>
                <span className="tile">
                  <Icon name={t.icon} size={22} />
                </span>
                <h4>{t.title}</h4>
                <p>{t.body}</p>
              </Reveal>
            ))}
          </div>

          <div className="shots-row">
            {CONSOLE_SHOTS.map((s, i) => (
              <Reveal key={s.src} delay={i}>
                <Phone src={s.src} alt={s.alt} />
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* ------------------------------------------------------ Security */}
      <section className="section" id="security">
        <div className="wrap">
          <div className="slab">
            <div className="section-head">
              <p className="eyebrow">Your data</p>
              <h2>Built so a leak is hard, not so it looks safe.</h2>
              <p className="lede">
                Your service history says where your car is and what it is worth. We treat it
                that way.
              </p>
            </div>

            <ul className="sec-list">
              {SECURITY.map((s) => (
                <li key={s.title}>
                  <h4>
                    <Icon name={s.icon} size={19} />
                    {s.title}
                  </h4>
                  <p>{s.body}</p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      {/* ----------------------------------------------------------- FAQ */}
      <section className="section section--alt" id="faq">
        <div className="wrap">
          <div className="section-head section-head--center">
            <p className="eyebrow">Questions</p>
            <h2>Asked often enough to put here.</h2>
          </div>

          <div className="faq">
            {FAQ.map((item) => (
              <details key={item.q} name="home-faq">
                <summary>{item.q}</summary>
                <div className="faq__a">{item.a}</div>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ------------------------------------------------------ CTA band */}
      <section className="section">
        <div className="wrap">
          <Reveal className="cta-band">
            <h2>Put your garage in your pocket.</h2>
            <p>
              Add your car in a minute. Book the next service before you forget about it
              again.
            </p>

            <div className="btn-row">
              <StoreBadge store="android" href={STORE.customer.android}
                label="Balaji Car on Google Play (opens in a new tab)" />
              <StoreBadge store="ios" href={STORE.customer.ios} />
              <a
                className="btn btn--dark"
                href={SUPPORT.whatsappHref}
                target="_blank"
                rel="noopener noreferrer"
              >
                <Icon name="i-wa" size={18} />
                WhatsApp us
              </a>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
