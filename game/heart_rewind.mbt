///|
const HeartDepartDelay : Double = 0.2

///|
const HeartTravelDuration : Double = 0.8

///|
const HeartBlinkDuration : Double = 0.6

///|
priv struct HeartFlight {
  x : Double
  y : Double
  size : Double
  opacity : Double
  phase : String
}

///|
fn heart_flight(elapsed : Double, teaching : Bool) -> HeartFlight {
  let hidden : HeartFlight = {
    x: 560.0,
    y: 310.0,
    size: 36.0,
    opacity: 0.0,
    phase: "none",
  }
  if !teaching {
    return hidden
  }
  if elapsed < HeartDepartDelay {
    return { ..hidden, phase: "waiting", }
  }
  if elapsed < HeartDepartDelay + HeartTravelDuration {
    let t = (elapsed - HeartDepartDelay) / HeartTravelDuration
    let eased = t * t * (3.0 - 2.0 * t)
    return {
      x: 576.0 - 16.0 * eased + @trig.sin(t * 3.141592653589793) * 52.0,
      y: 40.0 + 270.0 * eased,
      size: 24.0 + 12.0 * eased,
      opacity: 1.0,
      phase: "flying",
    }
  }
  let t = (elapsed - HeartDepartDelay - HeartTravelDuration) /
    HeartBlinkDuration
  if t >= 1.0 {
    return hidden
  }
  let pulse = 0.2 + 0.8 * (0.5 + 0.5 * @trig.cos(t * 12.566370614359172))
  let vanish = if t > 0.75 { (1.0 - t) / 0.25 } else { 1.0 }
  { ..hidden, opacity: pulse * vanish, phase: "blinking", }
}

///|
fn draw_heart_flight(flight : HeartFlight, heart : @asset.ImageHandle) -> Unit {
  guard flight.opacity > 0.0 else { return }
  @render2d.push_ui_image({
    image: heart,
    destination: {
      position: @math.Vec2(
        flight.x - flight.size / 2.0,
        flight.y - flight.size / 2.0,
      ),
      size: @math.Vec2(flight.size, flight.size),
    },
    source: None,
    transform: @math.Transform(),
    uv_transform: @math.Transform(),
    repeat: NoRepeat,
    alpha_mode: Blend,
    blend_mode: Alpha,
    color: color(0xed5363, alpha=flight.opacity),
  })
}

///|
// The heart is drawn by Selene. Only mask out the inverse clock behind it.
extern "js" fn present_heart_flight(
  x : Double,
  y : Double,
  size : Double,
  opacity : Double,
  phase : String,
) -> Unit =
  #|(x, y, size, opacity, phase) => {
  #|  const mask = document.getElementById('clock-heart-mask');
  #|  mask.setAttribute('transform', `translate(${x - size/2 - 516} ${y - size/2 - 266}) scale(${size/24})`);
  #|  mask.setAttribute('opacity', String(opacity));
  #|  const d = document.getElementById('canvas').dataset;
  #|  d.heartFlightPhase = phase; d.heartFlightX = String(x); d.heartFlightY = String(y);
  #|  d.heartFlightSize = String(size); d.heartFlightOpacity = String(opacity);
  #|}
