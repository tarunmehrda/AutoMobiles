import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import Icon from '../components/Icon.jsx';
import Reveal from '../components/Reveal.jsx';
import useMeta from '../hooks/useMeta.js';
import { SUPPORT, TOPICS } from '../lib/site.js';

/**
 * Where a submitted enquiry goes.
 *
 * "netlify" posts it to Netlify Forms, which stores it against the site and
 * emails a copy to whoever is listed under Project configuration > Forms >
 * Form notifications. That is what puts it in Gmail, and it needs no server
 * of our own. The matching stub form lives in index.html, because Netlify
 * registers forms by parsing the deployed HTML and never runs React.
 *
 * "whatsapp" opens WhatsApp with the message already written, which is how the
 * counter answered before this existed and is still the fastest route on a
 * phone. Set MODE to that if the form is ever moved off Netlify.
 */
const MODE = 'netlify';

/** Netlify matches the submission to the stub form by this name. */
const FORM_NAME = 'enquiry';

/* --------------------------------------------------------------- validation */

const RULES = {
  name: (v) => {
    if (!v) return 'Please tell us your name.';
    if (v.length < 2) return 'That looks too short.';
    return '';
  },
  phone: (v) => {
    if (!v) return 'We need a number to call you back on.';
    let digits = v.replace(/\D/g, '').replace(/^(91|0)/, '');
    if (!/^[6-9]\d{9}$/.test(digits)) return 'Enter a 10-digit Indian mobile number.';
    return '';
  },
  email: (v) => {
    if (!v) return ''; // optional
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v)) return 'Check the email address.';
    return '';
  },
  topic: (v) => (v ? '' : 'Pick what this is about.'),
  message: (v) => {
    if (!v) return 'Tell us what you need.';
    if (v.length < 10) return 'A little more detail helps us answer properly.';
    if (v.length > 2000) return 'Please keep it under 2000 characters.';
    return '';
  },
  consent: (v) => (v ? '' : 'We need your go-ahead to reply.'),
};

const BLANK = {
  name: '', phone: '', email: '', vehicle: '', topic: '', message: '', consent: false, botField: '',
};

/* --------------------------------------------------------------- channels */

const CHANNELS = [
  {
    icon: 'i-phone', title: 'Call the counter',
    value: SUPPORT.phone, href: SUPPORT.phoneHref,
    note: 'Fastest if the car is already with us.',
  },
  {
    icon: 'i-wa', title: 'WhatsApp',
    value: SUPPORT.phone, href: SUPPORT.whatsappHref, external: true,
    note: 'Send a photo of the problem and we will look.',
  },
  {
    icon: 'i-mail', title: 'Email',
    value: SUPPORT.email, href: SUPPORT.emailHref,
    note: 'For bills, estimates and anything with an attachment.',
  },
];

/* ------------------------------------------------------------------- page */

