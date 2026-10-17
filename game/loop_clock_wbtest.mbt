///|
test "impact holds and rewinds then reaches clock zero without a rebirth-ready stage" {
  assert_eq(time_wave(19.0, 0.5, false, 0.0, false).phase, "growing")
  assert_eq(time_wave(34.0, 1.0, false, 0.0, false).phase, "growing")
  let expanding = time_wave(100.0, 1.0, false, 0.0, false)
  assert_eq(expanding.radius, 100.0)
  assert_eq(expanding.phase, "expanding")
  let hold = time_wave(644.0, 1.0, true, 0.0, false)
  assert_eq(hold.phase, "holding")
  assert_true(hold.radius * hold.radius > 560.0 * 560.0 + 310.0 * 310.0)
  assert_eq(time_wave(644.0, 1.0, true, 0.2, false).strength, 1.0)
  let mut previous = hold
  for i in 1..<20 {
    let fade = time_wave(
      644.0,
      1.0,
      true,
      WaveHoldDuration + WaveFadeDuration * i.to_double() / 20.0,
      false,
    )
    assert_eq(fade.radius, hold.radius)
    assert_true(fade.strength < previous.strength)
    assert_true(fade.clock_progress < previous.clock_progress)
    assert_eq(fade.strength, fade.clock_progress)
    previous = fade
  }
  for
    elapsed in [
      WaveHoldDuration + WaveFadeDuration,
      WaveHoldDuration + WaveFadeDuration + 0.4,
      WaveHoldDuration + WaveFadeDuration,
    ] {
    let ready = time_wave(644.0, 1.0, true, elapsed, false)
    assert_eq(ready.phase, "resetting")
    assert_eq(ready.radius, 0.0)
    assert_eq(ready.clock_progress, 0.0)
  }
  assert_true(WaveHoldDuration + WaveFadeDuration + 0.2 <= 1.900001)
}

///|
test "game over keeps the scene and clock frozen while only its text fades in" {
  for elapsed in [0.0, 0.5, WaveHoldDuration + WaveFadeDuration, 60.0] {
    for progress in [0.5, 1.0] {
      let radius = if progress == 1.0 { 644.0 } else { 19.0 }
      let lost = time_wave(radius, progress, false, elapsed, true)
      assert_eq(lost.radius, radius)
      assert_eq(lost.strength, 1.0)
      assert_eq(lost.clock_progress, progress)
      assert_true(lost.phase != "fading")
    }
  }
  assert_eq(game_over_opacity(0.0), 0.0)
  assert_eq(game_over_opacity(GameOverDelay), 0.0)
  let mut previous = 0.0
  for i in 1..<=20 {
    let opacity = game_over_opacity(
      GameOverDelay + GameOverFadeDuration * i.to_double() / 20.0,
    )
    assert_true(opacity > previous)
    previous = opacity
  }
  assert_eq(previous, 1.0)
  assert_eq(game_over_opacity(60.0), 1.0)
}

///|
test "clock warning starts four seconds before the impact and stops on impact" {
  for tick in [0, 839, 840, 1080, 1100] {
    let shake = clock_shake(tick, 1080, false)
    assert_eq(shake.0, 0.0)
    assert_eq(shake.1, 0.0)
  }
  let mut early_energy = 0.0
  let mut late_energy = 0.0
  for tick in 841..<1080 {
    let shake = clock_shake(tick, 1080, false)
    assert_true(shake.0 >= -3.0 && shake.0 <= 3.0)
    assert_true(shake.1 >= -2.0 && shake.1 <= 2.0)
    let energy = shake.0 * shake.0 + shake.1 * shake.1
    if tick < 871 {
      early_energy += energy
    }
    if tick >= 1050 {
      late_energy += energy
    }
    let held = clock_shake(tick, 1080, true)
    assert_eq(held.0, 0.0)
    assert_eq(held.1, 0.0)
  }
  assert_true(late_energy > early_energy * 8.0)
}

