///|
fn run_for(game : @sim.Game, count : Int32, axis : Int32) -> Unit {
  for _ in 0..<count {
    game.step({ crouch: false, axis, jump: false, })
  }
}

///|
fn lower_route(tick : Int32) -> @sim.Input {
  {
    axis: if tick < 395 || (tick >= 650 && tick < 695) {
      1
    } else {
      0
    },
    jump: tick == 650,
    crouch: (tick >= 40 && tick < 44) || (tick >= 100 && tick < 305),
  }
}

///|
fn record_lower_route(game : @sim.Game) -> Unit {
  for t in 0..<1092 {
    game.step(lower_route(t))
  }
}

///|
fn upper_route(tick : Int32, actor : @sim.ActorView) -> @sim.Input {
  {
    axis: if actor.x < 6400 || (tick >= 330 && actor.x < 7000) || tick >= 710 {
      1
    } else {
      0
    },
    jump: false,
    crouch: false,
  }
}

///|
test "fourth room reciprocal two-life solution survives randomized spawns" {
  for seed in 0..<64 {
    let game = @sim.Game::new(
      2,
      progress=@sim.RunProgress::new(heart_capacity=2),
      seed=seed.reinterpret_as_uint(),
    )
    for t in 0..<1092 {
      game.step(lower_route(t))
      if t == 350 {
        assert_true(game.snapshot().plate_a)
        assert_eq(game.snapshot().actors[0].x, 5060)
        assert_true(game.snapshot().actors[0].walking)
        assert_eq(game.snapshot().gate_openings[0], 1200)
        assert_eq(game.snapshot().gate_openings[1], 0)
      }
    }
    assert_eq(game.snapshot().life, 2)
    for t in 0..<850 {
      game.step(upper_route(t, game.snapshot().actors[1]))
      if t == 430 {
        let past = game.snapshot().actors[0]
        assert_true(past.active && past.grounded)
        assert_true(past.x > 5900 && past.x < 9800)
        assert_eq(past.y, 4420)
        assert_true(game.snapshot().plate_b)
      }
    }
    assert_eq(game.snapshot().outcome, @sim.Won)
    assert_eq(game.snapshot().life, 2)
    assert_true(game.snapshot().plate_c)
    assert_true(game.snapshot().actors[0].x >= 9800)
    assert_eq(game.snapshot().actors[0].y, 4420)
    assert_true(game.snapshot().actors[1].x > 9800)
    assert_eq(game.snapshot().actors[1].y, 2120)
  }
}

///|
test "fourth room upper runner cannot reach the exit without the lower helper" {
  let game = @sim.Game::new(2)
  run_for(game, 500, 1)
  assert_eq(game.snapshot().outcome, @sim.Playing)
  assert_eq(game.snapshot().actors[0].x, 8260)
  assert_eq(game.snapshot().actors[0].y, 2120)
  assert_eq(game.snapshot().gate_openings, [0, 0, 0])
}

///|
test "fourth room outer upper plate opens the adjacent entrance but not the exit" {
  let game = @sim.Game::new(2)
  for _ in 0..<160 {
    game.step({
      axis: if game.snapshot().actors[0].x < 4300 {
        1
      } else {
        0
      },
      jump: false,
      crouch: false,
    })
  }
  assert_true(game.snapshot().plate_d)
  assert_false(game.snapshot().plate_c)
  assert_eq(game.snapshot().gate_openings, [1200, 0, 0])
  run_for(game, 300, 1)
  assert_false(game.snapshot().plate_d)
  assert_eq(game.snapshot().actors[0].x, 8260)
  assert_eq(game.snapshot().gate_openings, [0, 0, 0])
  assert_eq(game.snapshot().outcome, @sim.Playing)
}

///|
test "fourth room past remains blocked when the present does not release it" {
  let game = @sim.Game::new(2, progress=@sim.RunProgress::new(heart_capacity=2))
  record_lower_route(game)
  run_for(game, 700, 0)
  assert_eq(game.snapshot().actors[0].x, 5060)
  assert_eq(game.snapshot().gate_openings[1], 0)
  assert_eq(game.snapshot().gate_openings[2], 0)
  assert_eq(game.snapshot().outcome, @sim.Playing)
}

///|
test "fourth room stairs allow jumping from the lower gate back to the starting ledge" {
  let game = @sim.Game::new(2)
  for t in 0..<350 {
    game.step(lower_route(t))
  }
  run_for(game, 50, -1)
  assert_eq(game.snapshot().actors[0].x, 4600)
  for _ in 0..<200 {
    game.step({ axis: -1, jump: false, crouch: true, })
  }
  assert_eq(game.snapshot().actors[0].x, 3000)
  for target in [(2500, 4100), (1800, 3300), (1100, 2500)] {
    for frame in 0..<65 {
      let actor = game.snapshot().actors[0]
      game.step({
        axis: if actor.x > target.0 {
          -1
        } else {
          0
        },
        jump: frame == 0,
        crouch: false,
      })
    }
    let actor = game.snapshot().actors[0]
    assert_true(actor.grounded)
    assert_eq(actor.y + 380, target.1)
  }
  assert_true(game.snapshot().actors[0].x < 1600)
}

///|
test "fourth room long passage requires crouching and leaves standing room at the plate" {
  let game = @sim.Game::new(2)
  for t in 0..<100 {
    game.step(lower_route(t))
  }
  assert_eq(game.snapshot().actors[0].x, 3060)
  assert_false(game.snapshot().actors[0].crouching)
  run_for(game, 30, 1)
  assert_eq(game.snapshot().actors[0].x, 3060)
  for _ in 0..<180 {
    game.step({ axis: 1, jump: false, crouch: true, })
  }
  let inside = game.snapshot().actors[0]
  assert_eq(inside.x, 4500)
  assert_true(inside.crouching && inside.grounded)
  game.step({ axis: 1, jump: false, crouch: false, })
  assert_true(game.snapshot().actors[0].crouching)
  run_for(game, 30, 1)
  let outside = game.snapshot().actors[0]
  assert_true(game.snapshot().plate_a)
  assert_true(outside.grounded)
  assert_false(outside.crouching)
  assert_eq(outside.y, 4420)
}
