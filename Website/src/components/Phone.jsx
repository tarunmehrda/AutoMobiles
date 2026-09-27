/** A screenshot in a device bezel. The shots are the apps' own, not mockups. */
export default function Phone({ src, alt, className = '', eager = false }) {
  return (
    <div className={`phone${className ? ` ${className}` : ''}`}>
      <img
        src={src}
        alt={alt}
        width="540"
        height="1148"
        loading={eager ? 'eager' : 'lazy'}
        decoding="async"
        fetchPriority={eager ? 'high' : 'auto'}
      />
    </div>
  );
}
