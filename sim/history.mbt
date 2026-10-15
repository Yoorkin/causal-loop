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
pub struct Snapshot {
  level : Int32
  life : Int32
  max_lives : Int32
  heart_collected : Bool
  inventory : Inventory
  wave_start_tick : Int32
  wave_end_tick : Int32
  wave_radius : Int32
  tick : Int32
  outcome : Outcome
  actors : ReadOnlyArray[ActorView]
  history_lengths : ReadOnlyArray[Int32]
  recording_length : Int32
  plate_a : Bool
  plate_b : Bool
  plate_c : Bool
  gate_openings : ReadOnlyArray[Int32]
  bridge_open : Bool
} derive(Debug, Eq, ToJson)

///|
struct Game {
  level : Int32
  mut max_lives : Int32
  mut heart_collected : Bool
  mut inventory : Inventory
  spawns : ReadOnlyArray[Spawn]
  histories : Array[History]
  mut recording : Array[Input]
  mut actors : Array[Actor]
  mut tick : Int32
  mut outcome : Outcome
  mut plate_a : Bool
  mut plate_b : Bool
  mut plate_c : Bool
  gate_openings : Array[Int32]
  mut bridge_open : Bool
} derive(Debug, Eq)

///|
pub fn Game::new(
  level : Int32,
  seed~ : UInt32 = 0U,
  inventory~ : Inventory = Inventory::empty(),
) -> Game {
  let level = if level >= 0 && level <= 3 { level } else { 0 }
  let spawns = spawn_positions(seed)
  {
    level,
    max_lives: if level == 0 {
      1
    } else if level == 1 || level == 3 {
      2
    } else {
      3
    },
    heart_collected: false,
    inventory,
    spawns,
    histories: [],
    recording: [],
    actors: [Actor::new(0, spawns[0])],
    tick: 0,
    outcome: Playing,
    plate_a: false,
    plate_b: false,
    plate_c: false,
    gate_openings: [0, 0, 0],
    bridge_open: false,
  }
}

///|
pub fn Game::snapshot(self : Game) -> Snapshot {
  {
    level: self.level,
    life: self.actors.length(),
    max_lives: self.max_lives,
    heart_collected: self.heart_collected,
    inventory: self.inventory,
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
    gate_openings: ReadOnlyArray::from_array(self.gate_openings),
  }
}

///|
pub fn Game::end_life(self : Game) -> Unit {
  guard self.outcome == Playing else { return }
  self.histories.push(History::seal(self.recording))
  self.recording = []
  if self.histories.length() >= self.max_lives {
    self.outcome = Lost
    return
  }
  self.actors = [
    for id in 0..<=self.histories.length() => Actor::new(id, self.spawns[id])
  ]
  self.tick = 0
  self.plate_a = false
  self.plate_b = false
  self.plate_c = false
  self.gate_openings.fill(0)
  self.bridge_open = false
}

///|
pub fn Game::step(self : Game, input : Input) -> Unit {
  guard self.outcome == Playing else { return }
  self.recording.push(input)
  self.freeze_swept_actors(self.tick)
  let solids = self.colliders()
  let level = level_geometry(self.level)
  for actor in self.actors {
    if actor.id < self.histories.length() {
      if self.histories[actor.id].frames.get(self.tick) is Some(recorded) {
        actor.advance(recorded, solids, drop_platforms=level.drop_platforms)
      } else if actor.frozen_at < 0 {
        actor.active = false
      }
    } else {
      actor.advance(input, solids, drop_platforms=level.drop_platforms)
    }
  }
  self.freeze_swept_actors(self.tick + 1)
  self.resolve_puzzle()
  if (self.level == 0 || self.level == 3 || self.bridge_open) &&
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
