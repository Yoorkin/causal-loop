///|
test "charging clock is harmless even when a body covers its centre" {
  let game = Game::new(2)
  game.actors[0].x = 5480
  game.actors[0].y = 2910
  for tick in [0, 540, 1079, 1080] {
    game.freeze_swept_actors(tick)
    assert_eq(game.actors[0].frozen_at, -1)
  }
  game.freeze_swept_actors(1081)
  assert_eq(game.actors[0].frozen_at, 1081)
}

///|
test "the displayed wave edge uses circle-body contact including corners" {
  assert_eq(wave_radius(0), 0)
  assert_eq(wave_radius(1080), 340)
  assert_eq(WaveEndTick, 1092)
  assert_eq(wave_radius(WaveEndTick), 6440)
  // Immediate movement, then increasing speed all the way to full coverage.
  assert_true(wave_radius(1081) - 340 >= 350)
  assert_true(wave_radius(1083) >= 1400)
  assert_true(
    wave_radius(1092) - wave_radius(1089) >
    wave_radius(1086) - wave_radius(1083),
  )
  let mut previous_speed = 0
  for tick in 1081..<=WaveEndTick {
    let speed = wave_radius(tick) - wave_radius(tick - 1)
    assert_true(speed >= previous_speed - 2) // two truncated integer terms
    previous_speed = speed
  }
  let side : Rect = { x: 6600, y: 3000, w: 240, h: 380, }
  assert_false(wave_touches(side, 999))
  assert_true(wave_touches(side, 1000))
  let corner : Rect = { x: 5900, y: 3500, w: 240, h: 380, }
  assert_false(wave_touches(corner, 499))
  assert_true(wave_touches(corner, 500))
}

///|
test "wave freezes each actor on contact while a farther actor can still move" {
  let game = Game::new(2)
  game.histories.push(History::seal(Array::make(WaveEndTick, Input::wait())))
  game.actors = [
    Actor::new(0, { x: 5600, y: 4620, }),
    Actor::new(1, { x: 2000, y: 4620, }),
  ]
  game.tick = 1079
  game.step(Input::wait())
  assert_eq(game.actors[0].frozen_at, -1)
  assert_eq(game.actors[1].frozen_at, -1)
  for _ in 0..<6 {
    game.step({ axis: -1, jump: false, crouch: false, })
  }
  let near = game.snapshot().actors[0]
  let far = game.snapshot().actors[1]
  assert_true(near.frozen_at > 1080)
  assert_eq(far.frozen_at, -1)
  assert_true(far.x < 2000)
  for _ in 0..<1 {
    game.step({ axis: -1, jump: false, crouch: false, })
  }
  assert_eq(game.snapshot().actors[0], near)
  assert_true(game.snapshot().actors[1].x < far.x)
  for _ in 0..<4 {
    game.step(Input::wait())
  }
  assert_true(game.actors[1].frozen_at > near.frozen_at)
  assert_eq(game.snapshot().life, 2)
  assert_true(game.tick < WaveEndTick)
}

///|
test "running away during expansion earns more unfrozen time" {
  let waiting = Game::new(2)
  let escaping = Game::new(2)
  for game in [waiting, escaping] {
    game.tick = 1080
    game.actors[0].x = 2600
    game.actors[0].y = 4620
  }
  for _ in 0..<(WaveTravelTicks - 2) {
    waiting.step(Input::wait())
    escaping.step({ axis: -1, jump: false, crouch: false, })
  }
  assert_true(waiting.actors[0].frozen_at > 1080)
  assert_true(escaping.actors[0].frozen_at > waiting.actors[0].frozen_at)
}

///|
test "6x stops at expansion and the sweep accepts movement at normal speed" {
  let game = Game::new(2)
  for _ in 0..<1079 {
    game.step(Input::wait())
  }
  game.advance_batch(Input::wait(), true, debug=true)
  assert_eq(game.tick, 1080)
  assert_eq(game.snapshot().life, 1)
  let x = game.actors[0].x
  game.advance_batch(
    { axis: -1, jump: false, crouch: false, },
    true,
    debug=true,
  )
  assert_eq(game.tick, 1081)
  assert_eq(game.actors[0].x, x - 30)
  assert_eq(game.actors[0].frozen_at, -1)
}

///|
test "input replay reproduces contact and the exact frozen pose" {
  let game = Game::new(1)
  for _ in 0..<(WaveEndTick - 5) {
    game.step({ axis: 1, jump: false, crouch: false, })
  }
  let original = game.snapshot().actors[0]
  assert_true(original.frozen_at > 1080)
  for _ in (WaveEndTick - 5)..<WaveEndTick {
    game.step(Input::wait())
  }
  assert_eq(game.snapshot().life, 2)
  for _ in 0..<(WaveEndTick - 5) {
    game.step(Input::wait())
  }
  assert_eq(game.snapshot().actors[0], original)
}
