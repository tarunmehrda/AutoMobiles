/**
 * One sprite, mounted once at the top of the app. Every <Icon /> is a <use>
 * pointing into it, so an icon used forty times costs forty short elements
 * rather than forty copies of its path data — and it needs no extra request.
 */
export default function IconSprite() {
  return (
    <svg width="0" height="0" className="sprite" aria-hidden="true" focusable="false">
      <symbol id="i-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round">
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </symbol>
      <symbol id="i-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
      </symbol>
      <symbol id="i-menu" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
        <path d="M4 7h16M4 12h16M4 17h16" />
      </symbol>
      <symbol id="i-close" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
        <path d="M6 6l12 12M18 6L6 18" />
      </symbol>
      <symbol id="i-up" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 19V5M6 11l6-6 6 6" />
      </symbol>
      <symbol id="i-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 12h13M13 6l6 6-6 6" />
      </symbol>
      <symbol id="i-check" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 12.5 9.5 18 20 6" />
      </symbol>
      <symbol id="i-cal" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="5" width="18" height="16" rx="3" />
        <path d="M8 3v4M16 3v4M3 10h18" />
      </symbol>
      <symbol id="i-car" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M5 17h14M4 17v-4.2a2 2 0 0 1 .3-1L6.6 8A2 2 0 0 1 8.3 7h7.4a2 2 0 0 1 1.7 1l2.3 3.8a2 2 0 0 1 .3 1V17" />
        <circle cx="7.5" cy="17.5" r="1.8" />
        <circle cx="16.5" cy="17.5" r="1.8" />
      </symbol>
      <symbol id="i-bell" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M18 9a6 6 0 1 0-12 0c0 6-2 7-2 7h16s-2-1-2-7M13.7 20a2 2 0 0 1-3.4 0" />
      </symbol>
      <symbol id="i-bill" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M6 2h12a1 1 0 0 1 1 1v18l-3-2-3 2-3-2-3 2V3a1 1 0 0 1 1-1z" />
        <path d="M9 7h6M9 11h6M9 15h3" />
      </symbol>
      <symbol id="i-chat" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 12a8 8 0 0 1-11.6 7.1L3 21l1.9-6.4A8 8 0 1 1 21 12z" />
      </symbol>
      <symbol id="i-pay" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2.5" y="5" width="19" height="14" rx="3" />
        <path d="M2.5 10h19M6.5 15h3" />
      </symbol>
      <symbol id="i-wrench" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M15.5 3.5a5.5 5.5 0 0 0-5 7.7l-7 7a2 2 0 0 0 2.8 2.8l7-7a5.5 5.5 0 0 0 6.9-7.2l-3 3-2.8-2.8 3-3a5.5 5.5 0 0 0-1.9-.5z" />
      </symbol>
      <symbol id="i-chart" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M3 21h18M6 21v-7M11 21V8M16 21v-4M21 21V4" />
      </symbol>
      <symbol id="i-box" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 8.5v7a2 2 0 0 1-1 1.7l-7 4a2 2 0 0 1-2 0l-7-4a2 2 0 0 1-1-1.7v-7a2 2 0 0 1 1-1.7l7-4a2 2 0 0 1 2 0l7 4a2 2 0 0 1 1 1.7z" />
        <path d="m3.3 7.5 8.7 5 8.7-5M12 22v-9.5" />
      </symbol>
      <symbol id="i-users" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="9" cy="8" r="3.4" />
        <path d="M2.5 20a6.5 6.5 0 0 1 13 0M17 5.2a3.4 3.4 0 0 1 0 5.6M18.5 14.4A6.5 6.5 0 0 1 21.5 20" />
      </symbol>
      <symbol id="i-clock" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5.2l3.2 2" />
      </symbol>
      <symbol id="i-pin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M20 10.5c0 5.6-8 12-8 12s-8-6.4-8-12a8 8 0 1 1 16 0z" />
        <circle cx="12" cy="10.3" r="2.8" />
      </symbol>
      <symbol id="i-phone" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 16.9v2.6a2 2 0 0 1-2.2 2 19.4 19.4 0 0 1-8.5-3 19.1 19.1 0 0 1-5.9-5.9A19.4 19.4 0 0 1 1.4 4a2 2 0 0 1 2-2.2H6a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L7.1 9.6a15.5 15.5 0 0 0 5.9 5.9l1.2-1.1a2 2 0 0 1 2.1-.5c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z" />
      </symbol>
      <symbol id="i-mail" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2.5" y="4.5" width="19" height="15" rx="3" />
        <path d="m3 7 8.1 5.4a2 2 0 0 0 2.2 0L21.5 7" />
      </symbol>
      <symbol id="i-wa" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2a9.9 9.9 0 0 0-8.6 14.9L2 22l5.3-1.4A9.9 9.9 0 1 0 12 2zm0 18.1a8.2 8.2 0 0 1-4.2-1.1l-.3-.2-3.1.8.8-3-.2-.3A8.2 8.2 0 1 1 12 20.1zm4.5-5.7c-.2-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1l-.8 1c-.1.2-.3.2-.6.1a6.7 6.7 0 0 1-3.3-2.9c-.2-.4 0-.5.1-.7l.5-.6c.1-.2.1-.3 0-.5l-.8-1.9c-.2-.4-.4-.4-.6-.4h-.5c-.2 0-.5.1-.7.4a2.9 2.9 0 0 0-.9 2.2 5 5 0 0 0 1.1 2.7 11.4 11.4 0 0 0 4.4 3.9c1.6.6 2.2.7 3 .6a2.5 2.5 0 0 0 1.7-1.2c.2-.5.2-1 .1-1.1z" />
      </symbol>
      <symbol id="i-shield" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 22s8-3.5 8-9.5V5.4l-8-3.2-8 3.2v7.1C4 18.5 12 22 12 22z" />
        <path d="m9 12 2.2 2.2L15.5 10" />
      </symbol>
      <symbol id="i-lock" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="4" y="10.5" width="16" height="11" rx="3" />
        <path d="M8 10.5V7a4 4 0 0 1 8 0v3.5" />
      </symbol>
      <symbol id="i-key" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="8" cy="8" r="4.5" />
        <path d="m11.4 11.4 8.6 8.6M17 17l2.5-2.5M14.5 14.5 17 12" />
      </symbol>
      <symbol id="i-offline" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M2 3 22 21M8.8 13.3a5 5 0 0 1 6 .4M5.2 9.7a10 10 0 0 1 4-2.2M18.9 9.8a10 10 0 0 0-3.4-2" />
        <circle cx="12" cy="18" r="1" />
      </symbol>
      <symbol id="i-play" viewBox="0 0 512 512">
        <path fill="#00D0FF" d="M48 32 272 256 48 480a26 26 0 0 1-12-23V55a26 26 0 0 1 12-23z" />
        <path fill="#00E27A" d="M48 32 272 256l120-70L84 14a30 30 0 0 0-36 18z" />
        <path fill="#FFCE00" d="m392 186-120 70 120 70 70-41c19-11 19-48 0-59z" />
        <path fill="#FF3B44" d="M272 256 48 480a30 30 0 0 0 36 18l308-172z" />
      </symbol>
      <symbol id="i-apple" viewBox="0 0 24 24" fill="currentColor">
        <path d="M17.05 12.04c-.03-2.75 2.25-4.07 2.35-4.13-1.28-1.87-3.27-2.13-3.98-2.16-1.7-.17-3.31 1-4.17 1-.86 0-2.19-.98-3.6-.95-1.85.03-3.56 1.08-4.51 2.73-1.92 3.33-.49 8.26 1.38 10.96.92 1.32 2.01 2.8 3.45 2.75 1.38-.06 1.9-.89 3.57-.89 1.67 0 2.14.89 3.6.86 1.49-.02 2.43-1.34 3.34-2.67 1.05-1.53 1.49-3.01 1.51-3.09-.03-.01-2.9-1.11-2.94-4.41zM14.3 3.9c.76-.92 1.27-2.2 1.13-3.47-1.09.04-2.42.73-3.2 1.64-.7.81-1.32 2.11-1.15 3.36 1.22.09 2.46-.62 3.22-1.53z" />
      </symbol>
      <symbol id="i-insta" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
        <rect x="3" y="3" width="18" height="18" rx="5" />
        <circle cx="12" cy="12" r="4" />
        <circle cx="17.2" cy="6.8" r="1.1" fill="currentColor" stroke="none" />
      </symbol>
      <symbol id="i-fb" viewBox="0 0 24 24" fill="currentColor">
        <path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.5h-1.3c-1.2 0-1.6.8-1.6 1.6V12h2.8l-.5 2.9h-2.3v7A10 10 0 0 0 22 12z" />
      </symbol>
    </svg>
  );
}
