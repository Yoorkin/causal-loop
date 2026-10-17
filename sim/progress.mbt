///|
// A value checkpoint contains acquisitions, never level-specific allowances.
pub struct RunProgress {
  heart_capacity : Int32
  inventory : Inventory
  collected_hearts : ReadOnlyArray[String]
} derive(Debug, Eq, ToJson)

///|
pub fn RunProgress::new(
  heart_capacity~ : Int32 = 1,
  inventory~ : Inventory = Inventory::empty(),
) -> RunProgress {
  {
    heart_capacity: if heart_capacity < 1 {
      1
    } else {
      heart_capacity
    },
    inventory,
    collected_hearts: [],
  }
}

///|
pub fn Game::progress(self : Game) -> RunProgress {
  {
    heart_capacity: self.max_lives,
    inventory: self.inventory,
    collected_hearts: self.collected_hearts,
  }
}

///|
pub struct HeartPickup {
  id : String
  bounds : Rect
} derive(Debug, Eq)
