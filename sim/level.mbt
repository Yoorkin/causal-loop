///|
pub struct Level {
  id : Int32
  spawn_offset : (Int32, Int32)
  moving_platforms : ReadOnlyArray[MovingPlatform]
  platforms : ReadOnlyArray[Rect]
  ceilings : ReadOnlyArray[Rect]
  drop_platforms : ReadOnlyArray[Rect]
  heart : HeartPickup?
  items : ReadOnlyArray[ItemPickup]
  plate_a : Rect
  plate_b : Rect
  plate_c : Rect
  plate_d : Rect
  gates : ReadOnlyArray[Rect]
  bridge : Rect
  barrier : Rect
  exit : Rect
} derive(Debug, Eq)

///|
// Stable geometry IDs are independent of the player's current room order.
pub fn level_number(id : Int32) -> Int32 {
  match id {
    1 => 2
    3 => 3
    2 => 4
    4 => 5
    6 => 6
    _ => 1
  }
}

///|
pub fn level_for_number(number : Int32) -> Int32 {
  match number {
    2 => 1
    3 => 3
    4 => 2
    5 => 4
    6 => 6
    _ => 0
  }
}

///|
pub fn level_geometry(id : Int32) -> Level {
  let empty : Rect = { x: 0, y: 0, w: 0, h: 0, }
  if id == 6 {
    return stack_room_geometry()
  }
  if id == 4 {
    return {
      id,
      spawn_offset: (-1200, 600),
      moving_platforms: [],
      platforms: [
        { x: 200, y: 5600, w: 10800, h: 600, },
        { x: 9600, y: 4800, w: 1400, h: 800, },
      ],
      ceilings: [
        { x: 0, y: -2000, w: 200, h: 8200, },
        { x: 11000, y: -2000, w: 200, h: 8200, },
      ],
      drop_platforms: [],
      heart: Some({
        id: "crate-room-heart-container",
        bounds: { x: 9700, y: 4400, w: 280, h: 280, },
      }),
      items: [],
      plate_a: empty,
      plate_b: empty,
      plate_c: empty,
      plate_d: empty,
      gates: [],
      bridge: empty,
      barrier: empty,
      exit: { x: 10100, y: 4200, w: 500, h: 600, },
    }
  }
  if id == 0 {
    return {
      id,
      spawn_offset: (0, 0),
      moving_platforms: [],
      platforms: [
        { x: 200, y: 5000, w: 3800, h: 1200, },
        { x: 4000, y: 4300, w: 1800, h: 1900, },
        { x: 5800, y: 3500, w: 200, h: 2700, },
        { x: 6000, y: 5600, w: 5000, h: 600, },
      ],
      ceilings: [
        { x: 8000, y: 3500, w: 500, h: 1800, },
        { x: 8500, y: 3500, w: 2500, h: 1400, },
        { x: 10800, y: 1000, w: 200, h: 4600, },
      ],
      drop_platforms: [{ x: 6000, y: 3500, w: 2000, h: 80, }],
      heart: Some({
        id: "entry-heart-container",
        bounds: { x: 9400, y: 5140, w: 280, h: 280, },
      }),
      items: [],
      plate_a: empty,
      plate_b: empty,
      plate_c: empty,
      plate_d: empty,
      gates: [],
      bridge: empty,
      barrier: empty,
      exit: { x: 10100, y: 5000, w: 500, h: 600, },
    }
  }
  if id == 3 {
    return {
      id,
      spawn_offset: (0, 0),
      moving_platforms: [],
      platforms: [
        // Continuous ground; three elevated controls; uneven tunnel floor.
        { x: 200, y: 5000, w: 10800, h: 800, },
        { x: 700, y: 4200, w: 1100, h: 160, },
        { x: 2300, y: 3400, w: 1100, h: 160, },
        { x: 6500, y: 4500, w: 1400, h: 500, },
        { x: 7900, y: 4800, w: 700, h: 200, },
        { x: 8600, y: 4200, w: 1100, h: 800, },
      ],
      // The roof is too high to jump onto from the control platforms.
      ceilings: [
        { x: 5200, y: 1100, w: 1300, h: 2700, },
        { x: 6500, y: 1100, w: 1400, h: 2400, },
        { x: 7900, y: 1100, w: 700, h: 2600, },
        { x: 8600, y: 1100, w: 1100, h: 2100, },
      ],
      drop_platforms: [],
      heart: None,
      items: [],
      plate_a: { x: 900, y: 4140, w: 700, h: 60, },
      plate_b: { x: 2500, y: 3340, w: 700, h: 60, },
      plate_c: { x: 6700, y: 4440, w: 700, h: 60, },
      plate_d: empty,
      gates: [
        { x: 5800, y: 3800, w: 200, h: 1200, },
        { x: 7500, y: 3500, w: 200, h: 1000, },
        { x: 9200, y: 3200, w: 200, h: 1000, },
      ],
      bridge: empty,
      barrier: empty,
      exit: { x: 10100, y: 4400, w: 500, h: 600, },
    }
  }
  if id == 2 {
    return {
      id,
      spawn_offset: (-1200, -2500),
      moving_platforms: [
        {
          bounds: { x: 5900, y: 4800, w: 900, h: 160, },
          travel_x: 3000,
          travel_ticks: 300,
          pause_ticks: 30,
          phase: 300,
        },
      ],
      platforms: [
        { x: 200, y: 2500, w: 1400, h: 3300, },
        { x: 1600, y: 3300, w: 700, h: 2500, },
        { x: 2300, y: 4100, w: 700, h: 1700, },
        { x: 3000, y: 4800, w: 2900, h: 1000, },
        // A 130-pixel roof leaves 30 pixels above the lower floor: crouch only.
        { x: 3300, y: 2500, w: 1300, h: 2000, },
        { x: 4600, y: 2500, w: 6400, h: 1200, },
        { x: 9800, y: 4800, w: 1200, h: 1000, },
      ],
      ceilings: [
        { x: 5300, y: 800, w: 5700, h: 400, },
        { x: 10800, y: 800, w: 200, h: 4000, },
      ],
      drop_platforms: [{ x: 1600, y: 2500, w: 1700, h: 80, }],
      heart: None,
      items: [],
      // Lower left opens the upper entrance; upper middle opens the lower gate;
      // lower right opens the upper exit. The two lives help each other.
      plate_a: { x: 4700, y: 4740, w: 600, h: 60, },
      plate_b: { x: 6800, y: 2440, w: 800, h: 60, },
      plate_c: { x: 9900, y: 4740, w: 800, h: 60, },
      // This reachable upper plate also opens the adjacent upper entrance.
      plate_d: { x: 4000, y: 2440, w: 800, h: 60, },
      gates: [
        { x: 5300, y: 1200, w: 200, h: 1300, },
        { x: 5300, y: 3700, w: 200, h: 1100, },
        { x: 8500, y: 1200, w: 200, h: 1300, },
      ],
      bridge: empty,
      barrier: empty,
      exit: { x: 10100, y: 1900, w: 500, h: 600, },
    }
  }
  {
    id,
    spawn_offset: (0, 0),
    moving_platforms: [],
    platforms: [
      { x: 200, y: 5000, w: 4200, h: 800, },
      { x: 7000, y: 5000, w: 4000, h: 800, },
    ],
    ceilings: [],
    drop_platforms: [],
    heart: None,
    items: [
      { kind: TimeAcceleration, bounds: { x: 3700, y: 4520, w: 300, h: 300, }, },
    ],
    plate_a: { x: 900, y: 4940, w: 700, h: 60, },
    plate_b: empty,
    plate_c: empty,
    plate_d: empty,
    gates: [],
    bridge: { x: 4400, y: 5000, w: 2600, h: 160, },
    barrier: { x: 4160, y: 2400, w: 160, h: 2600, },
    exit: { x: 10100, y: 4400, w: 500, h: 600, },
  }
}

