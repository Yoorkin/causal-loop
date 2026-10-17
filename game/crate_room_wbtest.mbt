///|
test "Selene crates fall, settle on the floor, and stack on each other" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let physics = fn(view, inputs) { room.step(view, inputs) }
  game.step(@sim.Input::wait(), physics~)
  let initial_y = game.snapshot().crates[0].bounds.y
  for _ in 1..<360 {
    game.step(@sim.Input::wait(), physics~)
  }
  let boxes = game.snapshot().crates
  assert_eq(boxes.length(), 7)
  assert_true(initial_y < 0)
  assert_true((boxes[0].bounds.y - 5120).abs() < 10)
  assert_true((boxes[3].bounds.y - 4640).abs() < 20)
  assert_true(boxes[3].bounds.y + 480 <= boxes[0].bounds.y + 10)
  for box in boxes {
    assert_true(box.bounds.y + 480 <= 5610)
  }
  for box in room.boxes {
    assert_true(@physics2d.rigid_body_handle(box.0) is Some(_))
    assert_true(@physics2d.collider_handle(box.0) is Some(_))
  }
}

///|
test "walking pushes Selene dynamic crates without passing through their hitboxes" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let physics = fn(view, inputs) { room.step(view, inputs) }
  for _ in 0..<90 {
    game.step(@sim.Input::wait(), physics~)
  }
  for _ in 0..<180 {
    game.step({ axis: 1, jump: false, crouch: false, }, physics~)
  }
  let view = game.snapshot()
  assert_true(view.crates[0].bounds.x > 4300)
  assert_true(view.actors[0].x > 4000)
  let actor = view.actors[0]
  let body : @sim.Rect = { x: actor.x, y: actor.y, w: 240, h: 380, }
  for box in view.crates {
    assert_false(body.touches(box.bounds))
  }
  assert_eq(view.outcome, @sim.Playing)
}

///|
test "rewind removes every crate and restarts the free-fall sequence" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4, progress=@sim.RunProgress::new(heart_capacity=2))
  let physics = fn(view, inputs) { room.step(view, inputs) }
  for _ in 0..<50 {
    game.step(@sim.Input::wait(), physics~)
  }
  let before = game.snapshot().crates
  game.end_life()
  assert_eq(game.snapshot().crates.length(), 0)
  for _ in 0..<50 {
    game.step(@sim.Input::wait(), physics~)
  }
  let after = game.snapshot().crates
  assert_eq(after.length(), before.length())
  for i, box in after {
    assert_eq(box.id, before[i].id)
    // Floating-point contact solves may differ by subpixel amounts after
    // rebuilding handles; emission IDs and timing must be identical.
    assert_true((box.bounds.x - before[i].bounds.x).abs() <= 10)
    assert_true(
      (box.bounds.y - before[i].bounds.y).abs() <= 10,
      msg="crate \{i}: \{Repr(before[i])} => \{Repr(box)}",
    )
  }
  assert_eq(room.boxes.length(), before.length())
}

///|
test "Selene physics uses the same fixed steps at 1x and 6x" {
  let previous = @ecs.require_current_world()
  let normal_world = @ecs.World()
  let fast_world = @ecs.World()
  @ecs.set_current_world(normal_world)
  let normal_room = CrateRoom::new()
  @ecs.set_current_world(fast_world)
  let fast_room = CrateRoom::new()
  defer {
    @ecs.set_current_world(normal_world)
    normal_room.clear()
    @ecs.set_current_world(fast_world)
    fast_room.clear()
    @ecs.set_current_world(previous)
  }
  let normal = @sim.Game::new(4)
  let fast = @sim.Game::new(4)
  for _ in 0..<60 {
    @ecs.set_current_world(normal_world)
    for _ in 0..<6 {
      normal.step(@sim.Input::wait(), physics=fn(v, i) {
        normal_room.step(v, i)
      })
    }
    @ecs.set_current_world(fast_world)
    fast.advance_batch(@sim.Input::wait(), true, debug=true, physics=fn(v, i) {
      fast_room.step(v, i)
    })
    assert_eq(normal.snapshot(), fast.snapshot())
  }
}

///|
test "players can land on a Selene crate and walk off it" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let physics = fn(v, i) { room.step(v, i) }
  for _ in 0..<90 {
    game.step(@sim.Input::wait(), physics~)
  }
  for _ in 0..<60 {
    game.step({ axis: 1, jump: false, crouch: false, }, physics~)
  }
  game.step({ axis: 1, jump: true, crouch: false, }, physics~)
  for _ in 0..<18 {
    game.step({ axis: 1, jump: false, crouch: false, }, physics~)
  }
  for _ in 0..<40 {
    game.step(@sim.Input::wait(), physics~)
  }
  let landed = game.snapshot()
  assert_true(landed.actors[0].grounded)
  assert_true(
    (landed.actors[0].y + 380 - landed.crates[0].bounds.y).abs() <= 15,
  )
  let x = landed.actors[0].x
  for _ in 0..<20 {
    game.step({ axis: 1, jump: false, crouch: false, }, physics~)
  }
  assert_true(game.snapshot().actors[0].x > x + 300)
}

