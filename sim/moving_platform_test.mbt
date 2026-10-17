///|
test "red platform docks flush for half a second at both banks before reversing" {
  let platform = @sim.level_geometry(2).moving_platforms[0]
  for cycle in [0, 660, 1320] {
    // Right arrival at 11 1/2 s; left arrival at 6 s. Thirty stationary
    // frame intervals at either dock must not reduce the travel speed.
    for tick in 690..<=720 {
      let body = platform.at(cycle + tick)
      assert_eq(body.x + body.w, 9800)
      assert_eq(body.y, 4800)
    }
    for tick in 360..<=390 {
      assert_eq(platform.at(cycle + tick).x, 5900)
    }
    assert_eq(platform.at(cycle + 689).x, 8890)
    assert_eq(platform.at(cycle + 721).x, 8890)
    assert_eq(platform.at(cycle + 359).x, 5910)
    assert_eq(platform.at(cycle + 391).x, 5910)
  }
}
