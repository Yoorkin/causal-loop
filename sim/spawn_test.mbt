///|
test "spawn choices vary by seed, stay three bodies wide and fall onto the floor" {
  let first = @sim.Game::new(
      1,
      progress=@sim.RunProgress::new(heart_capacity=3),
      seed=0U,
    ).snapshot().actors[0]
  let mut varied = false
  let mut varied_y = false
  for seed in 0..<64 {
    let game = @sim.Game::new(
      1,
      progress=@sim.RunProgress::new(heart_capacity=3),
      seed=seed.reinterpret_as_uint(),
    )
    let starts : Array[@sim.ActorView] = []
    for life in 0..<3 {
      let initial = game.snapshot()
      let actor = initial.actors[life]
      starts.push(actor)
      assert_true(actor.x >= 2160 && actor.x + 240 <= 2880)
      assert_true(actor.y >= 3880 && actor.y <= 4080)
      assert_eq(actor.vy, 0)
      assert_false(actor.grounded)
      if life == 0 && actor.x != first.x {
        varied = true
      }
      if life == 0 && actor.y != first.y {
        varied_y = true
      }
      // Every previous life retains its own initial position, including altitude.
      for i in 0..<=life {
        assert_eq(initial.actors[i], starts[i])
        for j in 0..<i {
          assert_true((starts[i].x - starts[j].x).abs() >= 120)
        }
      }
      game.step(@sim.Input::wait())
      assert_eq(game.snapshot().actors[life].y, actor.y + 5)
      for _ in 1..<17 {
        game.step(@sim.Input::wait())
      }
      let landed = game.snapshot().actors[life]
      assert_eq(landed.y, 4620)
      assert_true(landed.grounded)
      game.end_life()
    }
  }
  assert_true(varied)
  assert_true(varied_y)
}

///|
test "airborne histories replay identical trajectories from their own randomized start" {
  for seed in [0U, 1U, 42U, 2147483648U, 4294967295U] {
    let game = @sim.Game::new(
      1,
      progress=@sim.RunProgress::new(heart_capacity=3),
      seed~,
    )
    let frames = []
    for t in 0..<100 {
      game.step({
        crouch: false,
        axis: if t < 40 {
          1
        } else {
          0
        },
        jump: t >= 50 && t < 55,
      })
      frames.push(game.snapshot().actors[0])
    }
    game.end_life()
    for frame in frames {
      game.step(@sim.Input::wait())
      assert_eq(game.snapshot().actors[0], frame)
    }
  }
}

///|
test "random spawn positions preserve the third-level timing solution across seeds" {
  for seed in 0..<64 {
    let game = @sim.Game::new(
      3,
      progress=@sim.RunProgress::new(heart_capacity=2),
      seed=seed.reinterpret_as_uint(),
    )
    record_runner(game)
    for t in 0..<320 {
      game.step(climber_input(t, game))
    }
    assert_eq(game.snapshot().outcome, @sim.Won)
  }
}
