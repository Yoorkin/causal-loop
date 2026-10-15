///|
fn color(hex : UInt32, alpha~ : Double = 1.0) -> @render.Color {
  { r: (hex >> 16) & 255, g: (hex >> 8) & 255, b: hex & 255, a: alpha, }
}

///|
fn rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  fill : @render.Color,
) -> Unit {
  @render2d.push_ui_rect({
    rect: { position: @math.Vec2(x, y), size: @math.Vec2(w, h), },
    transform: @math.Transform(),
    alpha_mode: Blend,
    blend_mode: Alpha,
    fill_color: fill,
    stroke_color: None,
  })
}
