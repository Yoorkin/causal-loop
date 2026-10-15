///|
// SVG poses use antialiased round strokes at 4x resolution. The simulation
// chooses the gait frame even at a wall; the same atlas serves every life.
fn draw_actor(
  actor : @sim.ActorView,
  image : @asset.ImageHandle,
  x : Double,
  y : Double,
  tick : Int32,
  current : Bool,
) -> Unit {
  let ink = if !current || actor.frozen_at >= 0 {
    color(0xa5a0b5, alpha=0.9)
  } else {
    color(0xefbf67)
  }
  let tick = if actor.frozen_at >= 0 { actor.frozen_at } else { tick }
  let idle_frame = (tick + actor.id * 23) % 120 * 32 / 120
  let frame = if actor.crouching {
    if actor.walking {
      98 + actor.stride / 2
    } else {
      66 + idle_frame
    }
  } else if !actor.grounded {
    if actor.vy < 0 {
      64
    } else {
      65
    }
  } else if actor.walking {
    32 + actor.stride
  } else {
    idle_frame
  }
  let transform = if actor.facing < 0 {
    // Selene transforms the image locally, relative to destination.position.
    @math.Transform(a=-1.0, tx=32.0)
  } else {
    @math.Transform()
  }
  let image_y = if actor.crouching { y - 22.0 } else { y - 8.0 }
  @render2d.push_ui_image({
    image,
    destination: {
      position: @math.Vec2(x - 4.0, image_y),
      size: @math.Vec2(32.0, 48.0),
    },
    source: Some({
      position: @math.Vec2(
        (frame % 16 * 128).to_double(),
        (frame / 16 * 192).to_double(),
      ),
      size: @math.Vec2(128.0, 192.0),
    }),
    transform,
    uv_transform: @math.Transform(),
    repeat: NoRepeat,
    alpha_mode: Blend,
    blend_mode: Alpha,
    color: ink,
  })
  if current {
    rect(x + 9.0, y - 7.0, 6.0, 2.0, ink)
  }
}
