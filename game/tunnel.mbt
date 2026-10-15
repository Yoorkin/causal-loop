///|
fn draw_tunnel(level : @sim.Level, view : @sim.Snapshot) -> Unit {
  let orange = color(0xeaa06b)
  for ceiling in level.ceilings {
    scene_rect(ceiling, color(0x22333f))
    rect(
      ceiling.x.to_double() / 10.0,
      (ceiling.y + ceiling.h).to_double() / 10.0 - 3.0,
      ceiling.w.to_double() / 10.0,
      3.0,
      color(0x708b98),
    )
  }
  let plates = [level.plate_a, level.plate_b, level.plate_c]
  let pressed = [view.plate_a, view.plate_b, view.plate_c]
  for i, gate in level.gates {
    let plate = plates[i]
    let px = plate.x.to_double() / 10.0
    let py = plate.y.to_double() / 10.0
    let pw = plate.w.to_double() / 10.0
    let gx = gate.x.to_double() / 10.0
    let gy = gate.y.to_double() / 10.0
    let gh = gate.h.to_double() / 10.0
    let active = pressed[i]
    let wire = { ..orange, a: if active { 0.7 } else { 0.16 }, }
    let track_y = 194.0 - i.to_double() * 18.0
    // Wiring identifies each plate/door pair without duplicate number markers.
    rect(px + pw / 2.0, track_y, 1.0, py - track_y, wire)
    rect(px + pw / 2.0, track_y, gx + 10.0 - px - pw / 2.0, 1.0, wire)
    rect(gx + 10.0, track_y, 1.0, gy - track_y, wire)
    scene_rect(plate, if active { color(0xffe2b8) } else { orange })
    if active {
      rect(px, py - 5.0, pw, 11.0, { ..orange, a: 0.18, })
    }
    // Empty rails remain visible while the gate retracts into the roof.
    rect(gx - 3.0, gy, 2.0, gh, { ..orange, a: 0.20, })
    rect(gx + 21.0, gy, 2.0, gh, { ..orange, a: 0.20, })
    rect(gx - 6.0, gy - 6.0, 32.0, 6.0, orange)
    let body = @sim.gate_body(gate, view.gate_openings[i])
    if body.h > 0 {
      let height = body.h.to_double() / 10.0
      scene_rect(body, color(0x80553e))
      for stripe in 0..<(body.h / 100) {
        rect(gx + 2.0, gy + stripe.to_double() * 10.0 + 3.0, 16.0, 2.0, orange)
      }
      rect(gx, gy + height - 3.0, 20.0, 3.0, color(0xffc58d))
    }
  }
}
