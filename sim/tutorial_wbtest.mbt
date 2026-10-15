///|
fn reach_tutorial_drop(game : Game) -> Unit raise {
  let right : Input = { axis: 1, jump: false, crouch: false, }
  for _ in 0..<30 {
    game.step(Input::wait())
  }
  for _ in 0..<100 {
    if game.actors[0].x >= 3600 {
      break
    }
    game.step(right)
  }
  game.step({ ..right, jump: true, })
  for _ in 0..<80 {
    game.step(right)
    if game.actors[0].grounded && game.actors[0].y == 3920 {
      break
    }
  }
  assert_eq(game.actors[0].y, 3920)
  for _ in 0..<100 {
    if game.actors[0].x >= 5400 {
      break
    }
    game.step(right)
  }
  game.step({ ..right, jump: true, })
  for _ in 0..<120 {
    game.step(right)
    if game.actors[0].grounded && game.actors[0].x >= 7000 {
      break
    }
  }
  assert_eq(game.actors[0].y, 3120)
  assert_true(game.actors[0].grounded)
  assert_false(game.heart_collected)
}

///|
test "tutorial route requires jumps and S, grants one heart and reaches the exit across seeds" {
  for seed in 0U..<64U {
    let game = Game::new(0, seed~)
    assert_eq(game.max_lives, 1)
    reach_tutorial_drop(game)
    let x = game.actors[0].x
    for _ in 0..<30 {
      game.step(Input::wait())
    }
    assert_eq(game.actors[0].y, 3120)
    game.step({ axis: 0, jump: false, crouch: true, })
    for _ in 0..<60 {
      game.step(Input::wait())
    }
    assert_eq(game.actors[0].x, x)
    assert_eq(game.actors[0].y, 5220)
    for _ in 0..<140 {
      game.step({ axis: 1, jump: false, crouch: false, })
      if game.outcome == Won {
        break
      }
    }
    assert_true(game.heart_collected)
    assert_eq(game.max_lives, 2)
    assert_eq(game.outcome, Won)
    assert_eq(game.histories.length(), 0)
  }
}

///|
test "tutorial starts with one life and its clock and impact use normal timing" {
  let game = Game::new(0)
  assert_eq(game.max_lives, 1)
  for _ in 0..<540 {
    game.step(Input::wait())
  }
  assert_eq(game.outcome, Playing)
  assert_eq(game.snapshot().wave_radius, 170)
  assert_eq(game.actors[0].frozen_at, -1)
  for _ in 540..<WaveEndTick {
    game.step(Input::wait())
  }
  assert_eq(game.outcome, Lost)
  assert_true(game.actors[0].frozen_at > WaveStartTick)
}

///|
test "walking cannot bypass tutorial jumps or enter the lower exit corridor" {
  let game = Game::new(0)
  for _ in 0..<500 {
    game.step({ axis: 1, jump: false, crouch: false, })
  }
  assert_eq(game.actors[0].x, 3760)
  assert_eq(game.outcome, Playing)
  assert_false(game.heart_collected)
}

///|
test "collected heart grants an actual retry and cannot be farmed after rewind" {
  let game = Game::new(0)
  game.actors[0].x = 9400
  game.actors[0].y = 5220
  game.step(Input::wait())
  assert_eq(game.max_lives, 2)
  for _ in 0..<60 {
    game.step(Input::wait())
  }
  assert_eq(game.max_lives, 2)
  game.end_life()
  assert_eq(game.outcome, Playing)
  assert_eq(game.snapshot().life, 2)
  game.actors[1].x = 9400
  game.actors[1].y = 5220
  game.step(Input::wait())
  assert_eq(game.max_lives, 2)
  game.end_life()
  assert_eq(game.outcome, Lost)
  let retry = Game::new(0)
  assert_eq(retry.max_lives, 1)
  assert_false(retry.heart_collected)
}

///|
test "recorded S drop replays through the platform with the same physics" {
  let game = Game::new(0)
  reach_tutorial_drop(game)
  game.step({ axis: 0, jump: false, crouch: true, })
  for _ in 0..<60 {
    game.step(Input::wait())
  }
  for _ in 0..<80 {
    game.step({ axis: 1, jump: false, crouch: false, })
  }
  assert_true(game.heart_collected)
  assert_eq(game.outcome, Playing)
  let original = game.snapshot().actors[0]
  let ticks = game.tick
  game.end_life()
  for _ in 0..<ticks {
    game.step(Input::wait())
  }
  assert_eq(game.snapshot().actors[0], original)
  assert_eq(game.max_lives, 2)
}

///|
test "one-way platforms allow upward passage and S only drops through the supporting platform" {
  let upper : Rect = { x: 6000, y: 3500, w: 2000, h: 80, }
  let lower : Rect = { x: 6000, y: 4300, w: 2000, h: 80, }
  let platforms : ReadOnlyArray[Rect] = [upper, lower]
  let actor = Actor::new(0, { x: 7000, y: 3600, })
  actor.vy = -110
  let mut passed_upward = false
  for _ in 0..<60 {
    actor.advance(Input::wait(), [], drop_platforms=platforms)
    if actor.vy < 0 && actor.y + 380 < upper.y {
      passed_upward = true
    }
    if actor.grounded {
      break
    }
  }
  assert_true(passed_upward)
  assert_eq(actor.y, 3120)
  for _ in 0..<80 {
    actor.advance(
      { axis: 0, jump: false, crouch: true, },
      [],
      drop_platforms=platforms,
    )
  }
  assert_true(actor.grounded && actor.crouching)
  assert_eq(actor.y + actor.bounds().h, lower.y)
  actor.advance(Input::wait(), [], drop_platforms=platforms)
  actor.advance(
    { axis: 0, jump: false, crouch: true, },
    [],
    drop_platforms=platforms,
  )
  assert_false(actor.grounded)
}
