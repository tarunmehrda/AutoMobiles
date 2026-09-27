/** A <use> into the sprite mounted by <IconSprite />. */
export default function Icon({ name, size = 20, className }) {
  return (
    <svg width={size} height={size} className={className} aria-hidden="true" focusable="false">
      <use href={`#${name}`} />
    </svg>
  );
}
