///|
priv struct CrateRoom {
  entities : Array[@entity.Entity]
  boxes : Array[(@entity.Entity, Int32)]
  gates : Array[@entity.Entity]
  players : Map[Int32, @entity.Entity]
  filter : @physics2d.CollisionFilter
  player_filter : @physics2d.CollisionFilter
  jump_held : Map[Int32, Bool]
  crouching : Map[Int32, Bool]
  mut last_tick : Int32
}

///|
fn CrateRoom::new() -> CrateRoom {
  let world_group = @physics2d.collision_group()
  let player_group = @physics2d.collision_group()
  {
    entities: [],
    boxes: [],
    gates: [],
    players: {},
    filter: @physics2d.collision_filter(world_group, [world_group, player_group]),
    player_filter: @physics2d.collision_filter(player_group, [world_group]),
    jump_held: {},
    crouching: {},
    last_tick: -1,
  }
}

///|
fn CrateRoom::body(
  self : CrateRoom,
  bounds : @sim.Rect,
  dynamic : Bool,
) -> @entity.Entity {
  let entity = @entity.Entity()
  self.entities.push(entity)
  @transform.transforms().set(
    entity,
    @transform.Transform::from_xyz(
      bounds.x.to_double() / 10.0,
      bounds.y.to_double() / 10.0,
      0.0,
    ),
  )
  @physics2d.shapes().set(
    entity,
    Rect(
      size=@math.Vec2(bounds.w.to_double() / 10.0, bounds.h.to_double() / 10.0),
      offset=@math.Vec2(0.0, 0.0),
    ),
  )
  @physics2d.colliders().set(
    entity,
    @physics2d.Collider::with_material(
      self.filter,
      friction=0.55,
      restitution=if dynamic { 0.08 } else { 0.0 },
    ),
  )
  @physics2d.rigid_bodies().set(
    entity,
    if dynamic {
      {
        ..@physics2d.RigidBody::dynamic(),
        linear_damping: 0.6,
        lock_rotation: true,
        ccd_enabled: true,
      }
    } else {
      @physics2d.RigidBody::fixed()
    },
  )
  entity
}

///|
fn CrateRoom::clear(self : CrateRoom) -> Unit {
  // Remove in reverse insertion order so Rapier reuses handle slots in the
  // same order on rewind instead of reversing the solver's body ordering.
  for i = self.entities.length() - 1; i >= 0; i = i - 1 {
    let entity = self.entities[i]
    @physics2d.colliders().remove(entity) |> ignore
    @physics2d.shapes().remove(entity) |> ignore
    @physics2d.rigid_bodies().remove(entity) |> ignore
    @physics2d.velocities().remove(entity) |> ignore
    @physics2d.resolved_velocities().remove(entity) |> ignore
    @transform.transforms().remove(entity) |> ignore
    entity.destroy()
    @physics2d.physics_step_system(1.0 / 240.0)
  }
  // Let Selene remove native bodies and contact caches before rebuilding.
  @entity.entity_flush_system(0.0)
  self.entities.clear()
  self.boxes.clear()
  self.gates.clear()
  self.players.clear()
  self.jump_held.clear()
  self.crouching.clear()
  self.last_tick = -1
}

///|
fn crate_bounds(entity : @entity.Entity) -> @sim.Rect {
  let p = @transform.transforms().get(entity).unwrap_or_default().translation
  { x: (p.x * 10.0).to_int(), y: (p.y * 10.0).to_int(), w: 480, h: 480, }
}

