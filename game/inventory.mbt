///|
fn item_icon(
  image : @asset.ImageHandle,
  x : Double,
  y : Double,
  size : Double,
  ink : @render.Color,
) -> Unit {
  @render2d.push_ui_image({
    image,
    destination: { position: @math.Vec2(x, y), size: @math.Vec2(size, size), },
    source: None,
    transform: @math.Transform(),
    uv_transform: @math.Transform(),
    repeat: NoRepeat,
    alpha_mode: Blend,
    blend_mode: Alpha,
    color: ink,
  })
}

///|
fn pickup_float(tick : Int32) -> Double {
  @trig.sin(tick.to_double() * 6.283185307179586 / 120.0) * 5.0
}

///|
fn draw_pickup_light(
  level : @sim.Level,
  pickup : @sim.Rect,
  tint : UInt32,
) -> Unit {
  let centre = pickup.x + pickup.w / 2
  let mut floor_y = 6200
  for platform in level.platforms {
    if centre >= platform.x &&
      centre < platform.x + platform.w &&
      platform.y >= pickup.y + pickup.h &&
      platform.y < floor_y {
      floor_y = platform.y
    }
  }
  let x = centre.to_double() / 10.0
  let bottom = floor_y.to_double() / 10.0
  let height = bottom - pickup.y.to_double() / 10.0 + 24.0
  // A narrow ground source fans upwards and fades before reaching its top.
  for band in 0..<32 {
    let t = band.to_double() / 32.0
    let width = 10.0 + 28.0 * t
    let alpha = (1.0 - t) * (1.0 - t) * 0.22
    rect(
      x - width / 2.0,
      bottom - height * (t + 1.0 / 32.0),
      width,
      height / 32.0 + 0.1,
      color(tint, alpha~),
    )
  }
  rect(x - 12.0, bottom - 1.0, 24.0, 2.0, color(tint, alpha=0.18))
  rect(x - 5.0, bottom - 1.0, 10.0, 2.0, color(tint, alpha=0.35))
}

///|
fn draw_item_pickups(
  level : @sim.Level,
  inventory : @sim.Inventory,
  icon : @asset.ImageHandle,
  tick : Int32,
) -> Unit {
  for pickup in level.items {
    if !inventory.contains(pickup.kind) {
      draw_pickup_light(level, pickup.bounds, 0x67dfdc)
      item_icon(
        icon,
        pickup.bounds.x.to_double() / 10.0,
        pickup.bounds.y.to_double() / 10.0 + pickup_float(tick),
        30.0,
        color(0x67dfdc),
      )
    }
  }
}

///|
fn draw_inventory(
  inventory : @sim.Inventory,
  icon : @asset.ImageHandle,
  flying : Bool,
) -> Unit {
  // The square exists only for an owned item; there are no empty slots.
  if inventory.time_acceleration {
    let border = color(0x91a5b2, alpha=0.65)
    rect(22.0, 22.0, 56.0, 1.0, border)
    rect(22.0, 77.0, 56.0, 1.0, border)
    rect(22.0, 22.0, 1.0, 56.0, border)
    rect(77.0, 22.0, 1.0, 56.0, border)
    if !flying {
      item_icon(icon, 38.0, 28.0, 24.0, color(0x67dfdc))
    }
    @render2d.push_ui_text({
      text: "SPACE",
      // Integer top-left alignment avoids half-pixel text texture sampling.
      position: @math.Vec2(25.0, 56.0),
      transform: @math.Transform(),
      blend_mode: Alpha,
      style: {
        font: None,
        family: "sans-serif",
        size: 14.0,
        color: color(0xe8eee9),
        align: Left,
        baseline: Top,
      },
    })
  }
}

///|
const ItemFlightDuration : Double = 0.85

///|
priv struct ItemFlight {
  x : Double
  y : Double
  mut elapsed : Double
}

///|
fn draw_item_flight(flight : ItemFlight?, icon : @asset.ImageHandle) -> Unit {
  if flight is Some(flight) {
    let t = flight.elapsed / ItemFlightDuration
    let eased = t * t * (3.0 - 2.0 * t)
    let remaining = 1.0 - eased
    // Lift away from the pickup, then sweep into the inventory along an arc.
    let x = flight.x * remaining + 50.0 * eased
    let y = flight.y * remaining +
      40.0 * eased -
      @trig.sin(eased * 3.141592653589793) * 100.0
    let size = 30.0 - 6.0 * eased
    item_icon(icon, x - size / 2.0, y - size / 2.0, size, color(0x67dfdc))
    present_item_flight(true, x, y)
  } else {
    present_item_flight(false, 50.0, 40.0)
  }
}

///|
fn draw_heart_pickup(
  level : @sim.Level,
  view : @sim.Snapshot,
  heart : @asset.ImageHandle,
) -> Unit {
  if !view.heart_collected && level.heart is Some(heart_pickup) {
    let pickup = heart_pickup.bounds
    draw_pickup_light(level, pickup, 0xed5363)
    @render2d.push_ui_image({
      image: heart,
      destination: {
        position: @math.Vec2(
          pickup.x.to_double() / 10.0,
          pickup.y.to_double() / 10.0 + pickup_float(view.tick),
        ),
        size: @math.Vec2(
          pickup.w.to_double() / 10.0,
          pickup.h.to_double() / 10.0,
        ),
      },
      source: None,
      transform: @math.Transform(),
      uv_transform: @math.Transform(),
      repeat: NoRepeat,
      alpha_mode: Blend,
      blend_mode: Alpha,
      color: color(0xed5363),
    })
  }
}
