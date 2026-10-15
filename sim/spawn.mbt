///|
priv struct Spawn {
  x : Int32
  y : Int32
} derive(Debug, Eq)

///|
// Three jittered, shuffled positions keep the combined bodies inside a 72 px
// zone. Their separation makes the lives legible without re-rolling a replay.
fn spawn_positions(seed : UInt32) -> ReadOnlyArray[Spawn] {
  let mut state = seed
  let positions = []
  for slot in 0..<3 {
    state = state * 1664525U + 1013904223U
    positions.push(
      2160 + slot * 200 + ((state >> 16) % 81U).reinterpret_as_int(),
    )
  }
  for i in [2, 1] {
    state = state * 1664525U + 1013904223U
    let j = ((state >> 16) % (i + 1).reinterpret_as_uint()).reinterpret_as_int()
    let saved = positions[i]
    positions[i] = positions[j]
    positions[j] = saved
  }
  // Sample a small independent vertical offset after choosing horizontal slots.
  let spawns : Array[Spawn] = [
    for x in positions => {
      state = state * 1664525U + 1013904223U
      { x, y: 3880 + ((state >> 16) % 201U).reinterpret_as_int(), }
    }
  ]
  ReadOnlyArray::from_array(spawns)
}
