///|
test "blocked movement keeps walking intent, facing and animated stride during replay" {
  let game = @sim.Game::new(1)
  for _ in 0..<180 {
    game.step({ crouch: false, axis: 1, jump: false, })
  }
  let blocked = game.snapshot().actors[0]
  assert_eq(blocked.x, 3920)
  assert_true(blocked.walking)
  assert_eq(blocked.facing, 1)
  for _ in 0..<9 {
    game.step({ crouch: false, axis: 1, jump: false, })
  }
  let animated = game.snapshot().actors[0]
  assert_eq(animated.x, blocked.x)
  assert_true(animated.walking)
  assert_true(animated.stride != blocked.stride)
  game.end_life()
  for _ in 0..<189 {
    game.step(@sim.Input::wait())
  }
  assert_eq(game.snapshot().actors[0], animated)
}

///|
test "idle and airborne actors retain the last requested facing" {
  let game = @sim.Game::new(2)
  for _ in 0..<20 {
    game.step(@sim.Input::wait())
  }
  game.step({ crouch: false, axis: -1, jump: false, })
  assert_eq(game.snapshot().actors[0].facing, -1)
  assert_true(game.snapshot().actors[0].walking)
  game.step(@sim.Input::wait())
  assert_eq(game.snapshot().actors[0].facing, -1)
  assert_false(game.snapshot().actors[0].walking)
  game.step({ crouch: false, axis: 0, jump: true, })
  assert_eq(game.snapshot().actors[0].facing, -1)
  assert_false(game.snapshot().actors[0].grounded)
  assert_false(game.snapshot().actors[0].walking)
  game.step({ crouch: false, axis: 1, jump: false, })
  game.step(@sim.Input::wait())
  assert_eq(game.snapshot().actors[0].facing, 1)
}
