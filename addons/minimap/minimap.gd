extends SubViewportContainer
class_name TamuMiniMapCore

# Narrow runtime adaptation of Msumri/minimap @
# f2b947cba4659632c9be0c3cb2c76b97e8a85a33 (MIT).
# Demo textures/scenes are intentionally not included.

@onready var sub_viewport: SubViewport = %SubViewport
@onready var camera_2d: Camera2D = %Camera2D
@onready var marker: Polygon2D = %Marker
@onready var border: Line2D = %Border

@export var zoom: float = 0.6
@export var window_size: Vector2i = Vector2i(160, 90)

var target: Node2D
var _map_visible: bool = true


func _ready() -> void:
	sub_viewport.size = window_size
	camera_2d.zoom = Vector2(zoom, zoom)
	_layout_overlay()
	set_map_visible(_map_visible)


func set_target(value: Node2D) -> void:
	target = value
	_sync_world()
	_sync_target()


func set_map_visible(value: bool) -> void:
	_map_visible = value
	visible = value
	set_process(value)
	if not is_node_ready():
		return
	sub_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	)
	if value:
		_sync_world()
		_sync_target()


func is_rendering() -> bool:
	return (
		is_node_ready()
		and visible
		and sub_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED
	)


func camera_world_position() -> Vector2:
	if not is_node_ready():
		return Vector2.ZERO
	# Keep coordinate queries accurate while hidden without re-enabling viewport
	# rendering or continuous processing.
	_sync_target()
	return camera_2d.global_position


func marker_screen_position() -> Vector2:
	return marker.position if is_node_ready() else Vector2.ZERO


func _process(_delta: float) -> void:
	_sync_target()


func _sync_world() -> void:
	if not is_node_ready() or target == null or not is_instance_valid(target):
		return
	var target_world := target.get_world_2d()
	if sub_viewport.world_2d != target_world:
		sub_viewport.world_2d = target_world


func _sync_target() -> void:
	if not is_node_ready() or target == null or not is_instance_valid(target):
		return
	_sync_world()
	# The shared World2D camera must consume world coordinates. target.position would
	# be wrong whenever the player's parent is translated/scaled/rotated.
	camera_2d.global_position = target.global_position


func _layout_overlay() -> void:
	var center := Vector2(window_size) * 0.5
	marker.position = center
	border.clear_points()
	border.add_point(Vector2(2.5, 2.5))
	border.add_point(Vector2(float(window_size.x) - 2.5, 2.5))
	border.add_point(Vector2(float(window_size.x) - 2.5, float(window_size.y) - 2.5))
	border.add_point(Vector2(2.5, float(window_size.y) - 2.5))
	border.add_point(Vector2(2.5, 2.5))
