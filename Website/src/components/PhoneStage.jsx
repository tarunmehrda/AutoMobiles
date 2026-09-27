import Phone from './Phone.jsx';

/**
 * The hero's pair of handsets.
 *
 * Both screens stay flat and unrotated in depth, so the screenshots render at
 * their native pixels and the app's type stays readable. The sense of a solid
 * object comes from the frame — see `.phone` in the stylesheet — rather than
 * from turning the screen away from the viewer.
 */
export default function PhoneStage({ front, back }) {
  return (
    <div className="phone-pair">
      <div className="phone-stage">
        <Phone className="phone--back" src={back.src} alt={back.alt} eager />
        <Phone className="phone--front" src={front.src} alt={front.alt} eager />
      </div>
    </div>
  );
}
