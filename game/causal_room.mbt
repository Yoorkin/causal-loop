///|
fn draw_causal_room(level : @sim.Level, view : @sim.Snapshot) -> Unit {
  draw_tutorial(level)
  let blue = color(0x73b9e8)
  let plates = [level.plate_a, level.plate_b, level.plate_c, level.plate_d]
  let pressed = [view.plate_a, view.plate_b, view.plate_c, view.plate_d]
  for i, plate in plates {
    draw_pressure_plate(plate, pressed[i], blue)
  }
  for i, gate in level.gates {
    draw_retracting_gate(gate, view.gate_openings[i])
  }
  for platform in level.moving_platforms {
    let body = platform.at(view.tick)
    scene_rect(body, color(0x963f50))
    rect(
      body.x.to_double() / 10.0,
      body.y.to_double() / 10.0,
      body.w.to_double() / 10.0,
      3.0,
      color(0xf48b91),
    )
    for i in 0..<(body.w / 200) {
      rect(
        (body.x + i * 200).to_double() / 10.0 + 5.0,
        body.y.to_double() / 10.0 + 8.0,
        10.0,
        2.0,
        color(0xf48b91, alpha=0.4),
      )
    }
  }
}
