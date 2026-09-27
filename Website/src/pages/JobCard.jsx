import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import useMeta from '../hooks/useMeta.js';
import { STATUS, fetchSharedCard, formatDate, money, totals } from '../lib/backend.js';
import { STORE } from '../lib/site.js';

/**
 * A job card, opened from the link the workshop sent over WhatsApp.
 *
 * No sign-in, no app, no account. The customer taps a link in a message and
 * sees what their car is having done and what it will cost — which is the
 * whole point: most people will never install anything, and a bill they
 * cannot open is a phone call to the counter.
 *
 * It shows what is on the bill and nothing behind it. The workshop's notes,
 * which mechanic has the car and what the parts cost to buy are not in the
 * payload at all, so there is nothing here to leak.
 */
export default function JobCard() {
  const { token = '' } = useParams();
  const [state, setState] = useState({ status: 'loading', card: null });

  useMeta({
    title: 'Your job card',
    description: 'Track your vehicle service with Balaji Automobiles.',
    path: `/j/${token}`,
    noindex: true,
  });

  useEffect(() => {
    const ac = new AbortController();
    setState({ status: 'loading', card: null });

    fetchSharedCard(token, { signal: ac.signal })
      .then((card) =>
        setState(card ? { status: 'ok', card } : { status: 'missing', card: null }),
      )
      .catch((err) => {
        if (err.name === 'AbortError') return;
        setState({ status: 'error', card: null });
      });

    return () => ac.abort();
  }, [token]);

  if (state.status === 'loading') return <Shell><p className="jc-note">Loading…</p></Shell>;

  if (state.status === 'missing') {
    return (
      <Shell>
        <h1>This link has expired</h1>
        <p className="lede u-mt-lg">
          It may have been replaced by a newer one, or the job card was removed. Ask
          the workshop to send the link again.
        </p>
        <p className="u-mt-lg">
          <Link className="btn btn--ghost" to="/">Go to the homepage</Link>
        </p>
      </Shell>
    );
  }

  if (state.status === 'error') {
    return (
      <Shell>
        <h1>Could not load this</h1>
        <p className="lede u-mt-lg">
          Something went wrong at our end, not yours. Check your connection and
          refresh the page.
        </p>
      </Shell>
    );
  }

  const card = state.card;
  const t = totals(card);
  const status = STATUS[card.status] ?? STATUS.open;
  const vehicle = [card.vehicle?.brand, card.vehicle?.model, card.vehicle?.variant]
    .filter(Boolean)
    .join(' ');

  return (
    <section className="section jc">
      <div className="wrap wrap--narrow">
        <header className="jc-head">
          <div>
            <p className="jc-garage">{card.garage?.name}</p>
            {card.garage?.address && <p className="jc-sub">{card.garage.address}</p>}
          </div>
          <span className={`jc-status jc-status--${status.tone}`}>{status.label}</span>
        </header>

        <div className="jc-panel">
          <dl className="jc-facts">
            <div><dt>Job card</dt><dd>{card.number}</dd></div>
            <div><dt>Vehicle</dt><dd>{vehicle || '–'}</dd></div>
            <div><dt>Registration</dt><dd>{card.vehicle?.reg_no || '–'}</dd></div>
            <div><dt>Opened</dt><dd>{formatDate(card.created_at)}</dd></div>
            {card.promised_at && (
              <div><dt>Promised</dt><dd>{formatDate(card.promised_at)}</dd></div>
            )}
            {card.odometer_km > 0 && (
              <div><dt>Odometer</dt><dd>{card.odometer_km.toLocaleString('en-IN')} km</dd></div>
            )}
          </dl>
        </div>

        <h2 className="jc-h2">Work and parts</h2>
        {card.items?.length ? (
          <table className="jc-table">
            <thead>
              <tr>
                <th>Item</th>
                <th className="jc-num">Qty</th>
                <th className="jc-num">Rate</th>
                <th className="jc-num">Amount</th>
              </tr>
            </thead>
            <tbody>
              {card.items.map((item, i) => (
                <tr key={`${item.name}-${i}`}>
                  <td>
                    {item.name}
                    {item.part_no ? <span className="jc-part"> · {item.part_no}</span> : null}
                  </td>
                  <td className="jc-num">{item.qty}</td>
                  <td className="jc-num">{money(item.rate)}</td>
                  <td className="jc-num">{money(item.qty * item.rate)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p className="jc-note">Nothing has been added to this job card yet.</p>
        )}

        <div className="jc-panel jc-totals">
          <Row label="Subtotal" value={money(t.subtotal)} />
          {t.discount > 0 && <Row label="Discount" value={`− ${money(t.discount)}`} />}
          {t.tax > 0 && (
            <Row label={`Tax (${(card.tax_rate * 100).toFixed(0)}%)`} value={money(t.tax)} />
          )}
          <Row label="Total" value={money(t.total)} strong />
          {t.paid > 0 && <Row label="Paid" value={money(t.paid)} />}
          {t.due > 0 && <Row label="Balance due" value={money(t.due)} strong accent />}
        </div>

        {card.garage?.phone && (
          <p className="btn-row u-mt-lg">
            <a className="btn btn--primary" href={`tel:${card.garage.phone}`}>
              Call the workshop
            </a>
            {STORE.customer.android && (
              <a className="btn btn--ghost" href={STORE.customer.android}>
                Get the app
              </a>
            )}
          </p>
        )}

        {card.garage?.terms && <p className="jc-terms">{card.garage.terms}</p>}

        <p className="jc-foot">
          This page is a live view of your job card. The workshop updates it as the
          work goes on, so it is worth checking back rather than saving a copy.
        </p>
      </div>
    </section>
  );
}

function Row({ label, value, strong, accent }) {
  return (
    <div className={`jc-row${strong ? ' jc-row--strong' : ''}${accent ? ' jc-row--accent' : ''}`}>
      <span>{label}</span>
      <span>{value}</span>
    </div>
  );
}

function Shell({ children }) {
  return (
    <section className="section jc">
      <div className="wrap wrap--narrow">{children}</div>
    </section>
  );
}
