///|
test "B - same recorded right input crosses only after the present opens the bridge" {
  let game = @sim.Game::new(1, progress=@sim.RunProgress::new(heart_capacity=2))
  for _ in 0..<360 {
    game.step({ crouch: false, axis: 1, jump: false, })
  }
  let blocked = game.snapshot().actors[0].x
  assert_eq(blocked, 3920)
  assert_eq(game.snapshot().outcome, @sim.Playing)
  game.end_life()
  for _ in 0..<40 {
    game.step({ crouch: false, axis: -1, jump: false, })
  }
  assert_true(game.snapshot().bridge_open)
  for _ in 0..<260 {
    game.step(@sim.Input::wait())
  }
  let view = game.snapshot()
  assert_eq(view.outcome, @sim.Won)
  assert_true(view.actors[0].x > 9700)
  assert_true(view.actors[1].x < 1600)
  assert_eq(view.history_lengths[0], 360)
}

///|
test "without changing the environment the first history remains blocked" {
  let game = @sim.Game::new(1, progress=@sim.RunProgress::new(heart_capacity=2))
  for _ in 0..<360 {
    game.step({ crouch: false, axis: 1, jump: false, })
  }
  let blocked = game.snapshot().actors[0].x
  game.end_life()
  for _ in 0..<300 {
    game.step(@sim.Input::wait())
  }
  assert_eq(game.snapshot().actors[0].x, blocked)
  assert_eq(game.snapshot().outcome, @sim.Playing)
}
