///|
// A Debug fixture models completed earlier rooms, not extra powers granted by
// this room. Normal gameplay never calls this or infers progress from a level.
pub fn debug_checkpoint(level : Int32) -> RunProgress {
  let mut capacity = 1
  let mut inventory = Inventory::empty()
  let hearts : Array[String] = []
  for number in 1..<level_number(level) {
    let completed = level_geometry(level_for_number(number))
    if completed.heart is Some(heart) && !hearts.contains(heart.id) {
      hearts.push(heart.id)
      capacity += 1
    }
    for pickup in completed.items {
      inventory = inventory.collect(pickup.kind)
    }
  }
  {
    heart_capacity: capacity,
    inventory,
    collected_hearts: ReadOnlyArray::from_array(hearts),
  }
}
