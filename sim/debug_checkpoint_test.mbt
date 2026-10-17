///|
test "debug fixtures match normal entry checkpoints and never include this room's pickups" {
  for number in 1..<=6 {
    let level = @sim.level_for_number(number)
    let progress = @sim.debug_checkpoint(level)
    let game = @sim.Game::new(level, progress~)
    let view = game.snapshot()
    assert_eq(
      view.max_lives,
      if number == 1 {
        1
      } else if number == 6 {
        3
      } else {
        2
      },
    )
    assert_eq(view.remaining_lives, view.max_lives)
    assert_eq(view.inventory.time_acceleration, number >= 3)
    assert_eq(
      progress.collected_hearts.length(),
      if number == 1 {
        0
      } else if number == 6 {
        2
      } else {
        1
      },
    )
    if number == 1 {
      assert_false(view.heart_collected)
    }
    // A fresh game still has no synthetic progression outside Debug.
    let normal = @sim.Game::new(level).snapshot()
    assert_eq(normal.max_lives, 1)
    assert_false(normal.inventory.time_acceleration)
  }
}
