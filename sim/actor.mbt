///|
pub(all) struct Input {
  axis : Int32
  jump : Bool
  crouch : Bool
} derive(Debug, Eq)

///|
pub fn Input::wait() -> Input {
  { axis: 0, jump: false, crouch: false, }
}

///|
priv struct Actor {
  id : Int32
  mut x : Int32
  mut y : Int32
  mut vy : Int32
  mut grounded : Bool
  mut jump_held : Bool
  mut active : Bool
  mut facing : Int32
  mut walking : Bool
  mut stride : Int32
  mut crouching : Bool
  mut crouch_held : Bool
  mut drop_through_y : Int32
  mut frozen_at : Int32
} derive(Debug, Eq)

///|
fn Actor::new(id : Int32, spawn : Spawn) -> Actor {
  {
    id,
    x: spawn.x,
    y: spawn.y,
    vy: 0,
    grounded: false,
    jump_held: false,
    active: true,
    facing: 1,
    walking: false,
    stride: 0,
    crouching: false,
    crouch_held: false,
    drop_through_y: -1,
    frozen_at: -1,
  }
}

///|
pub(all) struct Rect {
  x : Int32
  y : Int32
  w : Int32
  h : Int32
} derive(Debug, Eq, ToJson)

///|
fn Actor::bounds(self : Actor) -> Rect {
  { x: self.x, y: self.y, w: 240, h: if self.crouching { 240 } else { 380 }, }
}

///|
pub fn Rect::touches(self : Rect, other : Rect) -> Bool {
  self.x < other.x + other.w &&
  self.x + self.w > other.x &&
  self.y < other.y + other.h &&
  self.y + self.h > other.y
}

///|
// All physics uses tenths of a pixel, with one update per 1/60 second.
// Separate X/Y resolution against a stable collider list avoids float drift.
fn Actor::advance(
  self : Actor,
  input : Input,
  solids : Array[Rect],
  drop_platforms~ : ReadOnlyArray[Rect] = [],
) -> Unit {
  guard self.active && self.frozen_at < 0 else { return }
  // S drops only through the supporting one-way platform. A fresh press is
  // required so holding S cannot also drop through a lower platform.
  if input.crouch && !self.crouch_held && self.grounded {
    for platform in drop_platforms {
      if self.y + self.bounds().h == platform.y &&
        self.x < platform.x + platform.w &&
        self.x + 240 > platform.x {
        self.drop_through_y = platform.y + platform.h
        self.grounded = false
        self.vy = 10
        break
      }
    }
  }
  self.crouch_held = input.crouch
  // Keep the feet fixed when changing posture. A low roof or gate prevents
  // standing until the full-height body fits, including during input replay.
  if input.crouch && !self.crouching {
    self.y += 140
    self.crouching = true
  } else if !input.crouch && self.crouching {
    let standing : Rect = { x: self.x, y: self.y - 140, w: 240, h: 380, }
    if !solids.any(solid => standing.touches(solid)) {
      self.y -= 140
      self.crouching = false
    }
  }
  let speed = if self.crouching { 8 } else { 30 }
  let dx = if input.axis > 0 {
    speed
  } else if input.axis < 0 {
    -speed
  } else {
    0
  }
  if dx != 0 {
    self.facing = if dx > 0 { 1 } else { -1 }
  }
  self.x += dx
  for solid in solids {
    if self.bounds().touches(solid) {
      if dx > 0 {
        self.x = solid.x - 240
      }
      if dx < 0 {
        self.x = solid.x + solid.w
      }
    }
  }
  if self.x < 200 {
    self.x = 200
  }
  if self.x > 10760 {
    self.x = 10760
  }
  if input.jump && !self.jump_held && self.grounded && !self.crouching {
    self.vy = -110
  }
  self.jump_held = input.jump
  self.vy += 5
  if self.vy > 150 {
    self.vy = 150
  }
  let previous_feet = self.y + self.bounds().h
  self.y += self.vy
  self.grounded = false
  for solid in solids {
    if self.bounds().touches(solid) {
      if self.vy > 0 {
        self.y = solid.y - self.bounds().h
        self.grounded = true
      } else if self.vy < 0 {
        self.y = solid.y + solid.h
      }
      self.vy = 0
    }
  }
  for platform in drop_platforms {
    if self.vy >= 0 &&
      platform.y >= self.drop_through_y &&
      previous_feet <= platform.y &&
      self.y + self.bounds().h >= platform.y &&
      self.x < platform.x + platform.w &&
      self.x + 240 > platform.x {
      self.y = platform.y - self.bounds().h
      self.vy = 0
      self.grounded = true
    }
  }
  if self.y > self.drop_through_y {
    self.drop_through_y = -1
  }
  // A blocked actor is still trying to walk. The gait follows recorded intent,
  // not displacement, so future door-opening puzzles remain visually readable.
  self.walking = self.grounded && dx != 0
  let stride_ticks = if self.crouching { 64 } else { 32 }
  self.stride = if self.walking { (self.stride + 1) % stride_ticks } else { 0 }
  if self.y > 6800 {
    self.active = false
  }
}
