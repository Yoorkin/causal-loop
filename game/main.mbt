///|
priv struct Session {
  mut game : @sim.Game
  mut checkpoint : @sim.RunProgress
  mut paused : Bool
  mut fast : Bool
  mut debug : Bool
  mut crate_room : CrateRoom?
  mut transition : Double
  mut departing : @sim.Snapshot?
  scene_replay : SceneReplay
  mut rewind_elapsed : Double
  mut rewind_progress : Double
  mut game_over_elapsed : Double
  mut item_flight : ItemFlight?
  mut tutorial : TutorialGuide
  mut accumulator : Double
  mut requested_level : Int32
  mut restart : Bool
  mut entity_life : Int32
  entities : Array[@entity.Entity]
  exit_icon : @asset.ImageHandle
  actor_atlas : @asset.ImageHandle
  heart_icon : @asset.ImageHandle
  heart_container_icon : @asset.ImageHandle
  acceleration_icon : @asset.ImageHandle
}

///|
fn Session::load(
  self : Session,
  level : Int32,
  progress : @sim.RunProgress,
) -> Unit {
  if self.crate_room is Some(room) {
    room.clear()
  }
  self.crate_room = if @sim.is_rigid_room(level) {
    Some(CrateRoom::new())
  } else {
    None
  }
  let progress = if self.debug {
    @sim.debug_checkpoint(level)
  } else {
    progress
  }
  self.game = @sim.Game::new(level, seed=spawn_seed(), progress~)
  self.paused = false
  self.fast = false
  self.transition = 0.0
  self.departing = None
  self.scene_replay.frames.clear()
  self.rewind_elapsed = 0.0
  self.rewind_progress = 0.0
  self.game_over_elapsed = 0.0
  self.accumulator = 0.0
  self.entity_life = 0
  self.tutorial = TutorialGuide::new()
  self.item_flight = None
}

///|
fn Session::update(self : Session) -> Unit {
  let view = self.game.snapshot()
  if self.requested_level >= 0 {
    self.load(self.requested_level, self.game.progress())
    self.requested_level = -1
    return
  }
  if self.restart {
    self.load(view.level, self.checkpoint)
    self.restart = false
    return
  }
  if @inputs.is_just_pressed(Escape) {
    self.paused = !self.paused
  }
  if !self.paused && self.item_flight is Some(flight) {
    let delta = @time.delta()
    flight.elapsed += if delta > 0.05 { 0.05 } else { delta }
    if flight.elapsed >= ItemFlightDuration {
      self.item_flight = None
    }
  }
  if view.outcome == @sim.Lost {
    // A held fast-forward key must not dismiss the final moment of failure.
    if @inputs.is_just_pressed(Space) {
      self.load(view.level, self.checkpoint)
      return
    }
    if @inputs.is_just_pressed(Enter) {
      self.paused = false
    }
    if !self.paused && self.game_over_elapsed < GameOverDuration {
      let delta = @time.delta()
      self.game_over_elapsed += if delta > 0.05 { 0.05 } else { delta }
    }
    self.fast = false
    self.accumulator = 0.0
    return
  }
  if self.departing is Some(departing) {
    if @inputs.is_just_pressed(Enter) {
      self.paused = false
    }
    if !self.paused {
      // The sweep already froze each actor on contact in the simulation.
      // Hold, rewind and pause at zero, then immediately resume the fresh world.
      let delta = @time.delta()
      self.rewind_elapsed += if delta > 0.05 { 0.05 } else { delta }
      let timing = rewind_timing(departing.level, departing.life)
      if self.rewind_elapsed >= clock_zero_time(timing) + timing.reset_delay {
        self.departing = None
        self.scene_replay.frames.clear()
      }
    }
    self.fast = false
    self.accumulator = 0.0
    return
  }
  if @inputs.is_just_pressed(Enter) {
    self.paused = false
    self.accumulator = 0.0
    return
  }
  if self.transition > 0.0 {
    if !self.paused {
      self.transition -= @time.delta()
      if self.transition < 0.0 {
        self.transition = 0.0
      }
    }
    self.fast = false
    self.accumulator = 0.0
    return
  }
  // Only a fresh key press starts fast-forward. Holding Space across a life or
  // level boundary cannot turn it back on after that boundary cancels it.
  if !@inputs.is_pressed(Space) ||
    self.paused ||
    (!self.debug && !view.inventory.time_acceleration) ||
    view.outcome != @sim.Playing ||
    view.tick >= view.wave_start_tick {
    self.fast = false
  } else if @inputs.is_just_pressed(Space) {
    self.fast = true
  }
  if self.paused || view.outcome != @sim.Playing {
    self.accumulator = 0.0
    return
  }
  let axis = (if @inputs.is_pressed(KeyD) || @inputs.is_pressed(ArrowRight) {
      1
    } else {
      0
    }) -
    (if @inputs.is_pressed(KeyA) || @inputs.is_pressed(ArrowLeft) {
      1
    } else {
      0
    })
  let input : @sim.Input = {
    axis,
    jump: @inputs.is_pressed(KeyW),
    crouch: @inputs.is_pressed(KeyS),
  }
  // Clamp catch-up after a long frame; never skip a simulation tick.
  let delta = @time.delta()
  self.accumulator += if delta > 0.25 {
    0.25
  } else if delta < 0.0 {
    0.0
  } else {
    delta
  }
  while self.accumulator >= 1.0 / 60.0 {
    let before = self.game.snapshot()
    let physics = self.crate_room.map(room => {
      fn(view, inputs) { room.step(view, inputs) }
    })
    self.game.advance_batch(input, self.fast, debug=self.debug, physics?, before_step=frame => {
      self.scene_replay.record(frame)
    })
    self.accumulator -= 1.0 / 60.0
    let after = self.game.snapshot()
    self.tutorial.advance(before, after)
    // Capture the world icon before a portal can replace its level geometry.
    for pickup in @sim.level_geometry(before.level).items {
      if !before.inventory.contains(pickup.kind) &&
        after.inventory.contains(pickup.kind) {
        self.item_flight = Some({
          x: (pickup.bounds.x + pickup.bounds.w / 2).to_double() / 10.0,
          y: (pickup.bounds.y + pickup.bounds.h / 2).to_double() / 10.0 +
          pickup_float(before.tick),
          elapsed: 0.0,
        })
      }
    }
    if after.tick >= after.wave_start_tick {
      self.fast = false
    }
    if after.outcome == @sim.Won {
      // A completed room refills its acquired containers and commits a value
      // checkpoint. Retrying discards this room's uncommitted acquisitions.
      if !self.debug {
        self.checkpoint = self.game.progress()
      }
      let flight = self.item_flight
      self.load(@sim.next_level(after.level), self.checkpoint)
      self.item_flight = flight
      self.transition = 0.55
      break
    }
    if after.life != view.life || after.outcome != @sim.Playing {
      // Only another available life rewinds. Failure retains the final state.
      self.departing = if after.outcome == @sim.Lost {
        self.scene_replay.frames.clear()
        None
      } else {
        Some(before)
      }
      self.game_over_elapsed = 0.0
      self.rewind_elapsed = 0.0
      self.rewind_progress = if before.tick >= before.wave_start_tick {
        1.0
      } else {
        before.tick.to_double() / before.wave_start_tick.to_double()
      }
      self.accumulator = 0.0
      self.fast = false
      break
    }
  }
}

