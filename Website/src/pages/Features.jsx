import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Icon from '../components/Icon.jsx';
import Phone from '../components/Phone.jsx';
import Reveal from '../components/Reveal.jsx';
import StoreBadge from '../components/StoreBadge.jsx';
import useMeta from '../hooks/useMeta.js';
import { STORE, asset } from '../lib/site.js';

/* ---------------------------------------------------------------- content */

const CUSTOMER_STEPS = [
  {
    title: 'Sign in with your number',
    body: 'Open the app and type your mobile number. A six-digit code arrives; type it in and you are through. No password to choose, none to forget, and nothing to reset at eleven at night.',
    points: [
      'Mobile and OTP, and that is the whole sign-in',
      'Your name and email are asked for once, afterwards',
      'The same login works on a new phone; nothing is lost',
    ],
    shot: asset('/assets/img/app/u_profile.webp'),
    alt: 'The profile screen in the Balaji Car app, holding the account details and app settings.',
  },
  {
    title: 'Add the car',
    body: 'Type the registration number and the app fills in what it can. A hatchback, a sedan or a bike: the category decides which fields you even see. Everything past the plate is optional and can wait.',
    points: [
      'Registration number is the only thing required',
      'Make, model, fuel, year, colour and VIN if you want them',
      'Insurance and PUC expiry dates, so the app can warn you',
      'Add as many vehicles as the household has',
    ],
    shot: asset('/assets/img/app/u_home2.webp'),
    alt: 'My Garage listing a Maruti Suzuki Alto K10 on RJ18CC1390 at 60,000 km, with its next service three days overdue.',
  },
  {
    title: 'See the workshop and its prices',
    body: 'Every service the workshop publishes is listed with a price and a rough duration, alongside its address and phone number. You know the cost before you commit to the slot.',
    points: [
      'A price and a time against each service',
      'Address and phone, one tap away',
      'Book straight from the same sheet',
    ],
    shot: asset('/assets/img/app/u_services.webp'),
    alt: 'Workshop details for Balaji, showing a Full Service of oil and filters at ₹1,499 and about 60 minutes, with a Book Service button.',
  },
  {
    title: 'Book in four steps',
    body: 'A progress bar across the top shows exactly where you are: vehicle, workshop, services, details. One step is on screen at a time, with Back and Next at the bottom, so there is nothing to scroll past.',
    points: [
      'Step 1, pick which of your vehicles is going in',
      'Step 2, pick the workshop',
      'Step 3, tick services from the published list or describe the problem',
      'Step 4, pick a date and a slot',
      'The counter sees the request the moment you finish',
    ],
    shot: asset('/assets/img/app/u_book2.webp'),
    alt: 'Step two of the booking flow, choosing Balaji as the workshop, with Back and Next at the bottom.',
  },
  {
    title: 'Pick the slot, or ask us to collect it',
    body: 'Real time slots, not a promise to call you back. Say whether you are bringing the car in or want it picked up, add anything the workshop should know, and confirm.',
    points: [
      'Direct visit, or pick up and drop back',
      'Actual times to choose from, hour by hour',
      'A free-text note for anything unusual',
      'Confirmation on the spot',
    ],
    shot: asset('/assets/img/app/u_book4.webp'),
    alt: 'The last step of booking: direct visit or pick and drop, a date of 19 September 2026, a 10:00 am slot selected, and Confirm Booking.',
  },
  {
    title: 'Approve, follow, pay, and keep the paperwork',
    body: 'Every booking sits in one list with its stage and its estimate. The estimate comes back itemised and nothing is fitted until you approve it. When the work is done, pay by UPI or at the counter. The invoice stays under Jobcard History.',
    points: [
      'Approve the estimate, query a line, or ask for a revision',
      'Open, In Progress, Waiting for Parts, Ready, Delivered',
      'Photos the workshop takes of the car and the worn parts',
      'UPI from the app, or cash and card at the counter',
      'A GST invoice with HSN and SAC where it applies, a plain bill where it does not',
      'Every past invoice kept, filed per car',
    ],
    shot: asset('/assets/img/app/u_booked.webp'),
    alt: 'My Bookings, with a Full Service scheduled for 19 September against a ₹1,769 estimate, and a Jobcard History tab alongside.',
  },
];

const CUSTOMER_SPECS = [
  {
    icon: 'i-car',
    title: 'Your vehicles',
    items: [
      'Every car, bike, truck or tractor on one login',
      'Full service history per vehicle with the bills attached',
      'Running kilometres, updated at each service',
      'Photos from every visit kept against the card',
      'Insurance and PUC expiry tracked per vehicle',
    ],
  },
  {
    icon: 'i-bell',
    title: 'Reminders',
    items: [
      'Next service by date or by kilometres, whichever comes first',
      'Insurance renewal before the policy lapses',
      'PUC expiry, flagged early',
      'Offers the workshop publishes, if you want them',
      'A notification the moment the car is ready for pickup',
    ],
  },
  {
    icon: 'i-chat',
    title: 'Talking to the workshop',
    items: [
      'A message thread against each job card',
      'Query a line on the estimate without a phone call',
      'Request pickup and drop with the booking',
      'Raise a support ticket and follow it',
      'Rate the work afterwards',
    ],
  },
  {
    icon: 'i-bill',
    title: 'Money and documents',
    items: [
      'Itemised estimate before any work starts',
      'UPI payment from inside the app',
      'Advance, balance and outstanding shown plainly',
      'GST invoice with HSN and SAC per line where it applies',
      'Every invoice downloadable as the original PDF',
    ],
  },
];

