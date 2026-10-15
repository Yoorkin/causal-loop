///|
test "A - replay identical input through identical physics" {
  let game = @sim.Game::new(1)
  let inputs : Array[@sim.Input] = [
    for tick in 0..<300 => {
      {
        crouch: false,
        axis: if tick < 100 {
          1
        } else {
          0
        },
        jump: tick >= 30 && tick < 40,
      }
    }
  ]
  for input in inputs {
    game.step(input)
  }
  let original = game.snapshot().actors[0]
  game.end_life()
  for _ in inputs {
    game.step(@sim.Input::wait())
  }
  assert_eq(game.snapshot().actors[0], original)
  assert_eq(game.snapshot().recording_length, 300)
  assert_eq(game.snapshot().history_lengths[0], 300)
}

///|
test "history expires instead of holding its last input forever" {
  let game = @sim.Game::new(1)
  for _ in 0..<10 {
    game.step({ crouch: false, axis: 1, jump: false, })
  }
  game.end_life()
  for _ in 0..<11 {
    game.step(@sim.Input::wait())
  }
  assert_false(game.snapshot().actors[0].active)
  assert_true(game.snapshot().actors[1].active)
}
