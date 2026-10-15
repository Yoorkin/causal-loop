///|
fn run_for(game : @sim.Game, count : Int32, axis : Int32) -> Unit {
  for _ in 0..<count {
    game.step({ crouch: false, axis, jump: false, })
  }
}

///|
test "F - Level 2 needs two histories on separate switches and a third runner" {
  let game = @sim.Game::new(2)
  run_for(game, 40, -1)
  run_for(game, 680, 0)
  assert_eq(game.snapshot().outcome, @sim.Playing)
  game.end_life()
  run_for(game, 120, 1)
  run_for(game, 600, 0)
  assert_true(game.snapshot().plate_a)
  assert_true(game.snapshot().plate_b)
  assert_true(game.snapshot().bridge_open)
  assert_eq(game.snapshot().outcome, @sim.Playing)
  game.end_life()
  run_for(game, 300, 1)
  let view = game.snapshot()
  assert_eq(view.outcome, @sim.Won)
  assert_true(view.actors[0].x < 1600)
  assert_true(view.actors[1].x >= 5700 && view.actors[1].x < 6700)
  assert_true(view.actors[2].x > 9700)
}

///|
test "Level 2 two lives alone cannot keep both switches and run through exit" {
  let game = @sim.Game::new(2)
  run_for(game, 40, -1)
  run_for(game, 680, 0)
  game.end_life()
  run_for(game, 300, 1)
  assert_eq(game.snapshot().outcome, @sim.Playing)
  assert_true(game.snapshot().actors[1].x < 8800)
}