const MODULES = [
  {
    name: 'Job cards',
    what: 'Open a card from a registration number, a name or a mobile. One screen with four sections instead of a four-step wizard.',
    detail: 'Complaints picker, voice complaint, per-line labour and parts, assigned mechanic, fuel level, photo gallery, and a sticky total that is visible while you are still adding lines.',
  },
  {
    name: 'Kanban board',
    what: 'The same job cards as a drag-and-drop board.',
    detail: 'Open, In Progress, Waiting for Parts, Ready, Delivered. Drag a card across and the customer sees the change.',
  },
  {
    name: 'Counter sale',
    what: 'Over-the-counter parts without opening a job card.',
    detail: 'Camera and USB barcode scan, free quantity, cash-sale party, credit as a payment method, and a 58 or 80 mm thermal receipt beside the A4 PDF. Sale return writes the stock back.',
  },
  {
    name: 'Inventory',
    what: 'Parts, stock levels and where each one sits.',
    detail: 'Purchase entry that creates several part masters off one supplier invoice, min-stock alerts, MRP, rack location, HSN, and a low-stock report.',
  },
  {
    name: 'Invoicing',
    what: 'Six invoice designs, picked once.',
    detail: 'Default, Two Logos, Luxury, Advanced GST (Tally), Billbook and Simple. Preview renders the real PDF against your own latest job card before you commit.',
  },
  {
    name: 'GST',
    what: 'Off by default. On when you need it.',
    detail: 'CGST and SGST inside the state, IGST across a state line, decided from the customer’s state code and frozen onto the document. Inclusive or exclusive pricing, per-line HSN and SAC, round-off as its own row, and an HSN-wise rollup for GSTR-1.',
  },
  {
    name: 'Money',
    what: 'What came in, what went out, what is still owed.',
    detail: 'Daily cash book, expense entry by category, receivables and payables ageing, job-card payments, insurance claims and a ledger.',
  },
  {
    name: 'Staff',
    what: 'Five roles and a permission grid per module.',
    detail: 'View, create, edit and delete, per module, pre-filled from the role and editable afterwards. Attendance, leaves and payroll included.',
  },
  {
    name: 'Reports',
    what: 'Charts you can tap, not decorative sparklines.',
    detail: 'Animated area, bar, donut, horizontal bar, radial gauge and a calendar heat map, over revenue, expenses, services and staff.',
  },
  {
    name: 'Desktop',
    what: 'The same console on Windows.',
    detail: 'A permanent sidebar rail instead of a drawer, multi-pane tables, keyboard shortcuts and USB scanner support, on the same data as the phone.',
  },
];

const ROLES = [
  { name: 'Owner / Admin', body: 'Everything, including purchase rates and profit.' },
  { name: 'Manager', body: 'Operations and billing. No owner settings, no payroll, no profit.' },
  { name: 'Workshop / Mechanic', body: 'Only the job cards assigned to him. Nothing financial, no cost price.' },
  { name: 'Counter / Storekeeper', body: 'Counter sale, stock, parts issue and purchase entry.' },
  { name: 'Accountant', body: 'Invoices, payments, ledgers and reports. Not the workshop floor.' },
];

const TABS = [
  { id: 'customer', label: 'For customers' },
  { id: 'workshop', label: 'For workshops' },
];

/* ------------------------------------------------------------------ page */

