///|
test "heart capacity and item ownership are independent of room geometry" {
  let progress = RunProgress::new(heart_capacity=5, inventory={
    time_acceleration: true,
  })
  for level in 0..<=4 {
    let fresh = Game::new(level)
    assert_eq(fresh.max_lives, 1)
    assert_false(fresh.inventory.time_acceleration)
    let game = Game::new(level, progress~)
    assert_eq(game.max_lives, 5)
    assert_true(game.inventory.time_acceleration)
    for life in 1..<=5 {
      assert_eq(game.snapshot().life, life)
      assert_eq(game.outcome, Playing)
      game.end_life()
    }
    assert_eq(game.outcome, Lost)
    assert_eq(game.progress(), progress)
  }
}

///|
test "a completed bridge refills acquired containers and preserves pickup identity in any room" {
  let practice = Game::new(0)
  reach_tutorial_drop(practice)
  practice.step({ axis: 0, jump: false, crouch: true, })
  for _ in 0..<60 {
    practice.step(Input::wait())
  }
  for _ in 0..<360 {
    practice.step({
      axis: 1,
      jump: false,
      crouch: practice.actors[0].x >= 7600 && practice.actors[0].x < 8540,
    })
    if practice.outcome == Won {
      break
    }
  }
  assert_eq(practice.outcome, Won)
  assert_eq(practice.max_lives, 2)
  assert_eq(practice.snapshot().remaining_lives, 1)
  let game = Game::new(1, progress=practice.progress())
  assert_eq(game.snapshot().remaining_lives, 2)
  for _ in 0..<360 {
    game.step({ axis: 1, jump: false, crouch: false, })
  }
  assert_eq(game.max_lives, 2)
  game.end_life()
  for _ in 0..<40 {
    game.step({ axis: -1, jump: false, crouch: false, })
  }
  for _ in 0..<260 {
    game.step(Input::wait())
  }
  assert_eq(game.outcome, Won)
  assert_eq(game.snapshot().life, 2)
  let checkpoint = game.progress()
  assert_true(checkpoint.inventory.time_acceleration)
  assert_eq(checkpoint.heart_capacity, 2)
  for level in 0..<=4 {
    let next = Game::new(level, progress=checkpoint)
    assert_eq(next.snapshot().life, 1)
    assert_eq(next.max_lives, 2)
    assert_true(next.inventory.time_acceleration)
    assert_eq(next.snapshot().remaining_lives, 2)
    if level == 0 {
      assert_true(next.heart_collected)
      for _ in 0..<100 {
        next.step({ axis: 1, jump: false, crouch: false, })
      }
      assert_eq(next.max_lives, 2)
    }
    next.end_life()
    next.end_life()
    assert_eq(next.outcome, Lost)
    let retry = Game::new(level, progress=checkpoint)
    assert_eq(retry.snapshot().life, 1)
    assert_eq(retry.snapshot().remaining_lives, 2)
    assert_eq(retry.progress(), checkpoint)
  }
}

///|
test "retry restores the last completion checkpoint and discards uncommitted pickups" {
  let checkpoint = RunProgress::new()
  let game = Game::new(0, progress=checkpoint)
  game.actors[0].x = 9400
  game.actors[0].y = 5220
  game.step(Input::wait())
  assert_eq(game.max_lives, 2)
  assert_eq(game.snapshot().remaining_lives, 1)
  game.collect_items([
    { kind: TimeAcceleration, bounds: game.actors[0].bounds(), },
  ])
  assert_true(game.inventory.time_acceleration)
  game.end_life()
  assert_eq(game.outcome, Lost)
  // Pickups replace immutable values, so the saved state has not changed.
  assert_eq(checkpoint, RunProgress::new())
  let retry = Game::new(0, progress=checkpoint)
  assert_eq(retry.max_lives, 1)
  assert_eq(retry.snapshot().remaining_lives, 1)
  assert_false(retry.heart_collected)
  assert_false(retry.inventory.time_acceleration)
}
