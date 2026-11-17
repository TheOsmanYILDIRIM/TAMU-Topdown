class_name TamuSurvivalAdapter
extends Node
## Ticks Survival Core Lite exactly once and routes deprivation damage into the existing ClutteredCode Health.

@export var auto_tick: bool = true
@export var damage_interval_sec: float = 1.0
@export var damage_per_deprived_need: int = 2
@export var clock_path: NodePath = ^"../DayNightClock"
@export var stats_path: NodePath = ^"../SurvivalStats"
@export var health_path: NodePath = ^"../Player/Health"
@export var world_tint_path: NodePath = ^"../WorldTint"

var clock: DayNightClock
var stats: SurvivalStats
var health: Health
var world_tint: CanvasModulate
var _deprivation_elapsed: float = 0.0

func _ready() -> void:
	clock = get_node(clock_path) as DayNightClock
	stats = get_node(stats_path) as SurvivalStats
	health = get_node(health_path) as Health
	world_tint = get_node(world_tint_path) as CanvasModulate
	assert(clock != null, "DayNightClock is required.")
	assert(stats != null, "SurvivalStats is required.")
	assert(health != null, "Existing player Health is required.")
	assert(world_tint != null, "World CanvasModulate is required.")
	_apply_light()

func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	clock.tick(delta)
	stats.tick(delta)
	_apply_light()

	if health.is_dead():
		_deprivation_elapsed = 0.0
		return

	var deprived_needs := int(stats.hunger <= 0.0) + int(stats.thirst <= 0.0)
	if deprived_needs == 0:
		_deprivation_elapsed = 0.0
		return

	var interval := maxf(damage_interval_sec, 0.001)
	_deprivation_elapsed += delta
	while _deprivation_elapsed + 0.000001 >= interval:
		_deprivation_elapsed -= interval
		if health.is_dead():
			_deprivation_elapsed = 0.0
			return
		health.damage(damage_per_deprived_need * deprived_needs)

func reset_damage_clock() -> void:
	_deprivation_elapsed = 0.0

func _apply_light() -> void:
	var level := clock.light_level()
	world_tint.color = Color(level, level, level, 1.0)