///|
fn on_plate(actor : Actor, plate : Rect) -> Bool {
  actor.active &&
  actor.grounded &&
  (actor.y + actor.bounds().h - plate.y - plate.h).abs() <= 15 &&
  actor.x < plate.x + plate.w &&
  actor.x + 240 > plate.x
}

///|
// Opening is normalized to 0..1200 so all doors share the same travel time.
pub fn gate_body(gate : Rect, opening : Int32) -> Rect {
  { ..gate, h: gate.h * (1200 - opening) / 1200, }
}

///|
fn Game::colliders(self : Game) -> Array[Rect] {
  let level = level_geometry(self.level)
  let result = [ for platform in level.platforms => platform ]
  for ceiling in level.ceilings {
    result.push(ceiling)
  }
  if !level.gates.is_empty() {
    for i, gate in level.gates {
      let body = gate_body(gate, self.gate_openings[i])
      if body.h > 0 {
        result.push(body)
      }
    }
  } else if self.level == 1 {
    if self.bridge_open && self.level == 1 {
      result.push(level.bridge)
    }
    if !self.bridge_open &&
      !self.actors.any(a => a.active && a.bounds().touches(level.barrier)) {
      result.push(level.barrier)
    }
  }
  result
}

///|
fn Game::resolve_puzzle(self : Game) -> Unit {
  let level = level_geometry(self.level)
  self.collect_items(level.items)
  if !self.heart_collected &&
    level.heart is Some(heart) &&
    self.actors.any(a => {
      a.active && a.frozen_at < 0 && a.bounds().touches(heart.bounds)
    }) {
    self.heart_collected = true
    // A container expands capacity, not this attempt's remaining lives.
    self.max_lives += 1
    let collected = [ for id in self.collected_hearts => id ]
    collected.push(heart.id)
    self.collected_hearts = ReadOnlyArray::from_array(collected)
  }
  // All actors move first; switches are reduced together, independent of order.
  self.plate_a = self.actors.any(a => on_plate(a, level.plate_a)) ||
    self.crates.any(b => crate_on_plate(b.bounds, level.plate_a))
  self.plate_b = self.actors.any(a => on_plate(a, level.plate_b)) ||
    self.crates.any(b => crate_on_plate(b.bounds, level.plate_b))
  self.plate_c = self.actors.any(a => on_plate(a, level.plate_c)) ||
    self.crates.any(b => crate_on_plate(b.bounds, level.plate_c))
  self.plate_d = self.actors.any(a => on_plate(a, level.plate_d))
  if !level.gates.is_empty() {
    let pressed = [self.plate_a || self.plate_d, self.plate_b, self.plate_c]
    for i, gate in level.gates {
      let close_step = if self.level == 6 && i < 2 { 4 } else { 10 }
      let before = self.gate_openings[i]
      let after = if pressed[i] {
        if before + 60 > 1200 {
          1200
        } else {
          before + 60
        }
      } else if before < close_step {
        0
      } else {
        before - close_step
      }
      let body = gate_body(gate, after)
      // Closing starts on release. Pause only if the next position would crush
      // a body; rendering and collision use exactly the same door geometry.
      if after >= before ||
        (
          !self.actors.any(a => {
            let r = a.bounds()
            let padded = if self.level == 6 {
              { ..r, y: r.y - 12, h: r.h + 12, }
            } else {
              r
            }
            a.active && padded.touches(body)
          }) &&
          !self.crates.any(b => b.bounds.touches(body))
        ) {
        self.gate_openings[i] = after
      }
    }
  } else {
    self.bridge_open = self.plate_a && (self.level == 1 || self.plate_b)
  }
}

///|
fn crate_on_plate(box : Rect, plate : Rect) -> Bool {
  plate.w > 0 &&
  (box.y + box.h - plate.y - plate.h).abs() <= 15 &&
  box.x < plate.x + plate.w &&
  box.x + box.w > plate.x
}
