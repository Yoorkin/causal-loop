///|
test "crouching keeps feet and pressure plates grounded and releases to stand" {
  let game = @sim.Game::new(2)
  for _ in 0..<20 {
    game.step(@sim.Input::wait())
  }
  for _ in 0..<40 {
    game.step({ axis: -1, jump: false, crouch: false, })
  }
  assert_true(game.snapshot().plate_a)
  let standing = game.snapshot().actors[0]
  game.step({ axis: 0, jump: true, crouch: true, })
  let crouched = game.snapshot().actors[0]
  assert_true(crouched.crouching && crouched.grounded)
  assert_eq(crouched.y + 240, standing.y + 380)
  assert_eq(crouched.vy, 0)
  assert_true(game.snapshot().plate_a)
  game.step({ axis: 1, jump: false, crouch: true, })
  let moving = game.snapshot().actors[0]
  assert_eq(moving.x, crouched.x + 8)
  assert_true(moving.walking && moving.crouching)
  assert_eq(moving.facing, 1)
  game.step(@sim.Input::wait())
  assert_false(game.snapshot().actors[0].crouching)
  assert_eq(game.snapshot().actors[0].y, standing.y)
}

///|
test "historical crouching replays the complete actor state at normal and fast speed" {
  let game = @sim.Game::new(2)
  let frames : Array[@sim.ActorView] = []
  for tick in 0..<180 {
    game.step({
      axis: if tick < 90 {
        1
      } else {
        -1
      },
      jump: tick == 120,
      crouch: tick >= 24 && tick < 100,
    })
    frames.push(game.snapshot().actors[0])
  }
  game.end_life()
  for frame in frames {
    game.step(@sim.Input::wait())
    assert_eq(game.snapshot().actors[0], frame)
  }
  game.end_life()
  for batch in 0..<30 {
    game.advance_batch(@sim.Input::wait(), true, debug=true)
    assert_eq(game.snapshot().actors[0], frames[batch * 6 + 5])
  }
}
