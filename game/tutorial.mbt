///|
fn draw_tutorial(
  level : @sim.Level,
  view : @sim.Snapshot,
  heart : @asset.ImageHandle,
) -> Unit {
  for ceiling in level.ceilings {
    scene_rect(ceiling, color(0x30434f))
    rect(
      ceiling.x.to_double() / 10.0,
      ceiling.y.to_double() / 10.0,
      ceiling.w.to_double() / 10.0,
      3.0,
      color(0x708b98),
    )
  }
  for platform in level.drop_platforms {
    let x = platform.x.to_double() / 10.0
    let y = platform.y.to_double() / 10.0
    rect(x, y, platform.w.to_double() / 10.0, 8.0, color(0x67dfdc, alpha=0.12))
    for i in 0..<(platform.w / 160) {
      rect(x + i.to_double() * 16.0, y, 10.0, 3.0, color(0x67dfdc))
    }
    // Small descending marks distinguish a permeable ledge from solid stone.
    for i in 0..<3 {
      rect(
        x + platform.w.to_double() / 20.0 - 6.0 + i.to_double() * 2.0,
        y + 15.0 + i.to_double() * 3.0,
        12.0 - i.to_double() * 4.0,
        2.0,
        color(0x67dfdc, alpha=0.65),
      )
    }
  }
  if !view.heart_collected && level.heart is Some(pickup) {
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
