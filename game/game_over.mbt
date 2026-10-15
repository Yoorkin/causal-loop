///|
const GameOverDelay : Double = 0.3

///|
const GameOverFadeDuration : Double = 0.8

///|
const GameOverDuration : Double = GameOverDelay + GameOverFadeDuration

///|
fn game_over_opacity(elapsed : Double) -> Double {
  if elapsed <= GameOverDelay {
    return 0.0
  }
  if elapsed >= GameOverDuration {
    return 1.0
  }
  let t = (elapsed - GameOverDelay) / GameOverFadeDuration
  t * t * (3.0 - 2.0 * t)
}

///|
fn draw_game_over(opacity : Double) -> Unit {
  guard opacity > 0.0 else { return }
  @render2d.push_ui_text({
    text: "Game Over",
    position: @math.Vec2(560.0, 405.0),
    transform: @math.Transform(),
    blend_mode: Alpha,
    style: {
      font: None,
      family: "sans-serif",
      size: 48.0,
      color: color(0xe8eee9, alpha=opacity),
      align: Center,
      baseline: Center,
    },
  })
  @render2d.push_ui_text({
    text: "space retry",
    position: @math.Vec2(560.0, 450.0),
    transform: @math.Transform(),
    blend_mode: Alpha,
    style: {
      font: None,
      family: "sans-serif",
      size: 16.0,
      color: color(0xa5a0b5, alpha=opacity),
      align: Center,
      baseline: Center,
    },
  })
}
