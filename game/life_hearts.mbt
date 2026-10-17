///|
fn life_hearts(
  view : @sim.Snapshot,
  filled : @asset.ImageHandle,
  empty : @asset.ImageHandle,
) -> Unit {
  let left = 560.0 - (view.max_lives.to_double() * 32.0 - 8.0) / 2.0
  for slot in 0..<view.max_lives {
    @render2d.push_ui_image({
      image: if slot < view.remaining_lives {
        filled
      } else {
        empty
      },
      destination: {
        position: @math.Vec2(left + slot.to_double() * 32.0, 28.0),
        size: @math.Vec2(24.0, 24.0),
      },
      source: None,
      transform: @math.Transform(),
      uv_transform: @math.Transform(),
      repeat: NoRepeat,
      alpha_mode: Blend,
      blend_mode: Alpha,
      color: if slot < view.remaining_lives {
        color(0xed5363)
      } else {
        color(0x70818c, alpha=0.7)
      },
    })
  }
}