///|
fn CrateRoom::step(
  self : CrateRoom,
  view : @sim.Snapshot,
  inputs : ReadOnlyArray[@sim.Input],
) -> @sim.PhysicsFrame {
  if view.tick <= self.last_tick {
    self.clear()
  }
  let initializing = self.last_tick < 0
  let level = @sim.level_geometry(view.level)
  if initializing {
    @physics2d.configure_physics(
      gravity=@math.Vec2(0.0, 900.0),
      pixels_per_meter=100.0,
      max_ccd_substeps=4,
    )
    for rect in level.platforms {
      let entity = self.body(rect, false)
      if view.level == 6 &&
        (rect.y == 3500 || (rect.x == 600 && rect.y == 3100)) {
        // Smooth ledge faces let directional jumps rise along a wall instead
        // of losing their vertical speed to the walking motor's contact force.
        @physics2d.colliders().set(
          entity,
          @physics2d.Collider::with_material(self.filter, friction=0.0),
        )
      }
    }
    for rect in level.ceilings {
      self.body(rect, false) |> ignore
    }
    for gate in level.gates {
      self.gates.push(self.body(gate, false))
    }
    if view.level == 6 {
      for id, bounds in @sim.stack_room_crates() {
        self.boxes.push((self.body(bounds, true), id))
      }
    }
    // Reserve every life so replay count does not renumber dynamic bodies.
    for id in 0..<view.max_lives {
      let entity = self.body({ x: -5000, y: -5000, w: 240, h: 380, }, true)
      self.players.set(id, entity)
      @physics2d.colliders().set(
        entity,
        @physics2d.Collider::with_material(self.player_filter, active=false),
      )
    }
  }
  for i, entity in self.gates {
    let gate = @sim.gate_body(level.gates[i], view.gate_openings[i])
    @physics2d.shapes().set(
      entity,
      Rect(
        size=@math.Vec2(
          gate.w.to_double() / 10.0,
          (if gate.h > 0 { gate.h } else { 1 }).to_double() / 10.0,
        ),
        offset=@math.Vec2(0.0, 0.0),
      ),
    )
    @physics2d.colliders().set(
      entity,
      @physics2d.Collider::with_material(
        self.filter,
        friction=0.0,
        active=gate.h > 0,
      ),
    )
  }
  if view.level == 4 && view.tick % 54 == 0 && view.tick < view.wave_start_tick {
    let id = view.tick / 54
    let x = [3600, 5400, 7200][id % 3]
    let entity = self.body({ x, y: -700, w: 480, h: 480, }, true)
    self.boxes.push((entity, id))
  }
  for i, actor in view.actors {
    guard self.players.get(actor.id) is Some(entity) else { continue }
    if initializing {
      @physics2d.set_rigid_body_translation(
        entity,
        @math.Vec2(actor.x.to_double() / 10.0, actor.y.to_double() / 10.0),
      )
    }
    let frozen = actor.frozen_at >= 0
    @physics2d.rigid_bodies().set(
      entity,
      if frozen {
        @physics2d.RigidBody::fixed()
      } else {
        {
          ..@physics2d.RigidBody::dynamic(),
          gravity_scale: 2.0,
          lock_rotation: true,
          ccd_enabled: true,
        }
      },
    )
    @physics2d.colliders().set(
      entity,
      @physics2d.Collider::with_material(
        self.player_filter,
        friction=0.2,
        restitution=0.0,
        active=actor.active,
      ),
    )
    if !actor.active || frozen {
      continue
    }
    let gate_bodies = [
      for i, g in level.gates => @sim.gate_body(g, view.gate_openings[i])
    ]
    let was_crouching = self.crouching.get(actor.id).unwrap_or(false)
    let mut crouching = inputs[i].crouch
    if was_crouching && !crouching {
      // Query only newly occupied headroom. Rapier allows subpixel contact
      // penetration at the feet, which must not prevent standing on a floor.
      let standing : @sim.Rect = {
        x: actor.x + 1,
        y: actor.y - 140,
        w: 238,
        h: 140,
      }
      crouching = level.platforms.any(r => standing.touches(r)) ||
        level.ceilings.any(r => standing.touches(r)) ||
        gate_bodies.any(r => r.h > 0 && standing.touches(r)) ||
        self.boxes.any(box => standing.touches(crate_bounds(box.0)))
    }
    if crouching != was_crouching {
      let p = @transform.transforms().get(entity).unwrap_or_default().translation
      @physics2d.set_rigid_body_translation(
        entity,
        @math.Vec2(p.x, p.y + (if crouching { 14.0 } else { -14.0 })),
      )
    }
    self.crouching.set(actor.id, crouching)
    @physics2d.shapes().set(
      entity,
      Rect(
        size=@math.Vec2(24.0, if crouching { 24.0 } else { 38.0 }),
        offset=@math.Vec2(0.0, 0.0),
      ),
    )
    let jump = inputs[i].jump && !self.jump_held.get(actor.id).unwrap_or(false)
    self.jump_held.set(actor.id, inputs[i].jump)
    if jump && actor.grounded && !crouching {
      let velocity = @physics2d.rigid_body_linear_velocity(entity).unwrap_or(
        @math.Vec2(0.0, 0.0),
      )
      @physics2d.set_rigid_body_linear_velocity(
        entity,
        @math.Vec2(velocity[X], -660.0),
      )
    }
  }
  for _ in 0..<4 {
    // Input controls horizontal speed; Rapier alone resolves all contacts,
    // including pushing crates, landing, head impacts and friction.
    for i, actor in view.actors {
      if !actor.active || actor.frozen_at >= 0 {
        continue
      }
      guard self.players.get(actor.id) is Some(entity) else { continue }
      let velocity = @physics2d.rigid_body_linear_velocity(entity).unwrap_or(
        @math.Vec2(0.0, 0.0),
      )
      let speed = if self.crouching.get(actor.id).unwrap_or(false) {
        48.0
      } else {
        180.0
      }
      let vy = if velocity[Y] > 900.0 { 900.0 } else { velocity[Y] }
      let target = inputs[i].axis.to_double() * speed
      // A bounded motor avoids an infinite contact force that could hold the
      // body against a vertical wall through friction.
      let difference = target - velocity[X]
      let change = if difference > 10.0 {
        10.0
      } else if difference < -10.0 {
        -10.0
      } else {
        difference
      }
      @physics2d.set_rigid_body_linear_velocity(
        entity,
        @math.Vec2(velocity[X] + change, vy),
      )
    }
    @physics2d.physics_step_system(1.0 / 240.0)
  }
  self.last_tick = view.tick
  let crates : Array[@sim.CrateView] = self.boxes.map(box => {
    id: box.1,
    bounds: crate_bounds(box.0),
  })
  let actors = view.actors.map(actor => {
    let crouching = self.crouching.get(actor.id).unwrap_or(actor.crouching)
    let entity = self.players.get(actor.id)
    let p = entity
      .map(e => @transform.transforms().get(e).unwrap_or_default().translation)
      .unwrap_or(
        @math.Vec3(actor.x.to_double() / 10.0, actor.y.to_double() / 10.0, 0.0),
      )
    let velocity = entity
      .map(e => {
        @physics2d.rigid_body_linear_velocity(e).unwrap_or(@math.Vec2(0.0, 0.0))
      })
      .unwrap_or(@math.Vec2(0.0, 0.0))
    let x = (p.x * 10.0).to_int()
    let y = (p.y * 10.0).to_int()
    let feet = y + (if crouching { 240 } else { 380 })
    // This is a support query for jump/animation, never a position correction.
    let supported = fn(r : @sim.Rect) {
      (feet - r.y).abs() <= 15 && x + 230 > r.x && x + 10 < r.x + r.w
    }
    let grounded = velocity[Y] >= -30.0 &&
      (
        level.platforms.any(supported) ||
        crates.any(box => supported(box.bounds))
      )
    @sim.PhysicsActor::{
      id: actor.id,
      x,
      y,
      vy: (velocity[Y] / 6.0).to_int(),
      grounded,
      crouching,
    }
  })
  { crates: ReadOnlyArray::from_array(crates), actors, }
}

