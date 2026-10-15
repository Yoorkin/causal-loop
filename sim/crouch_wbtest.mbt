///|
test "crouch clears low obstacles and cannot stand through a roof" {
  let actor = Actor::new(0, { x: 1000, y: 4620, })
  let floor : Rect = { x: 200, y: 5000, w: 10800, h: 800, }
  let roof : Rect = { x: 1260, y: 4500, w: 600, h: 220, }
  let solids = [floor, roof]
  actor.advance(Input::wait(), solids)
  for _ in 0..<10 {
    actor.advance({ axis: 1, jump: false, crouch: false, }, solids)
  }
  assert_eq(actor.x, 1020)
  for _ in 0..<60 {
    actor.advance({ axis: 1, jump: false, crouch: true, }, solids)
  }
  assert_eq(actor.x, 1500)
  actor.advance(Input::wait(), solids)
  assert_true(actor.crouching && actor.grounded)
  assert_false(actor.bounds().touches(roof))
  for _ in 0..<60 {
    actor.advance({ axis: 1, jump: false, crouch: false, }, solids)
  }
  assert_false(actor.crouching)
  assert_eq(actor.y, 4620)
  assert_false(actor.bounds().touches(roof))
}

///|
test "a closing gate respects a crouched body and prevents standing inside it" {
  let game = Game::new(3)
  game.actors[0].x = 5810
  game.actors[0].y = 4620
  game.gate_openings[0] = 380
  for _ in 0..<20 {
    game.step({ axis: 0, jump: false, crouch: true, })
  }
  assert_eq(game.gate_openings[0], 240)
  assert_true(game.actors[0].crouching)
  game.step(Input::wait())
  assert_true(game.actors[0].crouching)
  assert_eq(game.gate_openings[0], 240)
  assert_false(
    game.actors[0].bounds().touches(gate_body(level_geometry(3).gates[0], 240)),
  )
}
