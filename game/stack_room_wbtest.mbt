///|
fn stack_step(
  game : @sim.Game,
  room : CrateRoom,
  frames : Int32,
  axis : Int32,
  jump~ : Bool = false,
) -> Unit {
  for t in 0..<frames {
    game.step({ axis, jump: jump && t == 0, crouch: false, }, physics=fn(v, i) {
      room.step(v, i)
    })
  }
}

///|
test "the left high ledge is reachable with an ordinary jump from one crate" {
  for offset in [0, 40, 80] {
    let previous = @ecs.require_current_world()
    @ecs.set_current_world(@ecs.World())
    let room = CrateRoom::new()
    defer {
      room.clear()
      @ecs.set_current_world(previous)
    }
    let game = @sim.Game::new(6)
    stack_step(game, room, 1, 0)
    guard room.players.get(0) is Some(player) else {
      fail("missing player body")
    }
    // Isolate the final jump with a crate already delivered to the ledge.
    @physics2d.set_rigid_body_translation(
      room.boxes[0].0,
      @math.Vec2(250.0 + offset.to_double() / 10.0, 402.0),
    )
    @physics2d.set_rigid_body_translation(
      player,
      @math.Vec2(265.0 + offset.to_double() / 10.0, 364.0),
    )
    stack_land(game, room)
    stack_step(game, room, 48, -1, jump=true)
    stack_land(game, room)
    let actor = game.snapshot().actors[0]
    assert_true(
      actor.x < 2260 && actor.y < 2900,
      msg="offset=\{offset} actor=\{Repr(actor)}",
    )
  }
}

///|
test "the left high ledge cannot be jumped from the bare floor" {
  for x in [2510, 2800, 3300] {
    let previous = @ecs.require_current_world()
    @ecs.set_current_world(@ecs.World())
    let room = CrateRoom::new()
    defer {
      room.clear()
      @ecs.set_current_world(previous)
    }
    let game = @sim.Game::new(6)
    stack_step(game, room, 1, 0)
    guard room.players.get(0) is Some(player) else {
      fail("missing player body")
    }
    @physics2d.set_rigid_body_translation(
      player,
      @math.Vec2(x.to_double() / 10.0, 412.0),
    )
    stack_land(game, room)
    for _ in 0..<3 {
      stack_step(game, room, 48, -1, jump=true)
      stack_land(game, room)
      assert_true(game.snapshot().actors[0].x >= 2490)
    }
  }
}

///|
test "a single pushed crate is trapped in the recess instead of skipping it" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(6)
  stack_step(game, room, 1, 0)
  @physics2d.set_rigid_body_translation(
    room.boxes[0].0,
    @math.Vec2(480.0, 402.0),
  )
  @physics2d.set_rigid_body_translation(
    room.players.get(0).unwrap(),
    @math.Vec2(530.0, 412.0),
  )
  stack_land(game, room)
  stack_step(game, room, 180, -1)
  let box = game.snapshot().crates[0].bounds
  assert_true(box.x >= 3990 && box.x + box.w <= 4610, msg="\{Repr(box)}")
  assert_true((box.y - 4500).abs() < 15)
}

///|
test "the hanging wall catches crates pushed off the upper shelf above the recess" {
  for filled in [false, true] {
    let previous = @ecs.require_current_world()
    @ecs.set_current_world(@ecs.World())
    let room = CrateRoom::new()
    defer {
      room.clear()
      @ecs.set_current_world(previous)
    }
    let game = @sim.Game::new(6)
    stack_step(game, room, 1, 0)
    guard room.players.get(0) is Some(player) else {
      fail("missing player body")
    }
    @physics2d.set_rigid_body_translation(player, @math.Vec2(600.0, 312.0))
    if filled {
      @physics2d.set_rigid_body_translation(
        room.boxes[1].0,
        @math.Vec2(400.0, 450.0),
      )
    }
    stack_land(game, room)
    stack_step(game, room, 180, -1)
    if filled {
      stack_step(game, room, 6, -1, jump=true)
      stack_step(game, room, 30, 0)
      stack_step(game, room, 60, -1)
    }
    let box = game.snapshot().crates[0].bounds
    if filled {
      assert_true(box.x + box.w < 4000, msg="filled: \{Repr(box)}")
    } else {
      assert_true(
        box.x >= 3990 && box.x + box.w <= 4610,
        msg="empty: \{Repr(box)}",
      )
      assert_true((box.y - 4500).abs() <= 15, msg="\{Repr(box)}")
    }
  }
}

