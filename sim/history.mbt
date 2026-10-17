///|
// Immutable input values in an immutable array; no recorded positions exist.
priv struct History {
  frames : ReadOnlyArray[Input]
} derive(Debug, Eq)

///|
fn History::seal(frames : Array[Input]) -> History {
  { frames: ReadOnlyArray::from_array(frames), }
}

///|
pub(all) enum Outcome {
  Playing
  Won
  Lost
} derive(Debug, Eq, ToJson)

///|
pub struct ActorView {
  id : Int32
  x : Int32
  y : Int32
  vy : Int32
  grounded : Bool
  active : Bool
  facing : Int32
  walking : Bool
  stride : Int32
  crouching : Bool
  frozen_at : Int32
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CrateView {
  id : Int32
  bounds : Rect
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PhysicsActor {
  id : Int32
  x : Int32
  y : Int32
  vy : Int32
  grounded : Bool
  crouching : Bool
} derive(Debug, Eq)

///|
pub(all) struct PhysicsFrame {
  crates : ReadOnlyArray[CrateView]
  actors : ReadOnlyArray[PhysicsActor]
}

///|
pub struct Snapshot {
  level : Int32
  life : Int32
  max_lives : Int32
  remaining_lives : Int32
  heart_collected : Bool
  inventory : Inventory
  wave_start_tick : Int32
  wave_end_tick : Int32
  wave_radius : Int32
  tick : Int32
  outcome : Outcome
  actors : ReadOnlyArray[ActorView]
  crates : ReadOnlyArray[CrateView]
  history_lengths : ReadOnlyArray[Int32]
  recording_length : Int32
  plate_a : Bool
  plate_b : Bool
  plate_c : Bool
  plate_d : Bool
  gate_openings : ReadOnlyArray[Int32]
  bridge_open : Bool
} derive(Debug, Eq, ToJson)

///|
struct Game {
  level : Int32
  mut max_lives : Int32
  life_budget : Int32
  mut heart_collected : Bool
  mut inventory : Inventory
  mut collected_hearts : ReadOnlyArray[String]
  spawns : ReadOnlyArray[Spawn]
  histories : Array[History]
  mut recording : Array[Input]
  mut actors : Array[Actor]
  mut crates : ReadOnlyArray[CrateView]
  mut tick : Int32
  mut outcome : Outcome
  mut plate_a : Bool
  mut plate_b : Bool
  mut plate_c : Bool
  mut plate_d : Bool
  gate_openings : Array[Int32]
  mut bridge_open : Bool
} derive(Debug, Eq)

///|
pub fn Game::new(
  level : Int32,
  seed~ : UInt32 = 0U,
  progress~ : RunProgress = RunProgress::new(),
) -> Game {
  let level = if level >= 0 && (level <= 4 || level == 6) { level } else { 0 }
  let offset = level_geometry(level).spawn_offset
  let spawns = ReadOnlyArray::from_array(
    [
      for spawn in spawn_positions(seed, count=progress.heart_capacity + 1) => {
        { x: spawn.x + offset.0, y: spawn.y + offset.1, }
      }
    ],
  )
  {
    level,
    max_lives: progress.heart_capacity,
    life_budget: progress.heart_capacity,
    heart_collected: if level_geometry(level).heart is Some(heart) {
      progress.collected_hearts.contains(heart.id)
    } else {
      false
    },
    inventory: progress.inventory,
    collected_hearts: progress.collected_hearts,
    spawns,
    histories: [],
    recording: [],
    actors: [Actor::new(0, spawns[0])],
    crates: [],
    tick: 0,
    outcome: Playing,
    plate_a: false,
    plate_b: false,
    plate_c: false,
    plate_d: false,
    gate_openings: if level == 6 {
      [1200, 1200, 0]
    } else {
      [0, 0, 0]
    },
    bridge_open: false,
  }
}

///|
pub fn Game::snapshot(self : Game) -> Snapshot {
  {
    level: self.level,
    life: self.actors.length(),
    max_lives: self.max_lives,
    remaining_lives: if self.outcome == Lost {
      0
    } else {
      self.life_budget - self.histories.length()
    },
    heart_collected: self.heart_collected,
    inventory: self.inventory,
    crates: self.crates,
    wave_start_tick: WaveStartTick,
    wave_end_tick: WaveEndTick,
    wave_radius: wave_radius(self.tick),
    tick: self.tick,
    outcome: self.outcome,
    actors: ReadOnlyArray::from_array(
      self.actors.map(a => {
        id: a.id,
        x: a.x,
        y: a.y,
        vy: a.vy,
        grounded: a.grounded,
        active: a.active,
        facing: a.facing,
        walking: a.walking,
        stride: a.stride,
        crouching: a.crouching,
        frozen_at: a.frozen_at,
      }),
    ),
    history_lengths: ReadOnlyArray::from_array(
      self.histories.map(h => h.frames.length()),
    ),
    recording_length: self.recording.length(),
    plate_a: self.plate_a,
    bridge_open: self.bridge_open,
    plate_b: self.plate_b,
    plate_c: self.plate_c,
    plate_d: self.plate_d,
    gate_openings: ReadOnlyArray::from_array(self.gate_openings),
  }
}

///|
pub fn Game::end_life(self : Game) -> Unit {
  guard self.outcome == Playing else { return }
  self.histories.push(History::seal(self.recording))
  self.recording = []
  if self.histories.length() >= self.life_budget {
    self.outcome = Lost
    return
  }
  self.actors = [
    for id in 0..<=self.histories.length() => Actor::new(id, self.spawns[id])
  ]
  self.tick = 0
  self.crates = []
  self.plate_a = false
  self.plate_b = false
  self.plate_c = false
  self.plate_d = false
  self.gate_openings.fill(0)
  if self.level == 6 {
    self.gate_openings[0] = 1200
    self.gate_openings[1] = 1200
  }
  self.bridge_open = false
}

///|
pub fn Game::step(
  self : Game,
  input : Input,
  physics? : (Snapshot, ReadOnlyArray[Input]) -> PhysicsFrame,
) -> Unit {
  guard self.outcome == Playing else { return }
  self.recording.push(input)
  self.freeze_swept_actors(self.tick)
  let intents = self.actors.map(actor => {
    if actor.id < self.histories.length() {
      if self.histories[actor.id].frames.get(self.tick) is Some(recorded) {
        recorded
      } else {
        if actor.frozen_at < 0 {
          actor.active = false
        }
        Input::wait()
      }
    } else {
      input
    }
  })
  let mut physical_actors : ReadOnlyArray[PhysicsActor] = []
  if is_rigid_room(self.level) && physics is Some(step_physics) {
    let frame = step_physics(
      self.snapshot(),
      ReadOnlyArray::from_array(intents),
    )
    self.crates = frame.crates
    physical_actors = frame.actors
  }
  let solids = self.colliders()
  let level = level_geometry(self.level)
  for platform in level.moving_platforms {
    let before = platform.at(self.tick)
    let after = platform.at(self.tick + 1)
    for actor in self.actors {
      actor.ride_platform(before, after, solids)
    }
  }
  for platform in level.moving_platforms {
    solids.push(platform.at(self.tick + 1))
  }
  for i, actor in self.actors {
    if physical_actors.get(i) is Some(motion) && motion.id == actor.id {
      actor.apply_physics(motion, intents[i])
    } else {
      actor.advance(intents[i], solids, drop_platforms=level.drop_platforms)
    }
  }
  self.freeze_swept_actors(self.tick + 1)
  self.resolve_puzzle()
  if (self.level != 1 || self.bridge_open) &&
    self.actors.any(a => {
      a.active &&
      a.frozen_at < 0 &&
      a.bounds().touches(level_geometry(self.level).exit)
    }) {
    self.outcome = Won
  }
  self.tick += 1
  if self.tick >= WaveEndTick ||
    self.actors.any(a => a.id == self.histories.length() && !a.active) {
    self.end_life()
  }
}
