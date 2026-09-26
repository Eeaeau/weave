class_name WindLane3D
extends Marker3D
## Distant start and possible contact region for one player's side.

@export_range(0, 1) var side: int = 0
@export var contact_rect: Rect2 = Rect2(-1.0, -1.0, 2.0, 2.0)
