class_name TamuInteractionFeedbackAdapter
extends Node2D

const IN_RANGE_COLOR := Color("#f7d38a")
const OUT_OF_RANGE_COLOR := Color("#e87163")
const RING_WIDTH: float = 2.5

var selected_target: StringName = &""
var in_range: bool = false
var ring_radius: float = 27.0
var pulse_count: int = 0

var _scale_effect: FeedbackScaleOnceEffect
var _modulate_effect: FeedbackModulateOnceEffect


func _ready() -> void:
	_scale_effect = FeedbackScaleOnceEffect.new()
	_scale_effect.scale = 1.16
	_scale_effect.duration_sec = 0.18
	add_child(_scale_effect)

	_modulate_effect = FeedbackModulateOnceEffect.new()
	_modulate_effect.color = Color(1.18, 1.18, 1.18, 1.0)
	_modulate_effect.duration_sec = 0.16
	add_child(_modulate_effect)

	visible = false


func show_target(
	target_name: StringName,
	target_position: Vector2,
	radius: float,
	reachable: bool,
	tap_feedback: bool = false
) -> void:
	if target_name == &"":
		clear_target()
		return

	var redraw_needed := (
		selected_target != target_name
		or not position.is_equal_approx(target_position)
		or not is_equal_approx(ring_radius, radius)
		or in_range != reachable
		or not visible
	)
	selected_target = target_name
	position = target_position
	ring_radius = radius
	in_range = reachable
	visible = true

	if tap_feedback:
		pulse_count += 1
		_scale_effect.fire()
		_modulate_effect.fire()

	if redraw_needed:
		queue_redraw()


func clear_target() -> void:
	if selected_target == &"" and not visible:
		return
	selected_target = &""
	in_range = false
	visible = false
	_scale_effect.reset()
	_modulate_effect.reset()
	scale = Vector2.ONE
	modulate = Color.WHITE


func current_color() -> Color:
	return IN_RANGE_COLOR if in_range else OUT_OF_RANGE_COLOR


func _process(_delta: float) -> void:
	if not visible:
		return
	scale = _scale_effect._get_value()
	modulate = _modulate_effect._get_value()


func _draw() -> void:
	if selected_target == &"":
		return
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, current_color(), RING_WIDTH, true)
