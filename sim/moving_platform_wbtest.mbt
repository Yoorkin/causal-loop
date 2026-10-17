///|
test "moving platform carries idle riders through both turns and agrees at 1x and 6x" {
  let normal = Game::new(2)
  let fast = Game::new(2)
  let platform = level_geometry(2).moving_platforms[0]
  let start = platform.at(0)
  for game in [normal, fast] {
    game.actors[0].x = start.x + 300
    game.actors[0].y = start.y - 380
    game.actors[0].grounded = true
  }
  for _ in 0..<120 {
    for _ in 0..<6 {
      normal.step(Input::wait())
    }
    fast.advance_batch(Input::wait(), true, debug=true)
    assert_eq(normal, fast)
    let actor = normal.actors[0]
    let body = platform.at(normal.tick)
    assert_eq(actor.x, body.x + 300)
    assert_eq(actor.y + 380, body.y)
    assert_true(actor.active && actor.grounded)
  }
}

///|
test "falling onto the moving platform attaches the rider and jumping detaches it" {
  let game = Game::new(2)
  let platform = level_geometry(2).moving_platforms[0]
  game.actors[0].x = platform.at(0).x + 600
  game.actors[0].y = platform.at(0).y - 800
  for _ in 0..<20 {
    game.step(Input::wait())
  }
  assert_true(game.actors[0].grounded)
  let before = game.actors[0].x
  game.step(Input::wait())
  assert_eq(
    game.actors[0].x - before,
    platform.at(game.tick).x - platform.at(game.tick - 1).x,
  )
  game.step({ axis: 0, jump: true, crouch: false, })
  let airborne_x = game.actors[0].x
  for _ in 0..<10 {
    game.step(Input::wait())
  }
  assert_false(game.actors[0].grounded)
  assert_eq(game.actors[0].x, airborne_x)
}

///|
test "rewind restores the moving platform phase and every gate" {
  let game = Game::new(2, progress=RunProgress::new(heart_capacity=2))
  let platform = level_geometry(2).moving_platforms[0]
  let start = platform.at(game.tick)
  for _ in 0..<180 {
    game.step(Input::wait())
  }
  game.gate_openings[0] = 1200
  assert_true(platform.at(game.tick) != start)
  game.end_life()
  assert_eq(platform.at(game.tick), start)
  assert_eq(game.gate_openings, [0, 0, 0])
}