///|
test "hour hand follows minute progress forward and backward for each level" {
  for index, level in [0, 1, 3, 2, 4] {
    let start = index.to_double() * 30.0
    assert_eq(clock_hour_degrees(level, 0.0), start)
    assert_eq(clock_hour_degrees(level, 0.5), start + 15.0)
    assert_eq(clock_hour_degrees(level, 1.0), start + 30.0)
    let fade = time_wave(
      644.0,
      1.0,
      true,
      WaveHoldDuration + WaveFadeDuration / 2.0,
      false,
    )
    assert_true(clock_hour_degrees(level, fade.clock_progress) > start)
    assert_true(clock_hour_degrees(level, fade.clock_progress) < start + 30.0)
    let end = time_wave(
      644.0,
      1.0,
      true,
      WaveHoldDuration + WaveFadeDuration,
      false,
    )
    assert_eq(clock_hour_degrees(level, end.clock_progress), start)
  }
}

///|
test "only the bridge's first rewind extends hold rewind and clock-zero pause" {
  let teaching = rewind_timing(1, 1)
  assert_eq(teaching.hold_duration, 1.6)
  assert_eq(teaching.fade_duration, 4.0)
  assert_eq(teaching.reset_delay, 1.6)
  let reset = time_wave(
    644.0,
    1.0,
    true,
    clock_zero_time(teaching) + 0.8,
    false,
    timing=teaching,
  )
  assert_eq(reset.phase, "resetting")
  assert_eq(reset.clock_progress, 0.0)
  let ready = time_wave(
    644.0,
    1.0,
    true,
    clock_zero_time(teaching) + teaching.reset_delay,
    false,
    timing=teaching,
  )
  assert_eq(ready.phase, "resetting")
  assert_eq(ready.clock_progress, 0.0)
  for level in 0..<=3 {
    for life in 1..<=3 {
      if level != 1 || life != 1 {
        let normal = rewind_timing(level, life)
        assert_eq(normal.reset_delay, 0.0)
      }
    }
  }
}

///|
test "the teaching heart leaves its HUD slot, blinks at the clock and starts rewind only after vanishing" {
  let timing = rewind_timing(1, 1)
  assert_eq(heart_flight(0.1, true).phase, "waiting")
  let departure = heart_flight(HeartDepartDelay, true)
  assert_eq(departure.phase, "flying")
  assert_eq(departure.x, 576.0)
  assert_eq(departure.y, 40.0)
  let midway = heart_flight(0.6, true)
  assert_true(midway.y > departure.y && midway.y < 310.0)
  let arrival = heart_flight(1.0, true)
  assert_eq(arrival.phase, "blinking")
  assert_eq(arrival.x, 560.0)
  assert_eq(arrival.y, 310.0)
  assert_eq(arrival.opacity, 1.0)
  for i in 0..<160 {
    let elapsed = i.to_double() / 100.0
    let wave = time_wave(644.0, 1.0, true, elapsed, false, timing~)
    assert_eq(wave.phase, "holding")
    assert_eq(wave.clock_progress, 1.0)
    assert_eq(heart_flight(elapsed, false).phase, "none")
  }
  assert_eq(heart_flight(timing.hold_duration, true).opacity, 0.0)
  assert_eq(
    time_wave(644.0, 1.0, true, timing.hold_duration, false, timing~).phase,
    "fading",
  )
}

///|
test "rewind shakes only during its first two seconds and settles before zero" {
  let timing = rewind_timing(1, 1)
  for elapsed in [0.0, 1.0, 1.59, 3.6, 4.0, 5.6, 7.2] {
    let shake = rewind_clock_shake(elapsed, timing)
    assert_eq(shake, @math.Vec2(0.0, 0.0))
  }
  let shake = rewind_clock_shake(1.8, timing)
  assert_true(shake.0 != 0.0 && shake.1 != 0.0)
  assert_true(shake.0 >= -2.5 && shake.0 <= 2.5)
  assert_true(shake.1 >= -1.7 && shake.1 <= 1.7)
  let normal = rewind_timing(2, 1)
  assert_eq(rewind_clock_shake(1.8, normal), @math.Vec2(0.0, 0.0))
}
