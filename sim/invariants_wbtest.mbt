///|
test "H - simultaneous switch effects are independent of actor traversal order" {
  let ordered = Game::new(3)
  let reversed = Game::new(3)
  let waiting = Array::make(700, Input::wait())
  for index, game in [ordered, reversed] {
    game.histories.push(History::seal(waiting))
    game.histories.push(History::seal(waiting))
    let a = Actor::new(0, { x: 2400, y: 3980, })
    let b = Actor::new(1, { x: 2400, y: 3980, })
    let c = Actor::new(2, { x: 2400, y: 3980, })
    a.x = 2600
    a.y = 3020
    b.x = 6800
    b.y = 4120
    c.x = 1200
    c.y = 3820
    game.actors = if index == 0 { [a, b, c] } else { [c, b, a] }
  }
  for _ in 0..<600 {
    let input : Input = { crouch: false, axis: 0, jump: false, }
    ordered.step(input)
    reversed.step(input)
    assert_eq(ordered.tick, reversed.tick)
    assert_eq(ordered.plate_a, reversed.plate_a)
    assert_eq(ordered.plate_b, reversed.plate_b)
    assert_eq(ordered.bridge_open, reversed.bridge_open)
    assert_eq(ordered.plate_c, reversed.plate_c)
    assert_eq(ordered.gate_openings, reversed.gate_openings)
    assert_eq(ordered.actors[0], reversed.actors[2])
    assert_eq(ordered.actors[1], reversed.actors[1])
    assert_eq(ordered.actors[2], reversed.actors[0])
  }
  assert_true(ordered.plate_a && ordered.plate_b && ordered.plate_c)
}

///|
test "sealed input owns an immutable copy, not a live recording array" {
  let frames = [Input::{ crouch: false, axis: 1, jump: true, }]
  let history = History::seal(frames)
  frames[0] = Input::wait()
  frames.clear()
  assert_eq(history.frames.length(), 1)
  assert_eq(history.frames[0].axis, 1)
  assert_true(history.frames[0].jump)
}

///|
test "falling current actor ends its life; falling history does not end the current life" {
  let game = Game::new(1)
  game.actors[0].y = 6900
  game.step(Input::wait())
  assert_eq(game.snapshot().life, 2)
  assert_eq(game.tick, 0)
  game.actors[0].y = 6900
  game.step(Input::wait())
  assert_eq(game.outcome, Playing)
  assert_false(game.actors[0].active)
  assert_true(game.actors[1].active)
}

///|
test "6x stops immediately at death without recording frames in the next life" {
  let game = Game::new(1)
  game.actors[0].y = 6900
  game.advance_batch(Input::wait(), true, debug=true)
  let view = game.snapshot()
  assert_eq(view.life, 2)
  assert_eq(view.tick, 0)
  assert_eq(view.recording_length, 0)
  assert_eq(view.history_lengths[0], 1)
  assert_true(view.actors[1].active)
}

///|
test "three elevated plates operate only their matching gates" {
  let level = level_geometry(3)
  for i, plate in [level.plate_a, level.plate_b, level.plate_c] {
    let game = Game::new(3)
    game.actors[0].x = plate.x
    game.actors[0].y = plate.y + plate.h - 380
    for _ in 0..<20 {
      game.step(Input::wait())
    }
    for j in 0..<3 {
      assert_eq(game.gate_openings[j], if i == j { 1200 } else { 0 })
    }
  }
}

///|
test "gates start closing on the release frame and move through intermediate positions" {
  let game = Game::new(3)
  game.actors[0].x = 1200
  game.actors[0].y = 3820
  for _ in 0..<20 {
    game.step(Input::wait())
  }
  assert_eq(game.gate_openings[0], 1200)
  game.step({ crouch: false, axis: 0, jump: true, })
  assert_false(game.plate_a)
  assert_eq(game.gate_openings[0], 1190)
  let first_body = gate_body(level_geometry(3).gates[0], game.gate_openings[0])
  assert_eq(first_body.h, 10)
  game.actors[0].x = 2400
  game.actors[0].y = 4620
  game.actors[0].vy = 0
  for _ in 0..<59 {
    game.step(Input::wait())
  }
  assert_eq(game.gate_openings[0], 600)
  for _ in 0..<60 {
    game.step(Input::wait())
  }
  assert_eq(game.gate_openings[0], 0)
}

///|
test "closing gate waits for an overlapping body and then immediately resumes" {
  let game = Game::new(3)
  game.gate_openings[0] = 380
  game.actors[0].x = 5810
  game.actors[0].y = 4620
  game.resolve_puzzle()
  assert_eq(game.gate_openings[0], 380)
  assert_eq(game.actors[0].x, 5810)
  assert_eq(game.actors[0].y, 4620)
  game.actors[0].x = 6020
  game.resolve_puzzle()
  assert_eq(game.gate_openings[0], 370)
}

///|
test "D extended - three moving gates and two histories agree at 1x and 6x" {
  let normal = Game::new(3)
  let fast = Game::new(3)
  // Synthetic three-actor stress case; the playable tunnel has only two lives.
  for game in [normal, fast] {
    game.max_lives = 3
    for route in 0..<2 {
      for t in 0..<720 {
        let x = game.actors[route].x
        game.step({
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
          } else if route == 1 && t >= 90 && t < 134 {
            1
          } else {
            0
          },
          jump: (t >= 36 && t < 70) || (route == 1 && t >= 90 && t < 124),
        })
      }
      game.end_life()
    }
  }
  for _ in 0..<600 {
    normal.advance_batch(Input::wait(), false)
  }
  for _ in 0..<100 {
    fast.advance_batch(
      { crouch: false, axis: 1, jump: true, },
      true,
      debug=true,
    )
  }
  assert_eq(normal, fast)
  assert_eq(normal.gate_openings, [1200, 1200, 0])
  assert_eq(normal.tick, 600)
}
