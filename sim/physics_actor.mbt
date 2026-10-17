///|
// Selene owns the entire physical pose in the crate room. Only animation and
// lifecycle state are derived here; never resolve its contacts a second time.
fn Actor::apply_physics(
  self : Actor,
  motion : PhysicsActor,
  input : Input,
) -> Unit {
  guard self.active && self.frozen_at < 0 else { return }
  self.x = motion.x
  self.y = motion.y
  self.vy = motion.vy
  self.grounded = motion.grounded
  self.crouching = motion.crouching
  self.jump_held = input.jump
  self.crouch_held = input.crouch
  if input.axis != 0 {
    self.facing = if input.axis > 0 { 1 } else { -1 }
  }
  self.walking = self.grounded && input.axis != 0
  let stride_ticks = if self.crouching { 64 } else { 32 }
  self.stride = if self.walking { (self.stride + 1) % stride_ticks } else { 0 }
  if self.y > 6800 {
    self.active = false
  }
}