export default function Contact() {
  const [params] = useSearchParams();
  const [values, setValues] = useState(BLANK);
  const [errors, setErrors] = useState({});
  const [touched, setTouched] = useState({});
  const [status, setStatus] = useState(null); // { kind: 'ok' | 'err', text }
  const [sending, setSending] = useState(false);
  const openedAt = useRef(Date.now());
  const statusRef = useRef(null);

  useMeta({
    title: 'Contact',
    description:
      'Call, WhatsApp or email Balaji Automobiles, or send an enquiry about a service, a bill, the Balaji Car app or the workshop console.',
    path: '/contact',
  });

  /* Deep links like /contact?topic=console arrive from the app cards and FAQ. */
  const wanted = params.get('topic');
  useEffect(() => {
    if (wanted && TOPICS.some((t) => t.id === wanted)) {
      setValues((v) => ({ ...v, topic: wanted }));
    }
  }, [wanted]);

  /* On success, move focus to the result — there is nothing else to do, and it
     is the only way a screen reader reliably lands on the confirmation.
     On failure, leave focus where the submit handler put it: the first field
     that needs fixing. The message is still announced, through aria-live. */
  useEffect(() => {
    if (status?.kind === 'ok') statusRef.current?.focus();
  }, [status]);

  const fieldValue = (name, v) => (name === 'consent' ? (v ? 'yes' : '') : String(v).trim());

  const validate = (name, raw) => {
    const rule = RULES[name];
    return rule ? rule(fieldValue(name, raw)) : '';
  };

  const onChange = (e) => {
    const { name, type, value, checked } = e.target;
    const next = type === 'checkbox' ? checked : value;
    setValues((v) => ({ ...v, [name]: next }));
    /* Only nag live once the field has already been marked wrong. */
    if (errors[name]) setErrors((p) => ({ ...p, [name]: validate(name, next) }));
  };

  const onBlur = (e) => {
    const { name } = e.target;
    setTouched((t) => ({ ...t, [name]: true }));
    setErrors((p) => ({ ...p, [name]: validate(name, values[name]) }));
  };

  const whatsappUrl = useMemo(
    () => (data) => {
      const topic = TOPICS.find((t) => t.id === data.topic)?.label || data.topic;
      const lines = [
        'Enquiry from balajiautomobiles.in',
        '',
        `Name: ${data.name}`,
        `Phone: ${data.phone}`,
        data.email && `Email: ${data.email}`,
        data.vehicle && `Vehicle: ${data.vehicle}`,
        `About: ${topic}`,
        '',
        data.message,
      ].filter(Boolean).join('\n');
      return `${SUPPORT.whatsappHref}?text=${encodeURIComponent(lines)}`;
    },
    [],
  );

  const onSubmit = async (e) => {
    e.preventDefault();
    setStatus(null);

    /* There is a hidden trap field (bot-field) that people never see and bots
       fill in. It is NOT checked here. An earlier version stopped silently when
       it was filled, and Chrome autofill filled it for real customers, so their
       enquiries vanished with no error. Now the value is simply sent along and
       Netlify's own filter judges it server-side: a bot lands in the Spam tab,
       and a person who was misread can still be found there. Nothing is lost. */

    const found = {};
    Object.keys(RULES).forEach((name) => {
      const msg = validate(name, values[name]);
      if (msg) found[name] = msg;
    });

    setErrors(found);
    setTouched((t) => ({ ...t, ...Object.fromEntries(Object.keys(RULES).map((k) => [k, true])) }));

    const first = Object.keys(found)[0];
    if (first) {
      setStatus({ kind: 'err', text: 'A couple of fields need a look before this can go.' });
      document.getElementById(first)?.focus();
      return;
    }

    /* Only once the form is otherwise valid: a complete, correct form filled in
       under two and a half seconds was not filled in by a person. Checking this
       last means somebody who clicks Send early still gets told what is missing,
       rather than being scolded for being quick. */
    if (Date.now() - openedAt.current < 2500) {
      setStatus({
        kind: 'err',
        text: 'Give that a moment and press send again, so we can tell you apart from a bot.',
      });
      openedAt.current = Date.now() - 2400;
      return;
    }

    const data = {
      name: values.name.trim(),
      phone: values.phone.trim(),
      email: values.email.trim(),
      vehicle: values.vehicle.trim(),
      topic: values.topic,
      message: values.message.trim(),
    };
    const firstName = data.name.split(' ')[0];

    /* Netlify Forms expects url-encoded fields, with the form's name among
       them, posted back to the site's own origin. */
    const encode = (obj) =>
      Object.keys(obj)
        .map((k) => `${encodeURIComponent(k)}=${encodeURIComponent(obj[k])}`)
        .join('&');

    const reset = () => {
      setValues(BLANK);
      setTouched({});
      openedAt.current = Date.now();
    };

    const toWhatsApp = () => {
      const win = window.open(whatsappUrl(data), '_blank', 'noopener,noreferrer');
      if (win) {
        setStatus({
          kind: 'ok',
          text: `Thanks, ${firstName}. WhatsApp is open with your message. Press send and we will reply the same working day.`,
        });
        reset();
      } else {
        setStatus({
          kind: 'err',
          text: `Allow pop-ups to finish on WhatsApp, or call us on ${SUPPORT.phone}.`,
        });
      }
    };

    if (MODE === 'whatsapp') {
      toWhatsApp();
      return;
    }

    setSending(true);
    try {
      const res = await fetch('/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: encode({ 'form-name': FORM_NAME, ...data, 'bot-field': values.botField }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setStatus({
        kind: 'ok',
        text: `Thanks, ${firstName}. Your message is with the counter and we will reply the same working day.`,
      });
      reset();
    } catch {
      /* The network failed, or the site is running somewhere that does not
         handle the post. Rather than lose the enquiry, hand it to WhatsApp. */
      setStatus({
        kind: 'err',
        text: 'That did not go through. Opening WhatsApp with your message instead.',
      });
      toWhatsApp();
    } finally {
      setSending(false);
    }
  };

  const err = (name) => (touched[name] ? errors[name] || '' : '');
  const invalid = (name) => (err(name) ? 'true' : undefined);

  return (
    <>
      <section className="page-head">
        <div className="wrap">
          <p className="crumb">
            <Link to="/">Home</Link> · Contact
          </p>
          <h1>Talk to a person.</h1>
          <p className="lede u-mt-lg">
            The counter answers the phone, and the same people answer WhatsApp. If it is
            easier to write it down, the form below reaches us just as fast.
          </p>
        </div>
      </section>

      <section className="section section--tight">
        <div className="wrap">
          <div className="grid channels">
            {CHANNELS.map((c, i) => (
              <Reveal
                as="a"
                className="channel"
                key={c.title}
                delay={i}
                href={c.href}
                {...(c.external ? { target: '_blank', rel: 'noopener noreferrer' } : {})}
              >
                <span className="tile">
                  <Icon name={c.icon} size={19} />
                </span>
                <h3>{c.title}</h3>
                <b>{c.value}</b>
                <small>{c.note}</small>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="section section--flush-top">
        <div className="wrap contact-grid">

          {/* ------------------------------------------------------ form */}
          <div className="form-card">
            <h2>Send an enquiry</h2>
            <p>
              Everything marked with a <span className="u-req">*</span> is needed. We reply
              the same working day.
            </p>

            <form className="form" id="contact-form" onSubmit={onSubmit} noValidate>

              {/* Trap for bots: off-screen, skipped by the keyboard, hidden from
                  screen readers. Named and labelled so browser autofill has no
                  reason to touch it. "company" was the old name, and autofill
                  took it for the organisation field. */}
              <div className="hp" aria-hidden="true">
                <label htmlFor="bot-field">Leave this empty</label>
                <input
                  id="bot-field" name="botField" type="text" tabIndex={-1}
                  autoComplete="off" data-lpignore="true" data-1p-ignore="true"
                  value={values.botField} onChange={onChange}
                />
              </div>

              <div className="field-2">
                <div className="field">
                  <label htmlFor="name">Your name <span className="u-req">*</span></label>
                  <input
                    id="name" name="name" type="text" autoComplete="name"
                    placeholder="Ramesh Kumar" value={values.name}
                    onChange={onChange} onBlur={onBlur}
                    aria-invalid={invalid('name')} aria-describedby="name-err"
                  />
                  <span className="err" id="name-err">{err('name')}</span>
                </div>

                <div className="field">
                  <label htmlFor="phone">Mobile number <span className="u-req">*</span></label>
                  <input
                    id="phone" name="phone" type="tel" inputMode="numeric" autoComplete="tel"
                    placeholder="98765 43210" value={values.phone}
                    onChange={onChange} onBlur={onBlur}
                    aria-invalid={invalid('phone')} aria-describedby="phone-err"
                  />
                  <span className="err" id="phone-err">{err('phone')}</span>
                </div>
              </div>

              <div className="field-2">
                <div className="field">
                  <label htmlFor="email">Email <span className="u-opt">(optional)</span></label>
                  <input
                    id="email" name="email" type="email" autoComplete="email"
                    placeholder="you@example.com" value={values.email}
                    onChange={onChange} onBlur={onBlur}
                    aria-invalid={invalid('email')} aria-describedby="email-err"
                  />
                  <span className="err" id="email-err">{err('email')}</span>
                </div>

                <div className="field">
                  <label htmlFor="vehicle">Vehicle number <span className="u-opt">(optional)</span></label>
                  <input
                    id="vehicle" name="vehicle" type="text"
                    placeholder="RJ18CC1390" value={values.vehicle}
                    onChange={onChange}
                  />
                  <span className="err" />
                </div>
              </div>

              <div className="field">
                <label htmlFor="topic">What is this about? <span className="u-req">*</span></label>
                <div className="select-wrap">
                  <select
                    id="topic" name="topic" value={values.topic}
                    onChange={onChange} onBlur={onBlur}
                    aria-invalid={invalid('topic')} aria-describedby="topic-err"
                  >
                    <option value="">Choose one…</option>
                    {TOPICS.map((t) => (
                      <option key={t.id} value={t.id}>{t.label}</option>
                    ))}
                  </select>
                </div>
                <span className="err" id="topic-err">{err('topic')}</span>
              </div>

              <div className="field">
                <label htmlFor="message">Your message <span className="u-req">*</span></label>
                <textarea
                  id="message" name="message"
                  placeholder="Tell us what the car is doing, or what you need from us."
                  value={values.message} onChange={onChange} onBlur={onBlur}
                  aria-invalid={invalid('message')} aria-describedby="message-err"
                />
                <span className="err" id="message-err">{err('message')}</span>
              </div>

              <div className="field">
                <label className="consent" htmlFor="consent">
                  <input
                    id="consent" name="consent" type="checkbox"
                    checked={values.consent} onChange={onChange} onBlur={onBlur}
                    aria-invalid={invalid('consent')} aria-describedby="consent-err"
                  />
                  <span>
                    Yes, contact me about this enquiry. We use your details for nothing else. See the{' '}
                    <Link to="/privacy">privacy policy</Link>.
                  </span>
                </label>
                <span className="err" id="consent-err">{err('consent')}</span>
              </div>

              <div
                className={status ? `form-status form-status--${status.kind}` : 'form-status'}
                id="form-status"
                role="status"
                aria-live="polite"
                tabIndex={-1}
                ref={statusRef}
                hidden={!status}
              >
                {status?.text}
              </div>

              <button
                className="btn btn--primary btn--block"
                type="submit"
                id="form-submit"
                aria-disabled={sending || undefined}
              >
                {sending ? 'Sending…' : 'Send enquiry'}
                {!sending && <Icon name="i-arrow" size={18} className="arrow" />}
              </button>

              <p className="form__note">
                {MODE === 'netlify'
                  ? 'Your message comes straight to the counter. We reply the same working day.'
                  : 'This opens WhatsApp with your message filled in. Press send there and it reaches the counter.'}
              </p>
            </form>
          </div>

          {/* ----------------------------------------------------- aside */}
          <div className="aside-stack">
            <Reveal className="hours">
              <h3>
                <Icon name="i-clock" size={18} /> When we are open
              </h3>
              <dl>
                <div>
                  <dt>Monday to Saturday</dt>
                  <dd>9:30 am – 7:30 pm</dd>
                </div>
                <div>
                  <dt>Sunday</dt>
                  <dd>Closed</dd>
                </div>
                <div>
                  <dt>Pickup &amp; drop</dt>
                  <dd>On request</dd>
                </div>
              </dl>
            </Reveal>

            <Reveal className="hours" delay={1}>
              <h3>
                <Icon name="i-pin" size={18} /> Where we are
              </h3>
              <address>
                {SUPPORT.address.map((line) => (
                  <span key={line}>{line}</span>
                ))}
              </address>
              <a
                className="tlink tlink--sp"
                href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(SUPPORT.address.join(', '))}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                Open in Maps
                <Icon name="i-arrow" size={15} />
              </a>
            </Reveal>

            <Reveal className="hours" delay={2}>
              <h3>Already using the app?</h3>
              <p>
                Raising the query inside Balaji Car attaches it to your job card, so whoever
                picks it up can already see the vehicle and the bill.
              </p>
              <Link className="tlink tlink--sp" to="/features#customer">
                How support works in the app
                <Icon name="i-arrow" size={15} />
              </Link>
            </Reveal>
          </div>
        </div>
      </section>
    </>
  );
}
