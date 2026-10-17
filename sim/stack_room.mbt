///|
// Both rigid-body rooms share the same contact solver.
pub fn is_rigid_room(id : Int32) -> Bool {
  id == 4 || id == 6
}

///|
pub fn next_level(id : Int32) -> Int32 {
  match id {
    0 => 1
    1 => 3
    3 => 2
    2 => 4
    4 => 6
    _ => 0
  }
}

///|
pub fn stack_room_crates() -> ReadOnlyArray[Rect] {
  [
    { x: 5400, y: 3020, w: 480, h: 480, },
    { x: 7800, y: 3020, w: 480, h: 480, },
    { x: 1650, y: 2620, w: 480, h: 480, },
  ]
}

///|
fn stack_room_geometry() -> Level {
  let empty : Rect = { x: 0, y: 0, w: 0, h: 0, }
  {
    id: 6,
    spawn_offset: (4000, -130),
    moving_platforms: [],
    platforms: [
      // A box-sized recess in the otherwise continuous middle floor.
      { x: 2500, y: 4500, w: 1500, h: 700, },
      { x: 4000, y: 4980, w: 600, h: 220, },
      { x: 4600, y: 4500, w: 4600, h: 700, },
      // The two upper shelves join a ceiling-height central partition.
      { x: 5000, y: 3500, w: 1500, h: 40, },
      { x: 7200, y: 3500, w: 1800, h: 40, },
      // 140px above the floor, but only 92px above a delivered 48px crate.
      // Leave clearance for a diagonal jump with native wall friction.
      { x: 600, y: 3100, w: 1900, h: 2900, },
      { x: 2500, y: 5200, w: 1500, h: 800, },
      { x: 600, y: 6000, w: 10400, h: 200, },
    ],
    ceilings: [
      { x: 400, y: 600, w: 200, h: 5600, },
      { x: 600, y: 600, w: 10400, h: 200, },
      // Catch airborne crates above the recess; leave 90px below for the
      // intended ground-level crossing after another crate fills the slot.
      { x: 4000, y: 800, w: 200, h: 2800, },
      { x: 6300, y: 800, w: 200, h: 2700, },
      { x: 11000, y: 600, w: 200, h: 5600, },
      { x: 9000, y: 800, w: 200, h: 2740, },
    ],
    drop_platforms: [],
    heart: None,
    items: [],
    plate_a: { x: 5400, y: 3440, w: 850, h: 60, },
    plate_b: { x: 7600, y: 3440, w: 1300, h: 60, },
    plate_c: { x: 1150, y: 3040, w: 450, h: 60, },
    plate_d: empty,
    gates: [
      { x: 5000, y: 3540, w: 200, h: 960, },
      { x: 9000, y: 3540, w: 200, h: 960, },
      { x: 9000, y: 5200, w: 200, h: 800, },
    ],
    bridge: empty,
    barrier: empty,
    exit: { x: 8400, y: 5400, w: 500, h: 600, },
  }
}
