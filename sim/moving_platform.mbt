///|
pub struct MovingPlatform {
  bounds : Rect
  travel_x : Int32
  travel_ticks : Int32
  pause_ticks : Int32
  phase : Int32
} derive(Debug, Eq)

///|
// Derived from simulation time: rewinds and accelerated batches share the same
// path, without accumulating rounding errors or storing a second clock.
pub fn MovingPlatform::at(self : MovingPlatform, tick : Int32) -> Rect {
  let half_cycle = self.travel_ticks + self.pause_ticks
  let phase = (tick + self.phase) % (half_cycle * 2)
  // Left dock -> outbound -> right dock -> inbound. Pauses belong to the
  // simulation timeline, so riders, history and 6x playback stay synchronized.
  let distance = if phase < self.pause_ticks {
    0
  } else if phase < half_cycle {
    phase - self.pause_ticks
  } else if phase < half_cycle + self.pause_ticks {
    self.travel_ticks
  } else {
    half_cycle * 2 - phase
  }
  {
    ..self.bounds,
    x: self.bounds.x + self.travel_x * distance / self.travel_ticks,
  }
}

///|
fn Actor::ride_platform(
  self : Actor,
  before : Rect,
  after : Rect,
  solids : Array[Rect],
) -> Unit {
  guard self.active && self.frozen_at < 0 else { return }
  let supported = self.grounded &&
    self.y + self.bounds().h == before.y &&
    self.x < before.x + before.w &&
    self.x + 240 > before.x
  let dx = after.x - before.x
  if supported {
    self.x += dx
  } else if self.bounds().touches(after) {
    if dx > 0 {
      self.x = after.x + after.w
    } else if dx < 0 {
      self.x = after.x - 240
    }
  } else {
    return
  }
  for solid in solids {
    if self.bounds().touches(solid) {
      if dx > 0 {
        self.x = solid.x - 240
      } else if dx < 0 {
        self.x = solid.x + solid.w
      }
    }
  }
}
