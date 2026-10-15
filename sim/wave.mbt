///|
const WaveStartTick : Int32 = 1080

///|
const WaveTravelTicks : Int32 = 12

///|
const WaveEndTick : Int32 = WaveStartTick + WaveTravelTicks

///|
// Tenths of a pixel, shared by the rendered edge and collision detection.
// The small charging disc is harmless. Only the outward sweep freezes bodies.
fn wave_radius(tick : Int32) -> Int32 {
  if tick <= WaveStartTick {
    340 * tick / WaveStartTick
  } else if tick >= WaveEndTick {
    6440
  } else {
    // Accelerating impact: 70% linear + 30% cubic ease-in. A strong initial
    // velocity launches the edge immediately, then it keeps gaining speed.
    // All intermediates fit Int32 with the 12-tick (0.2-second) impact.
    let elapsed = tick - WaveStartTick
    let total = WaveTravelTicks * WaveTravelTicks * WaveTravelTicks
    340 +
    4270 * elapsed / WaveTravelTicks +
    1830 * elapsed * elapsed * elapsed / total
  }
}

///|
fn wave_touches(body : Rect, radius : Int32) -> Bool {
  let dx = if 5600 < body.x {
    body.x - 5600
  } else if 5600 > body.x + body.w {
    5600 - body.x - body.w
  } else {
    0
  }
  let dy = if 3100 < body.y {
    body.y - 3100
  } else if 3100 > body.y + body.h {
    3100 - body.y - body.h
  } else {
    0
  }
  dx * dx + dy * dy <= radius * radius
}

///|
fn Game::freeze_swept_actors(self : Game, tick : Int32) -> Unit {
  guard tick > WaveStartTick else { return }
  let radius = wave_radius(tick)
  for actor in self.actors {
    if actor.active &&
      actor.frozen_at < 0 &&
      wave_touches(actor.bounds(), radius) {
      actor.frozen_at = tick
    }
  }
}
