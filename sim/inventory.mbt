///|
pub(all) enum ItemKind {
  TimeAcceleration
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ItemPickup {
  kind : ItemKind
  bounds : Rect
} derive(Debug, Eq)

///|
pub(all) struct Inventory {
  time_acceleration : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn Inventory::empty() -> Inventory {
  { time_acceleration: false, }
}

///|
pub fn Inventory::contains(self : Inventory, kind : ItemKind) -> Bool {
  match kind {
    TimeAcceleration => self.time_acceleration
  }
}

///|
fn Inventory::collect(self : Inventory, kind : ItemKind) -> Inventory {
  if self.contains(kind) {
    self
  } else {
    { time_acceleration: true, }
  }
}

///|
fn Game::collect_items(self : Game, items : ReadOnlyArray[ItemPickup]) -> Unit {
  for pickup in items {
    if !self.inventory.contains(pickup.kind) &&
      self.actors.any(a => {
        a.active && a.frozen_at < 0 && a.bounds().touches(pickup.bounds)
      }) {
      self.inventory = self.inventory.collect(pickup.kind)
    }
  }
}
