///|
test "C - history and current input share the same frame index" {
  let game = @sim.Game::new(1, progress=@sim.RunProgress::new(heart_capacity=2))
  for tick in 0..<120 {
    game.step({
      crouch: false,
      axis: if tick >= 20 && tick < 30 {
        1
      } else {
        0
      },
      jump: tick == 50,
    })
  }
  game.end_life()
  let starts = game.snapshot().actors
  let start_sum = starts[0].x + starts[1].x
  for tick in 0..<60 {
    game.step({
      crouch: false,
      axis: if tick >= 20 && tick < 30 {
        -1
      } else {
        0
      },
      jump: tick == 50,
    })
    let view = game.snapshot()
    assert_eq(view.tick, tick + 1)
    if tick >= 17 {
      assert_eq(view.actors[0].y, view.actors[1].y)
    }
    assert_eq(view.actors[0].x + view.actors[1].x, start_sum)
  }
}

///|
test "D - 6x and 1x have identical complete state at frame 600" {
  let normal = @sim.Game::new(
    1,
    progress=@sim.RunProgress::new(heart_capacity=2),
  )
  let fast = @sim.Game::new(1, progress=@sim.RunProgress::new(heart_capacity=2))
  for _ in 0..<720 {
    normal.step({ crouch: false, axis: 1, jump: false, })
    fast.step({ crouch: false, axis: 1, jump: false, })
  }
  normal.end_life()
  fast.end_life()
  for _ in 0..<600 {
    normal.advance_batch(@sim.Input::wait(), false)
  }
  for _ in 0..<100 {
    fast.advance_batch(
      { crouch: false, axis: -1, jump: true, },
      true,
      debug=true,
    )
  }
  assert_eq(normal.snapshot().tick, 600)
  assert_eq(normal.snapshot(), fast.snapshot())
}