///|
fn draw_crate_room(level : @sim.Level, view : @sim.Snapshot) -> Unit {
  draw_tutorial(level)
  if view.level == 6 {
    let plates = [level.plate_a, level.plate_b, level.plate_c]
    let pressed = [view.plate_a, view.plate_b, view.plate_c]
    for i, plate in plates {
      draw_pressure_plate(plate, pressed[i], color(0x73b9e8))
      draw_retracting_gate(level.gates[i], view.gate_openings[i])
    }
  }
  for x in (if view.level == 4 { [360.0, 540.0, 720.0] } else { [] }) {
    rect(x - 8.0, 0.0, 64.0, 12.0, color(0x30434f))
    rect(x - 4.0, 10.0, 56.0, 3.0, color(0x708b98))
  }
  for crate in view.crates {
    let b = crate.bounds
    let x = b.x.to_double() / 10.0
    let y = b.y.to_double() / 10.0
    scene_rect(b, color(0xb08b60))
    rect(x + 4.0, y + 4.0, 40.0, 40.0, color(0x594a3e))
    rect(x + 8.0, y + 8.0, 32.0, 32.0, color(0x88704f))
    rect(x + 21.0, y + 4.0, 6.0, 40.0, color(0xb08b60))
    rect(x + 4.0, y + 21.0, 40.0, 6.0, color(0xb08b60))
    rect(x, y, 48.0, 3.0, color(0xe3c298))
  }
}
