///|
priv struct TutorialGuide {
  mut walked_left : Bool
  mut left_distance : Int32
  mut key : String
  mut animation_tick : Int32
}

///|
fn TutorialGuide::new() -> TutorialGuide {
  { walked_left: false, left_distance: 0, key: "", animation_tick: 0, }
}

///|
priv struct TutorialHint {
  key : String
  x : Double
  y : Double
  opacity : Double
}

///|
fn hint_proximity(x : Int32, left : Int32, right : Int32) -> Double {
  if x <= left || x >= right {
    0.0
  } else if x < left + 240 {
    (x - left).to_double() / 240.0
  } else if x > right - 240 {
    (right - x).to_double() / 240.0
  } else {
    1.0
  }
}

///|
fn tutorial_hint(view : @sim.Snapshot, walked_left : Bool) -> TutorialHint? {
  guard view.level == 0 && view.outcome == @sim.Playing else { return None }
  let actor = view.actors[view.life - 1]
  guard actor.active && actor.frozen_at < 0 else { return None }
  let feet = actor.y + (if actor.crouching { 240 } else { 380 })
  let x = actor.x + 120
  if actor.grounded && feet == 5000 && x > 2980 && x < 4220 {
    Some({
      key: "W",
      x: 354.0,
      y: 410.0,
      opacity: hint_proximity(x, 2980, 4220),
    })
  } else if actor.grounded && feet == 4300 && x > 4780 && x < 6020 {
    Some({
      key: "W",
      x: 510.0,
      y: 365.0,
      opacity: hint_proximity(x, 4780, 6020),
    })
  } else if actor.grounded && feet == 3500 && x > 6000 && x < 8080 {
    Some({
      key: "S",
      x: 700.0,
      y: 266.0,
      opacity: hint_proximity(x, 6000, 8080),
    })
  } else if actor.grounded && feet == 5600 && x > 7000 && x < 8740 {
    Some({
      key: "S + D",
      x: 740.0,
      y: 492.0,
      opacity: hint_proximity(x, 7000, 8740),
    })
  } else if feet >= 4200 && feet <= 5000 && x > 600 && x < 3220 {
    Some({
      key: if walked_left {
        "D"
      } else {
        "A"
      },
      x: 225.0,
      y: 408.0,
      opacity: hint_proximity(x, 600, 3220),
    })
  } else {
    None
  }
}

///|
fn TutorialGuide::advance(
  self : TutorialGuide,
  before : @sim.Snapshot,
  after : @sim.Snapshot,
) -> Unit {
  guard before.level == 0 && after.level == 0 && before.life == after.life else {
    return
  }
  // Only movement of the controlled character advances the lesson. Replays
  // and randomized respawn positions cannot complete it on the player's behalf.
  let previous = before.actors[before.life - 1]
  let current = after.actors[after.life - 1]
  if !self.walked_left && previous.x > current.x && current.active {
    self.left_distance += previous.x - current.x
    if self.left_distance >= 360 {
      self.walked_left = true
    }
  }
  let key = if tutorial_hint(after, self.walked_left) is Some(hint) {
    hint.key
  } else {
    ""
  }
  if self.key != key {
    self.key = key
    self.animation_tick = 0
  } else if key != "" {
    self.animation_tick += after.tick - before.tick
  }
}

///|
fn tutorial_key_depth(tick : Int32) -> Double {
  let phase = tick % 72
  let t = if phase < 8 {
    phase.to_double() / 8.0
  } else if phase < 26 {
    1.0
  } else if phase < 36 {
    (36 - phase).to_double() / 10.0
  } else {
    0.0
  }
  t * t * (3.0 - 2.0 * t)
}

///|
fn draw_tutorial_hint(guide : TutorialGuide, view : @sim.Snapshot) -> Unit {
  guard tutorial_hint(view, guide.walked_left) is Some(hint) else {
    present_tutorial_hint("", 0.0)
    return
  }
  let held = match hint.key {
    "A" => @inputs.is_pressed(KeyA) || @inputs.is_pressed(ArrowLeft)
    "D" => @inputs.is_pressed(KeyD) || @inputs.is_pressed(ArrowRight)
    "W" => @inputs.is_pressed(KeyW)
    "S" => @inputs.is_pressed(KeyS)
    "S + D" =>
      @inputs.is_pressed(KeyS) &&
      (@inputs.is_pressed(KeyD) || @inputs.is_pressed(ArrowRight))
    _ => false
  }
  let depth = if held { 1.0 } else { tutorial_key_depth(guide.animation_tick) }
  if hint.key == "S + D" {
    draw_tutorial_key("S", hint.x - 34.0, hint.y, hint.opacity, depth)
    draw_tutorial_key("D", hint.x + 34.0, hint.y, hint.opacity, depth)
    @render2d.push_ui_text({
      text: "+",
      position: @math.Vec2(hint.x, hint.y + 5.0),
      transform: @math.Transform(),
      blend_mode: Alpha,
      style: {
        font: None,
        family: "sans-serif",
        size: 22.0,
        color: { r: 179, g: 195, b: 204, a: hint.opacity * 0.8, },
        align: Center,
        baseline: Center,
      },
    })
  } else {
    draw_tutorial_key(hint.key, hint.x, hint.y, hint.opacity, depth)
  }
  present_tutorial_hint(hint.key, depth)
}

///|
fn draw_tutorial_key(
  key : String,
  center_x : Double,
  center_y : Double,
  opacity : Double,
  depth : Double,
) -> Unit {
  let offset = (depth * 10.0).to_int().to_double()
  let ink = color(0xb3c3cc, alpha=opacity * (0.55 + depth * 0.35))
  let x = center_x - 22.0
  let y = center_y - 22.0 + offset
  // The fixed base and collapsing side wall make the press readable in place.
  rect(x, y + 44.0, 44.0, 10.0 - offset, color(0x708b98, alpha=opacity * 0.4))
  rect(x, center_y + 32.0, 44.0, 2.0, ink)
  rect(x, y, 44.0, 44.0, color(0xb3c3cc, alpha=opacity * (0.06 + depth * 0.72)))
  rect(x, y, 44.0, 2.0, ink)
  rect(x, y + 42.0, 44.0, 2.0, ink)
  rect(x, y, 2.0, 44.0, ink)
  rect(x + 42.0, y, 2.0, 44.0, ink)
  @render2d.push_ui_text({
    text: key,
    position: @math.Vec2(center_x, center_y + offset),
    transform: @math.Transform(),
    blend_mode: Alpha,
    style: {
      font: None,
      family: "sans-serif",
      size: 26.0,
      color: {
        r: (179.0 - depth * 155.0).to_uint(),
        g: (195.0 - depth * 159.0).to_uint(),
        b: (204.0 - depth * 160.0).to_uint(),
        a: opacity * (0.65 + depth * 0.35),
      },
      align: Center,
      baseline: Center,
    },
  })
}