///|
fn Session::sync_entities(self : Session) -> Unit {
  let view = self.visible_snapshot()
  if self.entity_life != view.life {
    for entity in self.entities {
      entity.destroy()
    }
    self.entities.clear()
    for _ in view.actors {
      self.entities.push(@entity.Entity())
    }
    self.entity_life = view.life
  }
  // Selene entities are a projection. Stable integer IDs order simulation.
  for i, actor in view.actors {
    @transform.transforms().set(
      self.entities[i],
      @transform.Transform::from_xyz(
        actor.x.to_double() / 10.0,
        actor.y.to_double() / 10.0,
        0.0,
      ),
    )
  }
}

///|
pub fn run() -> Unit {
  let session : Session = {
    game: @sim.Game::new(0, seed=spawn_seed()),
    checkpoint: @sim.RunProgress::new(),
    paused: false,
    fast: false,
    debug: false,
    crate_room: None,
    transition: 0.0,
    departing: None,
    scene_replay: { frames: [], },
    rewind_elapsed: 0.0,
    rewind_progress: 0.0,
    game_over_elapsed: 0.0,
    item_flight: None,
    tutorial: TutorialGuide::new(),
    accumulator: 0.0,
    requested_level: -1,
    restart: false,
    entity_life: 0,
    entities: [],
    exit_icon: @asset.load_image("assets/exit.svg"),
    actor_atlas: @asset.load_image("assets/actors.svg"),
    heart_icon: @asset.load_image("assets/heart.svg"),
    heart_container_icon: @asset.load_image("assets/heart-container.svg"),
    acceleration_icon: @asset.load_image("assets/time-acceleration.svg"),
  }
  browser_debug(enabled => {
    session.debug = enabled
    // Entering Debug reloads its fixed entry fixture; leaving it restores the
    // real checkpoint. Debug completions never overwrite that checkpoint.
    session.load(session.game.snapshot().level, session.checkpoint)
  })
  browser_events(
    (key, down) => {
      if down {
        match key {
          "Backspace" => session.restart = true
          "Digit1" => session.requested_level = @sim.level_for_number(1)
          "Digit2" => session.requested_level = @sim.level_for_number(2)
          "Digit3" => session.requested_level = @sim.level_for_number(3)
          "Digit4" => session.requested_level = @sim.level_for_number(4)
          "Digit5" => session.requested_level = @sim.level_for_number(5)
          "Digit6" => session.requested_level = @sim.level_for_number(6)
          _ => ()
        }
      }
    },
    () => {
      session.paused = true
      session.accumulator = 0.0
    },
  )
  // Official App + web platform overrides, with only the necessary systems.
  @app.App()
  .with_viewport_width(1120.0)
  .with_viewport_height(620.0)
  .with_fps(60)
  .add_system(PreUpdate, _ => @inputs.advanced_key_system(@time.delta()))
  .add_system(Update, _ => session.update())
  .add_system(PostUpdate, _ => session.sync_entities())
  .add_system(RenderExtract, _ => @render2d.begin_frame2d_system(0.0))
  .add_system(RenderPrepare, _ => session.draw())
  .add_system(Render, _ => @render_submit.render_submit_system(0.0))
  .run()
}
