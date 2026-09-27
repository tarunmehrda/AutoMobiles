/**
 * Everything a rebrand or a re-point would need to change.
 *
 * The contact details and the Android package names are the same values as
 * `User/lib/config/brand.dart` and `Admin/lib/config/brand.dart`. If they change
 * in the apps, change them here too — the two are one product to the person
 * holding the phone.
 */

export const SITE = {
  name: 'Balaji Automobiles',
  tagline: 'Your car. Our care.',
  vendor: 'Techifyhouse',
  origin: 'https://balajiautomobiles.in',
};

export const SUPPORT = {
  phone: '+91 92692 97999',
  phoneHref: 'tel:+919269297999',
  phonePlain: '9269297999',
  whatsapp: '919269297999',
  whatsappHref: 'https://wa.me/919269297999',
  email: 'support@balajiautomobiles.in',
  emailHref: 'mailto:support@balajiautomobiles.in',
  hours: 'Monday to Saturday, 9:30 am – 7:30 pm',
  /* TODO for the owner: replace with the workshop's street address before launch. */
  address: ['Balaji Automobiles', 'Sector 15, Kuddleroo', 'Rajasthan, India'],
};

export const STORE = {
  customer: {
    name: 'Balaji Car',
    android: 'https://play.google.com/store/apps/details?id=com.balajiautomobiles.customer',
    ios: null, // not shipped yet — badges render as "coming soon" while this is null
  },
  garage: {
    name: 'Balaji Garage',
    android: 'https://play.google.com/store/apps/details?id=com.balajiautomobiles.garage',
    ios: null,
  },
};

export const SOCIAL = [
  { label: 'WhatsApp', icon: 'i-wa', href: SUPPORT.whatsappHref },
  { label: 'Instagram', icon: 'i-insta', href: 'https://www.instagram.com/' },
  { label: 'Facebook', icon: 'i-fb', href: 'https://www.facebook.com/' },
];

export const NAV = [
  { label: 'Features', to: '/features' },
  { label: 'How it works', to: '/#how' },
  { label: 'Download', to: '/#download' },
  { label: 'Security', to: '/#security' },
  { label: 'Contact', to: '/contact' },
];

/** Subjects offered by the contact form. The `id` is what lands in the message. */
export const TOPICS = [
  { id: 'service', label: 'Book or change a service' },
  { id: 'app', label: 'Help with the Balaji Car app' },
  { id: 'bill', label: 'A question about a bill or an estimate' },
  { id: 'console', label: 'I run a workshop, show me the console' },
  { id: 'ios', label: 'Tell me when the iPhone app lands' },
  { id: 'other', label: 'Something else' },
];

/**
 * Resolve a public asset against the build's base path.
 *
 * A normal build sets BASE_URL to "/" and this is a no-op. A portable build
 * (`VITE_ARTIFACT=1`) sets it to "./", so the same bundle works when it is
 * served from a sub-path rather than a domain root.
 */
export const asset = (p) => `${import.meta.env.BASE_URL}${p.replace(/^\//, '')}`;