export default function Features() {
  const [active, setActive] = useState('customer');

  useMeta({
    title: 'Features',
    description:
      'Every step of the Balaji Car app and the Balaji Garage console, explained plainly: booking, job cards, estimates, UPI payment, GST invoicing, inventory, staff roles and reports.',
    path: '/features',
  });

  /* Light up the jump link for whichever half of the page you are reading. */
  useEffect(() => {
    const targets = TABS.map((t) => document.getElementById(t.id)).filter(Boolean);
    if (!targets.length || !('IntersectionObserver' in window)) return undefined;

    const io = new IntersectionObserver(
      (entries) => {
        const seen = entries.filter((e) => e.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio);
        if (seen[0]) setActive(seen[0].target.id);
      },
      { rootMargin: '-45% 0px -45% 0px', threshold: 0 },
    );

    targets.forEach((t) => io.observe(t));
    return () => io.disconnect();
  }, []);

  return (
    <>
      <section className="page-head">
        <div className="wrap">
          <p className="crumb">
            <Link to="/">Home</Link> · Features
          </p>
          <h1>Every screen, in plain English.</h1>
          <p className="lede u-mt-lg">
            Two apps, and what each one actually does, step by step, in the order you would
            meet them. No feature bullets that turn out to mean nothing.
          </p>

          <nav className="subnav u-mt-lg" aria-label="Jump to a section">
            {TABS.map((t) => (
              <a key={t.id} href={`#${t.id}`} className={active === t.id ? 'is-on' : undefined}>
                {t.label}
              </a>
            ))}
          </nav>
        </div>
      </section>

      {/* ------------------------------------------------- Customer app */}
      <section className="section" id="customer">
        <div className="wrap">
          <div className="section-head">
            <p className="eyebrow">Balaji Car · for customers</p>
            <h2>Six steps, start to finish.</h2>
            <p className="lede">
              From the first time you open the app to the invoice landing in your history.
              This is the whole journey, nothing skipped.
            </p>
          </div>

          <div className="steps">
            {CUSTOMER_STEPS.map((s) => (
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

      <section className="section section--alt">
        <div className="wrap">
          <div className="section-head">
            <p className="eyebrow">The rest of it</p>
            <h2>Everything else the app holds.</h2>
          </div>

          <div className="grid specs">
            {CUSTOMER_SPECS.map((g, i) => (
              <Reveal as="article" className="spec" key={g.title} delay={i}>
                <div className="spec__head">
                  <span className="tile">
                    <Icon name={g.icon} size={20} />
                  </span>
                  <h3>{g.title}</h3>
                </div>
                <ul>
                  {g.items.map((it) => (
                    <li key={it}>
                      <Icon name="i-check" size={13} />
                      {it}
                    </li>
                  ))}
                </ul>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* --------------------------------------------------- Console */}
      <section className="section" id="workshop">
        <div className="wrap stack-lg">
          <div className="section-head section-head--flush">
            <p className="eyebrow">Balaji Garage · for workshops</p>
            <h2>The console, module by module.</h2>
            <p className="lede">
              What the counter, the floor and the owner each get. Ten modules on one set of
              data, on Android and on Windows.
            </p>
          </div>

          <Reveal className="table-scroll">
            <table className="ftable">
              <caption className="visually-hidden">Console modules and what each one covers</caption>
              <thead>
                <tr>
                  <th scope="col">Module</th>
                  <th scope="col">What it is</th>
                  <th scope="col">What is in it</th>
                </tr>
              </thead>
              <tbody>
                {MODULES.map((m) => (
                  <tr key={m.name}>
                    <td>{m.name}</td>
                    <td>{m.what}</td>
                    <td><p>{m.detail}</p></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Reveal>

          <div className="shots-row">
            <Reveal>
              <Phone src={asset('/assets/img/app/home_grid.webp')} alt="The console home screen: three cars on the floor, one ready to go, ₹10,000 owed on an open invoice, and tiles for inventory, reports, analytics, staff and appointments." />
            </Reveal>
            <Reveal delay={1}>
              <Phone src={asset('/assets/img/app/bill_ready.webp')} alt="The last step of a new job card: ₹2,325 quoted with a ₹500 advance and ₹1,825 balance, the mechanic on the floor and the promised delivery date." />
            </Reveal>
            <Reveal delay={2}>
              <Phone src={asset('/assets/img/app/a_revenue.webp')} alt="Revenue analytics for the last 30 days: ₹12,325 billed, ₹2,325 collected, ₹10,000 still owed, and a breakdown of where the money came from." />
            </Reveal>
            <Reveal delay={3}>
              <Phone src={asset('/assets/img/app/a_reports.webp')} alt="The share sheet for a closed job card, offering a GST tax invoice or a simple bill and sending it by WhatsApp, email, print or PDF." />
            </Reveal>
          </div>
        </div>
      </section>

      <section className="section section--alt">
        <div className="wrap">
          <div className="section-head">
            <p className="eyebrow">Who sees what</p>
            <h2>Five roles, and none of them sees everything.</h2>
            <p className="lede">
              Picking a role fills in a permission grid of view, create, edit and delete
              across every module. The grid stays editable for the workshop that wants
              something different.
            </p>
          </div>

          <div className="grid roles">
            {ROLES.map((r, i) => (
              <Reveal as="article" className="role" key={r.name} delay={i}>
                <h4>{r.name}</h4>
                <p>{r.body}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <Reveal className="cta-band">
            <h2>Start with the app.</h2>
            <p>
              Free for customers. If you run a workshop, ask us for a walkthrough on real job
              cards rather than a slide deck.
            </p>
            <div className="btn-row">
              <StoreBadge store="android" href={STORE.customer.android}
                label="Balaji Car on Google Play (opens in a new tab)" />
              <Link className="btn btn--dark" to="/contact?topic=console">
                Book a console demo
                <Icon name="i-arrow" size={18} className="arrow" />
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
