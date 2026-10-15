///|
pub struct Level {
  id : Int32
  platforms : ReadOnlyArray[Rect]
  ceilings : ReadOnlyArray[Rect]
  drop_platforms : ReadOnlyArray[Rect]
  heart : Rect?
  items : ReadOnlyArray[ItemPickup]
  plate_a : Rect
  plate_b : Rect
  plate_c : Rect
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
    _ => 1
  }
}

///|
pub fn level_for_number(number : Int32) -> Int32 {
  match number {
    2 => 1
    3 => 3
    4 => 2
    _ => 0
  }
}

///|
pub fn level_geometry(id : Int32) -> Level {
  let empty : Rect = { x: 0, y: 0, w: 0, h: 0, }
  if id == 0 {
    return {
      id,
      platforms: [
        { x: 200, y: 5000, w: 3800, h: 1200, },
        { x: 4000, y: 4300, w: 1800, h: 1900, },
        { x: 5800, y: 3500, w: 200, h: 2700, },
        { x: 6000, y: 5600, w: 5000, h: 600, },
      ],
      ceilings: [
        { x: 8000, y: 3500, w: 3000, h: 1400, },
        { x: 10800, y: 1000, w: 200, h: 4600, },
      ],
      drop_platforms: [{ x: 6000, y: 3500, w: 2000, h: 80, }],
      heart: Some({ x: 9400, y: 5140, w: 280, h: 280, }),
      items: [],
      plate_a: empty,
      plate_b: empty,
      plate_c: empty,
      gates: [],
      bridge: empty,
      barrier: empty,
      exit: { x: 10100, y: 5000, w: 500, h: 600, },
    }
  }
  if id == 3 {
    return {
      id,
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
  {
    id,
    platforms: if id == 2 {
      [{ x: 200, y: 5000, w: 10800, h: 800, }]
    } else {
      [
        { x: 200, y: 5000, w: 4200, h: 800, },
        { x: 7000, y: 5000, w: 4000, h: 800, },
      ]
    },
    ceilings: [],
    drop_platforms: [],
    heart: None,
    items: if id == 1 {
      [
        {
          kind: TimeAcceleration,
          bounds: { x: 9500, y: 4520, w: 300, h: 300, },
        },
      ]
    } else {
      []
    },
    plate_a: { x: 900, y: 4940, w: 700, h: 60, },
    plate_b: { x: 5700, y: 4940, w: 1000, h: 60, },
    plate_c: empty,
    gates: [],
    bridge: if id == 2 {
      empty
    } else {
      { x: 4400, y: 5000, w: 2600, h: 160, }
    },
    barrier: { x: if id == 2 { 8800 } else { 4160 }, y: 2400, w: 160, h: 2600, },
    exit: { x: 10100, y: 4400, w: 500, h: 600, },
  }
}

///|
fn on_plate(actor : Actor, plate : Rect) -> Bool {
  actor.active &&
  actor.grounded &&
  actor.y + actor.bounds().h == plate.y + plate.h &&
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
  if self.level == 3 {
    for i, gate in level.gates {
      let body = gate_body(gate, self.gate_openings[i])
      if body.h > 0 {
        result.push(body)
      }
    }
  } else if self.level > 0 {
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
      a.active && a.frozen_at < 0 && a.bounds().touches(heart)
    }) {
    self.heart_collected = true
    self.max_lives += 1
  }
  // All actors move first; switches are reduced together, independent of order.
  self.plate_a = self.actors.any(a => on_plate(a, level.plate_a))
  self.plate_b = self.level > 1 &&
    self.actors.any(a => on_plate(a, level.plate_b))
  self.plate_c = self.level == 3 &&
    self.actors.any(a => on_plate(a, level.plate_c))
  if self.level == 3 {
    let pressed = [self.plate_a, self.plate_b, self.plate_c]
    for i, gate in level.gates {
      let before = self.gate_openings[i]
      let after = if pressed[i] {
        if before + 60 > 1200 {
          1200
        } else {
          before + 60
        }
      } else if before < 10 {
        0
      } else {
        before - 10
      }
      let body = gate_body(gate, after)
      // Closing starts on release. Pause only if the next position would crush
      // a body; rendering and collision use exactly the same door geometry.
      if after >= before ||
        !self.actors.any(a => a.active && a.bounds().touches(body)) {
        self.gate_openings[i] = after
      }
    }
  } else {
    self.bridge_open = self.plate_a && (self.level == 1 || self.plate_b)
  }
}