///|
test "a character props a closing gate but leaves too little clearance for a crate" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(6)
  stack_step(game, room, 1, 0)
  let box = room.boxes[0].0
  @physics2d.set_rigid_body_translation(box, @math.Vec2(550.0, 402.0))
  @physics2d.set_rigid_body_translation(
    room.players.get(0).unwrap(),
    @math.Vec2(505.0, 412.0),
  )
  stack_step(game, room, 330, 0)
  let view = game.snapshot()
  let gate = @sim.gate_body(
    @sim.level_geometry(6).gates[0],
    view.gate_openings[0],
  )
  let clearance = 4500 - gate.y - gate.h
  assert_true(clearance >= 380 && clearance < 480, msg="clearance=\{clearance}")
  for _ in 0..<60 {
    @physics2d.set_rigid_body_linear_velocity(box, @math.Vec2(-180.0, 0.0))
    stack_step(game, room, 1, 0)
    assert_true(crate_bounds(box).x >= 5190)
  }
}

///|
test "upper shelves cannot bypass the lower gates through a jumping route" {
  for x in [595.0, 860.0] {
    let previous = @ecs.require_current_world()
    @ecs.set_current_world(@ecs.World())
    let room = CrateRoom::new()
    defer {
      room.clear()
      @ecs.set_current_world(previous)
    }
    let game = @sim.Game::new(6)
    stack_step(game, room, 1, 0)
    guard room.players.get(0) is Some(player) else {
      fail("missing player body")
    }
    @physics2d.set_rigid_body_translation(player, @math.Vec2(x, 312.0))
    stack_land(game, room)
    for _ in 0..<3 {
      stack_step(game, room, 48, 1, jump=true)
      stack_land(game, room)
      let wall = if x < 600.0 { 6300 } else { 9000 }
      assert_true(game.snapshot().actors[0].x + 240 <= wall + 10)
    }
  }
}

///|
test "the exit plate accepts a person and closes gradually after release" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(6)
  stack_step(game, room, 1, 0)
  guard room.players.get(0) is Some(player) else { fail("missing player body") }
  @physics2d.set_rigid_body_translation(player, @math.Vec2(120.0, 272.0))
  stack_step(game, room, 30, 0)
  assert_true(game.snapshot().plate_c)
  assert_eq(game.snapshot().gate_openings[2], 1200)
  @physics2d.set_rigid_body_translation(player, @math.Vec2(600.0, 412.0))
  stack_step(game, room, 1, 0)
  assert_false(game.snapshot().plate_c)
  assert_eq(game.snapshot().gate_openings[2], 1190)
  stack_step(game, room, 119, 0)
  assert_eq(game.snapshot().gate_openings[2], 0)
}

///|
fn stack_walk(game : @sim.Game, room : CrateRoom, target : Int32) -> Unit {
  for _ in 0..<300 {
    let v = game.snapshot()
    let x = v.actors[v.life - 1].x
    if (x - target).abs() < 20 {
      break
    }
    stack_step(game, room, 1, if x < target { 1 } else { -1 })
  }
  stack_step(game, room, 8, 0)
}

///|
fn stack_land(game : @sim.Game, room : CrateRoom) -> Unit {
  let mut stable = 0
  for _ in 0..<70 {
    stack_step(game, room, 1, 0)
    let v = game.snapshot()
    if v.actors[v.life - 1].grounded {
      stable += 1
    } else {
      stable = 0
    }
    if stable >= 3 {
      break
    }
  }
}

