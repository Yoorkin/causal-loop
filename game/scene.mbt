///|
fn scene_rect(r : @sim.Rect, fill : @render.Color) -> Unit {
  rect(
    r.x.to_double() / 10.0,
    r.y.to_double() / 10.0,
    r.w.to_double() / 10.0,
    r.h.to_double() / 10.0,
    fill,
  )
}

///|
fn Session::draw(self : Session) -> Unit {
  let view = self.visible_snapshot()
  let level = @sim.level_geometry(view.level)
  rect(0.0, 0.0, 1120.0, 620.0, color(0x101923))
  for i in 0..<7 {
    let x = 38.0 + i.to_double() * 160.0
    rect(x, 110.0, 112.0, 390.0, color(0x14222c))
    rect(x, 110.0, 112.0, 2.0, color(0x20313a))
  }
  let exit_ink = if view.outcome == @sim.Won {
    color(0xe8eee9)
  } else {
    color(0x67dfdc)
  }
  if view.outcome == @sim.Won {
    rect(984.0, 404.0, 97.0, 96.0, color(0x67dfdc, alpha=0.12))
  }
  scene_rect(level.exit, {
    ..exit_ink,
    a: if view.level == 0 || view.level == 3 || view.bridge_open {
      0.18
    } else {
      0.04
    },
  })
  @render2d.push_ui_image({
    image: self.exit_icon,
    destination: {
      position: @math.Vec2(
        level.exit.x.to_double() / 10.0 - 6.0,
        level.exit.y.to_double() / 10.0 + 2.0,
      ),
      size: @math.Vec2(60.0, 60.0),
    },
    source: None,
    transform: @math.Transform(),
    uv_transform: @math.Transform(),
    repeat: NoRepeat,
    alpha_mode: Blend,
    blend_mode: Alpha,
    color: color(0xffffff),
  })
  for p in level.platforms {
    scene_rect(p, color(0x30434f))
    rect(
      p.x.to_double() / 10.0,
      p.y.to_double() / 10.0,
      p.w.to_double() / 10.0,
      3.0,
      color(0x708b98),
    )
  }
  if view.level == 0 {
    draw_tutorial(level, view, self.heart_icon)
  } else if view.level == 3 {
    draw_tunnel(level, view)
  } else {
    let bridge_x = level.bridge.x.to_double() / 10.0
    if view.bridge_open && view.level != 2 {
      scene_rect(level.bridge, color(0x67dfdc, alpha=0.75))
      for i in 0..<(level.bridge.w / 200) {
        rect(bridge_x + i.to_double() * 20.0, 503.0, 2.0, 13.0, color(0x14222d))
      }
    } else if view.level != 2 {
      for i in 0..<(level.bridge.w / 200) {
        rect(bridge_x + i.to_double() * 20.0, 501.0, 10.0, 2.0, color(0x516571))
      }
    }
    if !view.bridge_open {
      scene_rect(level.barrier, color(0xd88874, alpha=0.26))
      rect(
        level.barrier.x.to_double() / 10.0,
        240.0,
        2.0,
        260.0,
        color(0xd88874),
      )
    }
    scene_rect(
      level.plate_a,
      if view.plate_a {
        color(0x67dfdc)
      } else {
        color(0xefbf67)
      },
    )
    if view.plate_a {
      rect(90.0, 488.0, 70.0, 12.0, color(0x67dfdc, alpha=0.12))
    }
    if view.level > 1 {
      scene_rect(
        level.plate_b,
        if view.plate_b {
          color(0x67dfdc)
        } else {
          color(0xb8a1ee)
        },
      )
      if view.plate_b {
        rect(570.0, 488.0, 100.0, 12.0, color(0x67dfdc, alpha=0.12))
      }
    }
  }
  draw_item_pickups(level, view.inventory, self.acceleration_icon, view.tick)
  let progress = if self.departing is Some(_) {
    self.rewind_progress
  } else if view.tick >= view.wave_start_tick {
    1.0
  } else {
    view.tick.to_double() / view.wave_start_tick.to_double()
  }
  let timing = if self.departing is Some(departing) {
    rewind_timing(departing.level, departing.life)
  } else {
    rewind_timing(view.level, view.life)
  }
  let wave = time_wave(
    view.wave_radius.to_double() / 10.0,
    progress,
    self.departing is Some(_),
    self.rewind_elapsed,
    view.outcome == @sim.Lost,
    timing~,
  )
  draw_time_wave(wave)
  for i, actor in view.actors {
    if actor.active && i < self.entities.length() {
      if @transform.transforms().get(self.entities[i]) is Some(transform) {
        let x = transform.translation.x
        let y = transform.translation.y
        let current = i == view.actors.length() - 1
        draw_actor(actor, self.actor_atlas, x, y, view.tick, current)
      }
    }
  }
  if self.paused {
    rect(0.0, 0.0, 1120.0, 620.0, color(0x09121b, alpha=0.35))
  }
  let teaching = self.departing is Some(previous) &&
    previous.level == 1 &&
    previous.life == 1
  let flight = heart_flight(self.rewind_elapsed, teaching)
  // Only the teaching death turns the consumed HUD heart into a clock offering.
  life_hearts(
    if flight.phase == "waiting" {
      view
    } else {
      self.game.snapshot()
    },
    self.heart_icon,
  )
  draw_heart_flight(flight, self.heart_icon)
  present_heart_flight(
    flight.x,
    flight.y,
    flight.size,
    flight.opacity,
    flight.phase,
  )
  let failure_opacity = if view.outcome == @sim.Lost {
    game_over_opacity(self.game_over_elapsed)
  } else {
    0.0
  }
  draw_game_over(failure_opacity)
  if self.transition > 0.0 {
    // Reveal the new room from left to right. Simulation stays at frame zero
    // until this short portal-coloured wipe has finished.
    let edge = 1120.0 * (1.0 - self.transition / 0.55)
    rect(edge, 0.0, 1120.0 - edge, 620.0, color(0x101923))
    rect(edge - 12.0, 0.0, 12.0, 620.0, color(0x67dfdc, alpha=0.12))
    rect(edge, 0.0, 2.0, 620.0, color(0x67dfdc, alpha=0.65))
  }
  // Pickup flights remain visible across portal wipes and finish in the HUD.
  draw_inventory(
    self.game.snapshot().inventory,
    self.acceleration_icon,
    self.item_flight is Some(_),
  )
  draw_item_flight(self.item_flight, self.acceleration_icon)
  publish_view(
    ToJson::to_json(view).stringify(),
    if self.paused {
      "paused"
    } else if view.outcome == @sim.Lost {
      "game-over"
    } else if self.departing is Some(_) {
      if self.rewind_elapsed >= clock_zero_time(timing) {
        "resetting"
      } else {
        "rewind"
      }
    } else if self.transition > 0.0 {
      "transition"
    } else {
      "play"
    },
    if self.fast {
      6
    } else {
      1
    },
    failure_opacity,
    self.debug,
  )
  let shake = if self.departing is Some(_) {
    rewind_clock_shake(self.rewind_elapsed, timing)
  } else {
    clock_shake(
      view.tick,
      view.wave_start_tick,
      view.outcome == @sim.Lost,
      fast=self.fast,
    )
  }
  present_time_wave(
    wave.radius,
    wave.strength,
    wave.clock_progress,
    clock_hour_degrees(view.level, wave.clock_progress),
    self.game.snapshot().tick,
    wave.phase,
    clock_face_path(view.level, wave.clock_progress),
    shake.0,
    shake.1,
  )
}
