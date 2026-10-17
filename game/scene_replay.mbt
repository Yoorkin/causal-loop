///|
// One life of presentation-only frames. The simulation still replays inputs;
// it never reads this buffer or runs the physics solver backward.
priv struct SceneReplay {
  frames : Array[@sim.Snapshot]
}

///|
fn SceneReplay::record(self : SceneReplay, view : @sim.Snapshot) -> Unit {
  if self.frames.length() > 0 {
    let last = self.frames[self.frames.length() - 1]
    if view.level != last.level ||
      view.life != last.life ||
      view.tick <= last.tick {
      self.frames.clear()
    }
  }
  if self.frames.length() < view.wave_end_tick {
    self.frames.push(view)
  }
}

///|
fn SceneReplay::at(
  self : SceneReplay,
  departing : @sim.Snapshot,
  elapsed : Double,
) -> @sim.Snapshot {
  guard self.frames.length() > 0 else { return departing }
  let remaining = rewind_remaining(
    elapsed,
    rewind_timing(departing.level, departing.life),
  )
  let index = ((self.frames.length() - 1).to_double() * remaining).to_int()
  self.frames[index]
}
