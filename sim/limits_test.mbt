///|
test "E - completed sweep seals a complete recording and resets the next life" {
  let game = @sim.Game::new(1)
  for _ in 0..<1091 {
    game.step(@sim.Input::wait())
  }
  assert_eq(game.snapshot().life, 1)
  game.step(@sim.Input::wait())
  let view = game.snapshot()
  assert_eq(view.life, 2)
  assert_eq(view.tick, 0)
  assert_eq(view.history_lengths, [1092])
  assert_eq(view.recording_length, 0)
  assert_eq(view.outcome, @sim.Playing)
}

///|
test "E - every level stops at its configured life limit and stays stopped" {
  for level in [0, 1, 3, 2] {
    let game = @sim.Game::new(level)
    let limit = if level == 0 { 1 } else if level == 2 { 3 } else { 2 }
    assert_eq(game.snapshot().max_lives, limit)
    assert_eq(game.snapshot().wave_start_tick, 1080)
    for _ in 0..<(limit * 1092) {
      game.step(@sim.Input::wait())
    }
    let finished = game.snapshot()
    assert_eq(finished.outcome, @sim.Lost)
    assert_eq(finished.life, limit)
    assert_eq(finished.history_lengths.length(), limit)
    for length in finished.history_lengths {
      assert_eq(length, 1092)
    }
    game.end_life()
    game.advance_batch(@sim.Input::wait(), true, debug=true)
    assert_eq(game.snapshot(), finished)
  }
}

///|
test "6x stops on the completed sweep without consuming the next life's first frame" {
  let game = @sim.Game::new(1)
  for _ in 0..<1091 {
    game.step(@sim.Input::wait())
  }
  game.advance_batch(@sim.Input::wait(), true, debug=true)
  assert_eq(game.snapshot().life, 2)
  assert_eq(game.snapshot().tick, 0)
  assert_eq(game.snapshot().recording_length, 0)
  assert_eq(game.snapshot().history_lengths, [1092])
}

///|
test "debug numbers and portal order agree after swapping rooms three and four" {
  for index, id in [0, 1, 3, 2] {
    let number = index + 1
    assert_eq(@sim.level_for_number(number), id)
    assert_eq(@sim.level_number(id), number)
    assert_eq(@sim.Game::new(id).snapshot().max_lives, [1, 2, 2, 3][index])
  }
}