///|
// The hanging wall invalidates the previous timed route. Keep this regression
// active until a complete three-life route is verified without changing the timer.
test "three recorded lives solve the crate gate room in eighteen seconds" {
  for seed in [0U, 1U, 7U, 42U] {
    let previous = @ecs.require_current_world()
    @ecs.set_current_world(@ecs.World())
    let room = CrateRoom::new()
    defer {
      room.clear()
      @ecs.set_current_world(previous)
    }
    let game = @sim.Game::new(
      6,
      seed~,
      progress=@sim.RunProgress::new(heart_capacity=3),
    )
    stack_step(game, room, 15, 0)
    stack_walk(game, room, 6800)
    stack_step(game, room, 9, 0, jump=true)
    stack_step(game, room, 25, 1)
    stack_land(game, room)
    stack_step(game, room, 35, 1, jump=true)
    stack_land(game, room)
    stack_step(game, room, 120, -1)
    stack_walk(game, room, 9000)
    let first = game.snapshot()
    assert_eq(first.wave_start_tick, 1080)
    assert_true(first.crates[1].bounds.y >= 4010)
    for _ in 0..<1092 {
      if game.snapshot().life != 1 {
        break
      }
      stack_step(game, room, 1, 0)
    }
    assert_eq(game.snapshot().life, 2)
    stack_step(game, room, 25, 0)
    stack_walk(game, room, 7100)
    while game.snapshot().tick < 260 {
      stack_step(game, room, 1, 0)
    }
    stack_step(game, room, 120, -1)
    stack_step(game, room, 12, 0)
    stack_step(game, room, 9, 0, jump=true)
    stack_step(game, room, 22, 1)
    stack_land(game, room)
    stack_walk(game, room, 5050)
    stack_step(game, room, 33, 1, jump=true)
    stack_land(game, room)
    stack_step(game, room, 100, -1)
    stack_step(game, room, 6, -1, jump=true)
    stack_step(game, room, 30, 0)
    stack_step(game, room, 70, -1)
    stack_step(game, room, 22, 1, jump=true)
    stack_land(game, room)
    stack_walk(game, room, 4950)
    let filled = game.snapshot()
    assert_true((filled.crates[1].bounds.y - 4500).abs() <= 15)
    assert_true(
      filled.crates[0].bounds.x + 480 < 4000,
      msg="filled=\{Repr(filled)}",
    )
    for _ in 0..<1092 {
      if game.snapshot().life != 2 {
        break
      }
      stack_step(game, room, 1, 0)
    }
    assert_eq(game.snapshot().life, 3)
    assert_eq(game.snapshot().history_lengths, [1092, 1092])
    stack_step(game, room, 25, 0)
    stack_walk(game, room, 4800)
    stack_step(game, room, 45, -1, jump=true)
    stack_land(game, room)
    stack_step(game, room, 9, 0, jump=true)
    stack_step(game, room, 25, -1)
    stack_land(game, room)
    stack_walk(game, room, 2950)
    while game.snapshot().tick < 700 {
      stack_step(game, room, 1, 0)
    }
    stack_step(game, room, 35, 1, jump=true)
    stack_step(game, room, 12, 0)
    stack_step(game, room, 65, -1)
    stack_step(game, room, 20, -1, jump=true)
    stack_land(game, room)
    stack_step(game, room, 18, 0, jump=true)
    stack_step(game, room, 22, -1)
    stack_land(game, room)
    let activated = game.snapshot()
    assert_true(activated.plate_c)
    assert_true(activated.actors[2].x < 2500 && activated.actors[2].y < 3100)
    assert_true(
      activated.gate_openings[0] > 0 && activated.gate_openings[1] > 0,
    )
    stack_step(game, room, 50, 1)
    stack_step(game, room, 45, 1, jump=true)
    stack_walk(game, room, 9250)
    stack_step(game, room, 10, 0)
    stack_step(game, room, 55, -1)
    assert_eq(game.snapshot().outcome, @sim.Won, msg="seed=\{seed}")
  }
}
