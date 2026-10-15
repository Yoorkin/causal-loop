///|
// Selene 0.37.3 Code omits Backspace and digits. Forward only
// these missing keys and focus events; gameplay stays entirely in MoonBit.
extern "js" fn browser_events(
  key : (String, Bool) -> Unit,
  blur : () -> Unit,
) -> Unit =
  #|(key, blur) => {
  #|  for (const type of ['keydown', 'keyup']) window.addEventListener(type, e => {
  #|    if (['Backspace', 'Digit1', 'Digit2', 'Digit3', 'Digit4'].includes(e.code)) {
  #|      e.preventDefault();
  #|      if (!e.repeat) key(e.code, type === 'keydown');
  #|    }
  #|  });
  #|  window.addEventListener('blur', blur);
  #|  document.addEventListener('visibilitychange', () => { if (document.hidden) blur(); });
  #|}

///|
// Read-only diagnostics for browser QA, published from MoonBit snapshots.
extern "js" fn publish_view(
  state : String,
  mode : String,
  speed : Int32,
  game_over_opacity : Double,
  debug : Bool,
) -> Unit =
  #|(state, mode, speed, gameOverOpacity, debug) => {
  #|  const c = document.getElementById('canvas');
  #|  c.dataset.state = state; c.dataset.mode = mode; c.dataset.speed = String(speed);
  #|  c.dataset.gameOverOpacity = String(gameOverOpacity);
  #|  c.dataset.debug = String(debug);
  #|  document.getElementById('boot').hidden = true;
  #|}

///|
// Entropy is sampled only when creating a fresh level. Simulation/replays
// consume the resulting immutable spawn choices, never browser randomness.
extern "js" fn spawn_seed() -> UInt32 =
  #|() => Math.floor(Math.random() * 4294967296)

///|
extern "js" fn browser_debug(changed : (Bool) -> Unit) -> Unit =
  #|changed => {
  #|  const checkbox = document.getElementById('debug-mode');
  #|  checkbox.checked = false;
  #|  checkbox.addEventListener('change', () => changed(checkbox.checked));
  #|}

///|
extern "js" fn present_item_flight(
  flying : Bool,
  x : Double,
  y : Double,
) -> Unit =
  #|(flying, x, y) => {
  #|  const c = document.getElementById('canvas');
  #|  c.dataset.itemFlying = String(flying);
  #|  c.dataset.itemFlightX = String(x);
  #|  c.dataset.itemFlightY = String(y);
  #|}

///|
// Only clock-stroke difference compositing and read-only diagnostics.
// Selene renders the wave beneath the actors; all geometry/time is MoonBit-owned.
extern "js" fn present_time_wave(
  radius : Double,
  strength : Double,
  progress : Double,
  hour_degrees : Double,
  simulation_tick : Int32,
  phase : String,
  clock_path : String,
  shake_x : Double,
  shake_y : Double,
) -> Unit =
  #|(radius, strength, progress, hour, tick, phase, clockPath, shakeX, shakeY) => {
  #|  document.getElementById('clock-shape').setAttribute('d', clockPath);
  #|  const charge = document.getElementById('charge-disc');
  #|  const clock = document.getElementById('loop-clock');
  #|  for (const layer of [clock, charge]) {
  #|    layer.style.left = `${50 + shakeX * 100 / 1120}%`;
  #|    layer.style.top = `${50 + shakeY * 100 / 620}%`;
  #|  }
  #|  charge.style.width = `${radius * 200 / 1120}%`;
  #|  charge.style.visibility = ['growing', 'resetting'].includes(phase) ? 'visible' : 'hidden';
  #|  const c = document.getElementById('canvas');
  #|  c.dataset.waveRadius = String(radius);
  #|  c.dataset.waveStrength = String(strength);
  #|  c.dataset.wavePhase = phase;
  #|  c.dataset.minuteDegrees = String(progress * 360);
  #|  c.dataset.hourDegrees = String(hour);
  #|  c.dataset.simulationTick = String(tick);
  #|  c.dataset.clockShakeX = String(shakeX);
  #|  c.dataset.clockShakeY = String(shakeY);
  #|}
