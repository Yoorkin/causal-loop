///|
// A fast-forward batch is six ordinary ticks. Input is neutral for the whole
// batch. Stop at a lifecycle boundary; never consume the next life's first tick.
pub fn Game::advance_batch(
  self : Game,
  input : Input,
  fast : Bool,
  debug~ : Bool = false,
) -> Unit {
  let fast = fast && (self.inventory.time_acceleration || debug)
  let life = self.histories.length()
  // Keep the threatening sweep readable and controllable at normal speed.
  let count = if fast && self.tick < WaveStartTick { 6 } else { 1 }
  for _ in 0..<count {
    if self.outcome != Playing || self.histories.length() != life {
      break
    }
    self.step(
      if fast && self.tick < WaveStartTick {
        Input::wait()
      } else {
        input
      },
    )
    if count > 1 && self.tick >= WaveStartTick {
      break
    }
  }
}
