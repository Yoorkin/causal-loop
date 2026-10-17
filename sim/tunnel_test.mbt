///|
fn runner_input(t : Int32, origin : Int32) -> @sim.Input {
  let first_jump = (6000 - origin) / 30
  let second_jump = (8340 - origin) / 30
  {
    crouch: false,
    axis: if t < 320 {
      1
    } else {
      0
    },
    jump: (t >= first_jump && t < first_jump + 6) ||
    (t >= second_jump && t < second_jump + 6),
  }
}

///|
fn climber_input(t : Int32, game : @sim.Game) -> @sim.Input {
  let actors = game.snapshot().actors
  let x = actors[actors.length() - 1].x
  {
    crouch: false,
    axis: if t >= 16 && t < 36 {
      if x < 2385 {
        1
      } else if x > 2415 {
        -1
      } else {
        0
      }
    } else if t >= 36 && t < 70 {
      -1
    } else if t >= 90 && t < 134 {
      1
    } else {
      0
    },
    jump: (t >= 36 && t < 70) || (t >= 90 && t < 124),
  }
}

///|
fn record_runner(game : @sim.Game) -> Unit {
  let origin = game.snapshot().actors[0].x
  for t in 0..<1092 {
    game.step(runner_input(t, origin))
  }
}

///|
test "Level 3 - a climbing present changes the blocked runner's original inputs" {
  let game = @sim.Game::new(3, progress=@sim.RunProgress::new(heart_capacity=2))
  let origin = game.snapshot().actors[0].x
  for t in 0..<320 {
    game.step(runner_input(t, origin))
  }
  assert_eq(game.snapshot().actors[0].x, 5560)
  assert_eq(game.snapshot().gate_openings, [0, 0, 0])
  for t in 320..<1092 {
    game.step(runner_input(t, origin))
  }
  let mut reached = 0
  for t in 0..<320 {
    game.step(climber_input(t, game))
    let s = game.snapshot()
    if s.plate_a {
      reached = reached | 1
    }
    if s.plate_b {
      reached = reached | 2
    }
    if s.plate_c {
      reached = reached | 4
    }
  }
  assert_eq(reached, 7)
  assert_eq(game.snapshot().outcome, @sim.Won)
  assert_true(game.snapshot().actors[0].x > 9700)
  assert_eq(game.snapshot().actors[1].y, 3020)
  assert_eq(game.snapshot().history_lengths, [1092])
}

///|
test "Level 3 - delay misses the recorded jump and prevents the runner clearing the steps" {
  let game = @sim.Game::new(3, progress=@sim.RunProgress::new(heart_capacity=2))
  record_runner(game)
  for t in 0..<500 {
    game.step(
      if t < 130 {
        @sim.Input::wait()
      } else {
        climber_input(t - 130, game)
      },
    )
  }
  assert_eq(game.snapshot().outcome, @sim.Playing)
  assert_true(game.snapshot().actors[0].x < 8600)
}

///|
test "Level 3 - walking cannot activate any elevated plate or bypass closed gates" {
  let game = @sim.Game::new(3, progress=@sim.RunProgress::new(heart_capacity=2))
  run_for(game, 70, -1)
  assert_false(game.snapshot().plate_a)
  run_for(game, 320, 1)
  let s = game.snapshot()
  assert_false(s.plate_a || s.plate_b || s.plate_c)
  assert_eq(s.gate_openings, [0, 0, 0])
  assert_eq(s.actors[0].x, 5560)
  assert_eq(s.outcome, @sim.Playing)
}

///|
test "G - reset clears all three gates and plates but keeps input histories" {
  let game = @sim.Game::new(3, progress=@sim.RunProgress::new(heart_capacity=2))
  for t in 0..<170 {
    game.step(climber_input(t, game))
  }
  assert_true(game.snapshot().plate_b)
  assert_true(game.snapshot().gate_openings[1] > 0)
  game.end_life()
  let s = game.snapshot()
  assert_eq(s.life, 2)
  assert_eq(s.tick, 0)
  assert_eq(s.gate_openings, [0, 0, 0])
  assert_false(s.plate_a || s.plate_b || s.plate_c || s.bridge_open)
  assert_eq(s.history_lengths, [170])
  assert_eq(s.recording_length, 0)
  for actor in s.actors {
    assert_true(actor.x >= 2160 && actor.x <= 2640)
    assert_true(actor.y >= 3880 && actor.y <= 4080)
    assert_false(actor.grounded)
  }
}

///|
test "history expiry releases elevated pressure plate and immediately begins closure" {
  let game = @sim.Game::new(3, progress=@sim.RunProgress::new(heart_capacity=2))
  for t in 0..<70 {
    game.step(climber_input(t, game))
  }
  run_for(game, 30, 0)
  assert_eq(game.snapshot().gate_openings[0], 1200)
  game.end_life()
  run_for(game, 100, 0)
  assert_true(game.snapshot().plate_a)
  run_for(game, 1, 0)
  assert_false(game.snapshot().actors[0].active)
  assert_false(game.snapshot().plate_a)
  assert_eq(game.snapshot().gate_openings[0], 1190)
}