///|
test "the fifth room remains playable through its exit amid falling crates" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  for _ in 0..<700 {
    let actor = game.snapshot().actors[0]
    game.step({ axis: 1, jump: actor.grounded, crouch: false, }, physics=fn(
      v,
      i,
    ) {
      room.step(v, i)
    })
    if game.snapshot().outcome == @sim.Won {
      break
    }
  }
  assert_eq(game.snapshot().outcome, @sim.Won, msg="\{Repr(game.snapshot())}")
}

///|
test "a recorded life pushes real crates while the current life stays still" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4, progress=@sim.RunProgress::new(heart_capacity=2))
  let physics = fn(v, i) { room.step(v, i) }
  for t in 0..<270 {
    game.step(
      { axis: if t >= 90 { 1 } else { 0 }, jump: false, crouch: false, },
      physics~,
    )
  }
  game.end_life()
  for _ in 0..<270 {
    game.step(@sim.Input::wait(), physics~)
  }
  let view = game.snapshot()
  assert_true(view.crates[0].bounds.x > 4300)
  assert_true(view.actors[0].x > 4000)
  assert_true(view.actors[1].x < 1500)
}

///|
test "crates falling onto a rigid character cannot teleport it sideways or upward" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let physics = fn(v, i) { room.step(v, i) }
  game.step(@sim.Input::wait(), physics~)
  guard room.players.get(0) is Some(player) else { fail("missing player body") }
  @physics2d.set_rigid_body_translation(player, @math.Vec2(372.0, 522.0))
  for _ in 0..<700 {
    game.step(@sim.Input::wait(), physics~)
    let actor = game.snapshot().actors[0]
    assert_true((actor.x - 3720).abs() < 20, msg="x=\{actor.x}")
    assert_true((actor.y - 5220).abs() < 30, msg="y=\{actor.y}")
  }
  assert_true(@physics2d.rigid_body_handle(player) is Some(_))
  assert_eq(
    @physics2d.rigid_bodies().get(player).map(b => b.body_type),
    Some(Dynamic),
  )
}

///|
test "pushing either crate face and reversing preserves the contact side" {
  for side in [-1, 1] {
    let previous = @ecs.require_current_world()
    @ecs.set_current_world(@ecs.World())
    let room = CrateRoom::new()
    defer {
      room.clear()
      @ecs.set_current_world(previous)
    }
    let game = @sim.Game::new(4)
    let physics = fn(v, i) { room.step(v, i) }
    game.step(@sim.Input::wait(), physics~)
    guard room.players.get(0) is Some(player) else {
      fail("missing player body")
    }
    let x = if side > 0 { 900.0 } else { 824.0 }
    @physics2d.set_rigid_body_translation(player, @math.Vec2(x, 522.0))
    let crate = room.body({ x: 8500, y: 5120, w: 480, h: 480, }, true)
    room.boxes.push((crate, 99))
    for t in 0..<60 {
      let axis = if t % 60 < 45 { -side } else { side }
      game.step({ axis, jump: false, crouch: false, }, physics~)
      let actor = game.snapshot().actors[0]
      let b = crate_bounds(crate)
      if side > 0 {
        assert_true(
          actor.x >= b.x + b.w - 15,
          msg="right t=\{t} x=\{actor.x} box=\{b.x}",
        )
      } else {
        assert_true(
          actor.x + 240 <= b.x + 15,
          msg="left t=\{t} x=\{actor.x} box=\{b.x}",
        )
      }
      assert_true(
        (actor.y - 5220).abs() < 30,
        msg="side=\{side} t=\{t} y=\{actor.y}",
      )
    }
  }
}

///|
test "repeated jump and crouch contacts have no one-frame position flips" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let mut axis = 1
  for t in 0..<1000 {
    let before = game.snapshot().actors[0]
    if before.x > 8200 {
      axis = -1
    }
    if before.x < 2400 {
      axis = 1
    }
    game.step({ axis, jump: t % 45 == 0, crouch: t % 120 >= 90, }, physics=fn(
      v,
      i,
    ) {
      room.step(v, i)
    })
    let after = game.snapshot().actors[0]
    let before_feet = before.y + (if before.crouching { 240 } else { 380 })
    let after_feet = after.y + (if after.crouching { 240 } else { 380 })
    assert_true(
      (after.x - before.x).abs() <= 100,
      msg="frame \{t}: horizontal flip",
    )
    assert_true(
      (after_feet - before_feet).abs() <= 200,
      msg="frame \{t}: vertical flip",
    )
  }
}

///|
test "a rigid character can stand after crouching on the floor" {
  let previous = @ecs.require_current_world()
  @ecs.set_current_world(@ecs.World())
  let room = CrateRoom::new()
  defer {
    room.clear()
    @ecs.set_current_world(previous)
  }
  let game = @sim.Game::new(4)
  let physics = fn(v, i) { room.step(v, i) }
  for _ in 0..<30 {
    game.step(@sim.Input::wait(), physics~)
  }
  for _ in 0..<30 {
    game.step({ axis: 0, jump: false, crouch: true, }, physics~)
  }
  assert_true(game.snapshot().actors[0].crouching)
  for _ in 0..<30 {
    game.step(@sim.Input::wait(), physics~)
  }
  let actor = game.snapshot().actors[0]
  assert_false(actor.crouching)
  assert_true(actor.grounded)
  assert_true((actor.y + 380 - 5600).abs() <= 15)
}
