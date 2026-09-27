/**
 * The one backend call this website makes.
 *
 * Everything else here is static marketing. This exists so the link a
 * workshop sends over WhatsApp — balajiautomobiles.in/j/<token> — opens a
 * real job card for a customer who has installed nothing and signed in to
 * nothing.
 *
 * The key below is the publishable (anon) key, which is meant to ship in a
 * client. It grants nothing on its own: `shared_card` is the only function
 * `anon` may call, it takes a 192-bit token, and it returns exactly one job
 * card's public fields. See supabase/07_share.sql.
 */

export const SUPABASE_URL = 'https://zlrmcrhwtfbwbxhfmygs.supabase.co';
export const SUPABASE_ANON_KEY = 'sb_publishable_IJGQOXtE8tr7b_IgIi5cdQ_wDs6oFl7';

/**
 * Reads one shared job card.
 *
 * Resolves to the card, or null when the token is unknown — which is the
 * same answer for a typo, a revoked link and a card that was deleted, on
 * purpose. Throws only when the network or the backend failed, so the page
 * can tell "this link is dead" apart from "try again in a minute".
 */
export async function fetchSharedCard(token, { signal } = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/shared_card`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_ANON_KEY,
      authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({ tok: token }),
    signal,
  });

  if (!res.ok) {
    throw new Error(`backend ${res.status}`);
  }
  const data = await res.json();
  // PostgREST hands back `null` for a function that returned no row, which
  // is what an unknown token produces.
  return data ?? null;
}

const rupee = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 0,
});

export const money = (n) => rupee.format(Number(n) || 0);

export function formatDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

/**
 * What the customer is actually being shown, worked out from the same
 * numbers the console printed: lines, less the discount, plus tax.
 *
 * Done here rather than sent down so the page cannot disagree with the bill
 * about the arithmetic — there is only one place it happens.
 */
export function totals(card) {
  const items = card?.items ?? [];
  const subtotal = items.reduce(
    (sum, i) => sum + (Number(i.qty) || 0) * (Number(i.rate) || 0),
    0,
  );
  const discount = Number(card?.discount) || 0;
  const taxable = Math.max(0, subtotal - discount);
  const tax = taxable * (Number(card?.tax_rate) || 0);
  const total = taxable + tax;
  const paid = Number(card?.paid) || 0;
  return {
    subtotal,
    discount,
    tax,
    total,
    paid,
    due: Math.max(0, total - paid),
  };
}

export const STATUS = {
  open: { label: 'In progress', tone: 'work' },
  complete: { label: 'Ready for pickup', tone: 'ready' },
  closed: { label: 'Completed', tone: 'done' },
};
