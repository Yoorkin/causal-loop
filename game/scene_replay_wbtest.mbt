///|
test "scene rewind reverses recorded movement and plate changes without changing the fresh life" {
  let game = @sim.Game::new(1, progress=@sim.RunProgress::new(heart_capacity=2))
  let replay : SceneReplay = { frames: [], }
  for tick in 0..<150 {
    game.advance_batch(
      { axis: if tick < 35 { -1 } else { 1 }, jump: false, crouch: false, },
      false,
      before_step=frame => replay.record(frame),
    )
  }
  let departing = replay.frames[replay.frames.length() - 1]
  assert_true(replay.frames.any(v => v.plate_a))
  assert_true(replay.frames.any(v => !v.plate_a))
  assert_true(departing.actors[0].x != replay.frames[0].actors[0].x)
  game.end_life()
  let fresh = game.snapshot()
  let timing = rewind_timing(1, 1)
  assert_eq(replay.at(departing, 0.0), departing)
  assert_eq(replay.at(departing, timing.hold_duration), departing)
  let mut previous = departing.tick
  for frame in 0..<=240 {
    let elapsed = timing.hold_duration + frame.to_double() / 60.0
    let shown = replay.at(departing, elapsed)
    assert_true(shown.tick <= previous)
    assert_eq(shown, replay.frames[shown.tick])
    assert_eq(game.snapshot(), fresh)
    let clock = time_wave(644.0, 1.0, true, elapsed, false, timing~)
    let expected = (149.0 * clock.clock_progress).to_int()
    assert_eq(shown.tick, expected)
    previous = shown.tick
  }
  assert_eq(
    replay.at(departing, clock_zero_time(timing) + 1.0),
    replay.frames[0],
  )
  assert_eq(fresh.tick, 0)
  assert_eq(fresh.remaining_lives, 1)
  replay.record(fresh)
  assert_eq(replay.frames.length(), 1)
  assert_eq(replay.frames[0].life, 2)
}

///|
test "accelerated recording retains every ordinary frame through a life boundary" {
  let normal = @sim.Game::new(
    1,
    progress=@sim.RunProgress::new(heart_capacity=2),
  )
  let fast = @sim.Game::new(1, progress=@sim.RunProgress::new(heart_capacity=2))
  let a : SceneReplay = { frames: [], }
  let b : SceneReplay = { frames: [], }
  for _ in 0..<1092 {
    normal.advance_batch(@sim.Input::wait(), false, before_step=v => a.record(v))
  }
  for _ in 0..<1092 {
    if fast.snapshot().life == 2 {
      break
    }
    fast.advance_batch(@sim.Input::wait(), true, debug=true, before_step=v => {
      b.record(v)
    })
  }
  assert_eq(a.frames.length(), 1092)
  assert_eq(b.frames, a.frames)
  assert_eq(fast.snapshot(), normal.snapshot())
  assert_eq(fast.snapshot().tick, 0)
}

///|
test "rewind restores physical crate positions and emission times from rendered frames" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let replay : SceneReplay = { frames: [], }
  for _ in 0..<180 {
    game.advance_batch(
      @sim.Input::wait(),
      false,
      physics=fn(v, i) { room.step(v, i) },
      before_step=v => replay.record(v),
    )
  }
  let end = replay.frames[179]
  let timing = rewind_timing(4, 1)
  let early = replay.at(end, timing.hold_duration + timing.fade_duration * 0.75)
  assert_true(early.crates.length() < end.crates.length())
  assert_true(early.crates[0].bounds.y < end.crates[0].bounds.y)
  assert_eq(early, replay.frames[early.tick])
  assert_eq(replay.at(end, clock_zero_time(timing)).tick, 0)
  assert_eq(replay.at(end, clock_zero_time(timing)).crates.length(), 0)
  let before = game.snapshot()
  for _ in 0..<30 {
    replay.at(end, timing.hold_duration + 0.5) |> ignore
  }
  assert_eq(game.snapshot(), before)
}
