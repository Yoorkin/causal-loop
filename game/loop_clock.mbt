///|
fn Session::visible_snapshot(self : Session) -> @sim.Snapshot {
  if self.departing is Some(view) &&
    self.rewind_elapsed <
    clock_zero_time(rewind_timing(view.level, view.life)) +
    rewind_timing(view.level, view.life).reset_delay {
    self.scene_replay.at(view, self.rewind_elapsed)
  } else {
    self.game.snapshot()
  }
}

///|
const ClockRadius : Double = 41.0

///|
const ClockTickInnerRadius : Double = 34.0

///|
const WaveHoldDuration : Double = 0.6

///|
const WaveFadeDuration : Double = 1.1

///|
priv struct RewindTiming {
  hold_duration : Double
  fade_duration : Double
  reset_delay : Double
}

///|
fn rewind_timing(level : Int32, life : Int32) -> RewindTiming {
  // The first bridge life teaches rebirth after the movement-only prologue.
  if level == 1 && life == 1 {
    {
      hold_duration: HeartDepartDelay + HeartTravelDuration + HeartBlinkDuration,
      fade_duration: 4.0,
      reset_delay: 1.6,
    }
  } else {
    {
      hold_duration: WaveHoldDuration,
      fade_duration: WaveFadeDuration,
      reset_delay: 0.0,
    }
  }
}

///|
fn clock_zero_time(timing : RewindTiming) -> Double {
  timing.hold_duration + timing.fade_duration
}

///|
// The clock and the scene travel through the same fraction of the past life.
fn rewind_remaining(elapsed : Double, timing : RewindTiming) -> Double {
  if elapsed <= timing.hold_duration {
    return 1.0
  }
  if elapsed >= clock_zero_time(timing) {
    return 0.0
  }
  let t = (elapsed - timing.hold_duration) / timing.fade_duration
  1.0 - t * t * (3.0 - 2.0 * t)
}

///|
priv struct TimeWave {
  radius : Double
  strength : Double
  clock_progress : Double
  phase : String
}

///|
fn time_wave(
  radius : Double,
  progress : Double,
  rewinding : Bool,
  elapsed : Double,
  lost : Bool,
  timing~ : RewindTiming = rewind_timing(0, 1),
) -> TimeWave {
  if lost {
    return {
      radius,
      strength: 1.0,
      clock_progress: progress,
      phase: if radius > ClockTickInnerRadius {
        "failed"
      } else {
        "growing"
      },
    }
  }
  if !rewinding {
    return {
      radius,
      strength: 1.0,
      clock_progress: progress,
      phase: if radius > ClockTickInnerRadius {
        "expanding"
      } else {
        "growing"
      },
    }
  }
  if elapsed < timing.hold_duration {
    return {
      radius: 644.0,
      strength: 1.0,
      clock_progress: progress,
      phase: "holding",
    }
  }
  if elapsed >= clock_zero_time(timing) {
    return {
      radius: 0.0,
      strength: 1.0,
      clock_progress: 0.0,
      phase: "resetting",
    }
  }
  let remaining = rewind_remaining(elapsed, timing)
  {
    radius: 644.0,
    strength: remaining,
    clock_progress: progress * remaining,
    phase: "fading",
  }
}

///|
fn clock_hour_degrees(level : Int32, progress : Double) -> Double {
  // Like a physical clock, the hour hand advances 1/12 of a minute-hand turn.
  ((@sim.level_number(level) - 1).to_double() + progress) * 30.0
}

///|
fn clock_shake(
  tick : Int32,
  wave_start_tick : Int32,
  rewinding : Bool,
  fast~ : Bool = false,
) -> @math.Vec2 {
  let warning_start = wave_start_tick - 240
  guard !rewinding && tick < wave_start_tick && (fast || tick > warning_start) else {
    return @math.Vec2(0.0, 0.0)
  }
  // Four seconds of tightening, small irregular tremors. Simulation ticks
  // make the warning pause and fast-forward with the rest of the world.
  let warning = (tick - warning_start).to_double() / 240.0
  let strength = if fast && warning < 0.55 { 0.55 } else { warning }
  let phase = tick.to_double()
  @math.Vec2(
    @trig.sin(phase * 2.4) * 3.0 * strength,
    @trig.sin(phase * 1.7 + 1.3) * 2.0 * strength,
  )
}

///|
fn draw_time_wave(wave : TimeWave) -> Unit {
  guard wave.radius > 0.0 &&
    wave.strength > 0.0 &&
    wave.phase != "growing" &&
    wave.phase != "resetting" else {
    return
  }
  // Uniform near-black purple. Actors are submitted after this opaque circle.
  @render2d.push_ui_circle({
    center: @math.Vec2(560.0, 310.0),
    radius: wave.radius,
    transform: @math.Transform(),
    alpha_mode: Blend,
    blend_mode: Alpha,
    fill_color: color(0x120b1c, alpha=wave.strength),
    stroke_color: None,
  })
}

///|
fn rewind_clock_shake(elapsed : Double, timing : RewindTiming) -> @math.Vec2 {
  let t = elapsed - timing.hold_duration
  let duration = if timing.fade_duration < 2.0 {
    timing.fade_duration
  } else {
    2.0
  }
  guard t >= 0.0 && t < duration else { return @math.Vec2(0.0, 0.0) }
  let strength = 1.0 - t / duration
  @math.Vec2(
    @trig.sin(t * 91.0) * 2.5 * strength,
    @trig.sin(t * 67.0 + 1.3) * 1.7 * strength,
  )
}

///|
// White difference-compositing strokes invert only these pixels. Geometry and
// both hand angles remain MoonBit-owned; the browser only composites the mask.
fn clock_stroke_path(
  angle : Double,
  near : Double,
  far : Double,
  width : Double,
) -> String {
  let sx = @trig.sin(angle)
  let cy = @trig.cos(angle)
  let x1 = 44.0 + sx * near - cy * width / 2.0
  let y1 = 44.0 - cy * near - sx * width / 2.0
  let x2 = 44.0 + sx * far - cy * width / 2.0
  let y2 = 44.0 - cy * far - sx * width / 2.0
  let x3 = 44.0 + sx * far + cy * width / 2.0
  let y3 = 44.0 - cy * far + sx * width / 2.0
  let x4 = 44.0 + sx * near + cy * width / 2.0
  let y4 = 44.0 - cy * near + sx * width / 2.0
  "M\{x1} \{y1}L\{x2} \{y2}L\{x3} \{y3}L\{x4} \{y4}Z"
}

///|
fn clock_face_path(level : Int32, progress : Double) -> String {
  let tau = 6.283185307179586
  let mut path = ""
  for mark in 0..<12 {
    path += clock_stroke_path(
      mark.to_double() * tau / 12.0,
      if mark % 3 == 0 {
        ClockTickInnerRadius
      } else {
        37.0
      },
      ClockRadius,
      if mark % 3 == 0 {
        2.8
      } else {
        2.0
      },
    )
  }
  path += clock_stroke_path(progress * tau, -5.0, 30.0, 2.8)
  path += clock_stroke_path(
    clock_hour_degrees(level, progress) * tau / 360.0,
    0.0,
    19.0,
    4.8,
  )
  path + "M44 41A3 3 0 1 1 44 47A3 3 0 1 1 44 41Z"
}
