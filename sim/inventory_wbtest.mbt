///|
test "entering any room does not grant acceleration and debug does not collect an item" {
  for level in 0..<=3 {
    let game = Game::new(level)
    assert_false(game.inventory.time_acceleration)
    let x = game.actors[0].x
    game.advance_batch({ axis: 1, jump: false, crouch: false, }, true)
    assert_eq(game.tick, 1)
    assert_eq(game.actors[0].x, x + 30)
    game.advance_batch(Input::wait(), true, debug=true)
    assert_eq(game.tick, 7)
    assert_false(game.inventory.time_acceleration)
    game.advance_batch(Input::wait(), true)
    assert_eq(game.tick, 8)
  }
}

///|
test "the end-of-bridge pickup can be collected by an active history and is idempotent" {
  let game = Game::new(1)
  game.end_life()
  game.actors[0].x = 9500
  game.actors[0].y = 4620
  game.actors[0].frozen_at = 100
  game.resolve_puzzle()
  assert_false(game.inventory.time_acceleration)
  game.actors[0].frozen_at = -1
  game.resolve_puzzle()
  assert_true(game.inventory.time_acceleration)
  let collected = game.inventory
  game.resolve_puzzle()
  assert_eq(game.inventory, collected)
}

///|
test "owned items survive death and can be carried through retry and any room without a save" {
  let game = Game::new(1, inventory={ time_acceleration: true, })
  game.end_life()
  assert_true(game.inventory.time_acceleration)
  game.end_life()
  assert_eq(game.outcome, Lost)
  assert_true(game.inventory.time_acceleration)
  for level in 0..<=3 {
    let carried = Game::new(level, inventory=game.snapshot().inventory)
    carried.advance_batch(Input::wait(), true)
    assert_eq(carried.tick, 6)
    assert_true(carried.inventory.time_acceleration)
    assert_false(Game::new(level).inventory.time_acceleration)
  }
}

///|
test "item collection depends on pickup contact rather than level number" {
  for level in 0..<=3 {
    let game = Game::new(level)
    let pickup : ItemPickup = {
      kind: TimeAcceleration,
      bounds: game.actors[0].bounds(),
    }
    game.collect_items([pickup])
    assert_true(game.inventory.time_acceleration)
    assert_eq(
      level_geometry(level).items.length(),
      if level == 1 {
        1
      } else {
        0
      },
    )
  }
}
