import { useEffect, useRef, useState } from 'react';

/**
 * Fades a block up the first time it comes into view, once, then stops
 * watching. Anyone who has asked their system for less motion, and anyone
 * whose browser has no IntersectionObserver, gets it visible immediately.
 */
export default function Reveal({ as: Tag = 'div', delay = 0, className = '', children, ...rest }) {
  const ref = useRef(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || shown) return undefined;

    const still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (still || !('IntersectionObserver' in window)) {
      setShown(true);
      return undefined;
    }

    let timer;
    const io = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        io.unobserve(el);
        timer = setTimeout(() => setShown(true), delay * 70);
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.08 },
    );

    io.observe(el);
    return () => {
      io.disconnect();
      clearTimeout(timer);
    };
  }, [delay, shown]);

  return (
    <Tag ref={ref} className={`reveal${shown ? ' is-in' : ''}${className ? ` ${className}` : ''}`} {...rest}>
      {children}
    </Tag>
  );
}
