// =====================================================================
// notify-garage — turns a new alert row into a push
// =====================================================================
// Invoked by two Supabase Database Webhooks, both on INSERT:
//
//   * public.garage_notifications → the workshop's phones (garage_devices)
//   * public.customer_alerts      → the customer's phones (customer_devices,
//                                   22_customer_push.sql)
//
// One function for both, told apart by the webhook's `table`, so there is
// one deployment and one secret. See docs/06-notifications.md.
//
// This is the only part of the notification path that lives outside the
// database, and it is outside for one reason: Postgres can raise a row,
// and a row reaches every console that is running, but a console that is
// closed has no socket to reach. Google will not take a message from
// Postgres, so something has to stand between them and hold the service
// account. This is that something, and it does nothing else.
//
// It is best-effort by design. A push that fails has not lost anything:
// the notification is already durable in `garage_notifications`, the
// bell will show it the moment the console opens, and the front desk
// screen has had the booking since it was inserted. So every failure
// here is logged and swallowed, and the webhook is answered 200 either
// way — a non-2xx would only make Supabase retry a send that a phone may
// well have already received.
// =====================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

// --- what the webhook sends -------------------------------------------
// A `garage_notifications` row carries `garage_id`; a `customer_alerts`
// row carries `profile_id`. Everything the push itself needs is common.
interface NotificationRow {
  id: string;
  garage_id?: string;
  profile_id?: string;
  kind: string;
  title: string;
  body: string;
  route: string | null;
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: NotificationRow | null;
}

// --- the service account ----------------------------------------------
interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/// Access tokens are good for an hour and this module stays warm between
/// invocations, so minting one per booking would be three extra round
/// trips to Google for no reason. Refreshed a minute early, because a
/// token that expires in flight fails the send it was fetched for.
let cachedToken: { value: string; expiresAt: number } | null = null;

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw) throw new Error('FCM_SERVICE_ACCOUNT is not set');
  const parsed = JSON.parse(raw) as ServiceAccount;
  // JSON in an environment variable often arrives with the newlines in the
  // key escaped, which is invalid PEM and fails deep inside importKey with
  // a message that says nothing about why.
  parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
  return parsed;
}

function b64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === 'string'
    ? bytes
    : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function signingKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/// The JWT-bearer flow: sign a claim set with the service account's key and
/// trade it for an OAuth token. Done by hand rather than with a library so
/// this function has one dependency instead of three.
async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const claims = {
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${
    b64url(JSON.stringify(claims))
  }`;

  const key = await signingKey(account.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${b64url(new Uint8Array(signature))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`token exchange failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json() as { access_token: string; expires_in: number };
  cachedToken = {
    value: json.access_token,
    expiresAt: now + json.expires_in,
  };
  return json.access_token;
}

/// Which Android channel an alert lands in, and therefore which chime the
/// counter hears. The channels themselves are created in the console's
/// MainActivity, and their sounds are fixed at creation — so these ids carry
/// the same version suffix, and changing a sound means bumping both together.
///
/// An unknown kind falls through to the general channel rather than being
/// dropped: a new kind of alert added to the database later should still
/// ring, just without a chime of its own until one is chosen for it.
const CHANNELS: Record<string, string> = {
  booking: 'garage_booking_v1',
  payment: 'garage_payment_v1',
  reminder: 'garage_reminder_v1',
  review: 'garage_general_v1',
};

const GENERAL = 'garage_general_v1';

/// The customer app has one channel, created in its own MainActivity.
const CUSTOMER_CHANNEL = 'customer_updates_v1';

/// Sends to one handset. Returns false only when the token is genuinely
/// dead, which is the caller's cue to drop it — a network blip or a Google
/// 500 returns true, because the token is still good and throwing it away
/// would permanently unsubscribe a working phone over a transient fault.
async function send(
  projectId: string,
  token: string,
  bearer: string,
  row: NotificationRow,
  channel: string,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${bearer}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: row.title, body: row.body },
          // Read by PushService on the tap, to open the right screen. `kind`
          // rides along so the console can tell what it was woken for without
          // re-reading the row.
          data: {
            route: row.route ?? '/notifications',
            id: row.id,
            kind: row.kind,
          },
          android: {
            priority: 'HIGH',
            notification: {
              // The chime. A booking and a payment must not sound alike:
              // the counter is across the workshop with its hands full, and
              // the whole value of the alert is being recognisable from
              // there.
              channel_id: channel,
              // Collapses to one line per booking in the tray rather than
              // stacking six identical-looking rows on a busy morning.
              tag: row.id,
            },
          },
        },
      }),
    },
  );

  if (res.ok) return true;

  const text = await res.text();
  const dead = res.status === 404 ||
    text.includes('UNREGISTERED') ||
    text.includes('INVALID_ARGUMENT');
  console.error(`fcm ${res.status} for ${token.slice(0, 12)}…: ${text}`);
  return !dead;
}

Deno.serve(async (req) => {
  // The webhook is the only caller. Deployed with --no-verify-jwt, so this
  // shared secret is what stands between the function and the open
  // internet; without it anyone who learned the URL could push arbitrary
  // text to every phone in the workshop.
  const expected = Deno.env.get('WEBHOOK_SECRET');
  if (!expected || req.headers.get('x-webhook-secret') !== expected) {
    return new Response('forbidden', { status: 403 });
  }

  try {
    const payload = await req.json() as WebhookPayload;
    const row = payload.record;
    if (payload.type !== 'INSERT' || !row) {
      return new Response('ignored', { status: 200 });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      // The service role, because both device tables are readable by
      // nobody: RLS on and no policy at all, so this is the only way in.
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Whose phones, and which channel they ring on.
    const forCustomer = payload.table === 'customer_alerts';
    const deviceTable = forCustomer ? 'customer_devices' : 'garage_devices';
    const owner = forCustomer ? row.profile_id : row.garage_id;
    const channel = forCustomer
      ? CUSTOMER_CHANNEL
      : CHANNELS[row.kind] ?? GENERAL;
    if (!owner) return new Response('ignored', { status: 200 });

    const { data: devices, error } = await supabase
      .from(deviceTable)
      .select('token')
      .eq(forCustomer ? 'profile_id' : 'garage_id', owner);

    if (error) throw error;
    if (!devices?.length) return new Response('no devices', { status: 200 });

    const account = serviceAccount();
    const bearer = await accessToken(account);

    // In parallel: a workshop has a handful of handsets, and doing them one
    // at a time would put the last phone's alert several seconds behind the
    // first one's.
    const results = await Promise.all(
      devices.map(async (d: { token: string }) => ({
        token: d.token,
        alive: await send(account.project_id, d.token, bearer, row, channel).catch(
          (e) => {
            console.error(`send threw: ${e}`);
            return true;
          },
        ),
      })),
    );

    const dead = results.filter((r) => !r.alive).map((r) => r.token);
    if (dead.length) {
      await supabase.from(deviceTable).delete().in('token', dead);
    }

    return new Response(
      JSON.stringify({ sent: results.length - dead.length, dropped: dead.length }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  } catch (e) {
    // Answered 200 on purpose — see the note at the top of this file.
    console.error(`notify-garage failed: ${e}`);
    return new Response('error logged', { status: 200 });
  }
});
