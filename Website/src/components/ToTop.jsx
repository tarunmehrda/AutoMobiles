import { useEffect, useState } from 'react';
import Icon from './Icon.jsx';

export default function ToTop() {
  const [on, setOn] = useState(false);

  useEffect(() => {
    const onScroll = () => setOn(window.scrollY > 700);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const go = () => {
    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    window.scrollTo({ top: 0, behavior: still ? 'auto' : 'smooth' });
  };

  return (
    <button
      className={`to-top${on ? ' is-on' : ''}`}
      type="button"
      onClick={go}
      aria-label="Back to top"
      tabIndex={on ? 0 : -1}
    >
      <Icon name="i-up" size={18} />
    </button>
  );
}
