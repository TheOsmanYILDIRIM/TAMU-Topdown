extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if ProjectSettings.has_setting("autoload/BetterTerrain"):
		_fail("Clean project unexpectedly contains BetterTerrain autoload.")
		return
	var addon_path := ProjectSettings.globalize_path("res://addons/better-tile-editor")
	if DirAccess.dir_exists_absolute(addon_path):
		_fail("Clean project unexpectedly contains Better Tile Editor addon.")
		return

	var packed := load("res://out/native_map.tscn") as PackedScene
	if packed == null:
		_fail("Native TileMapLayer scene did not load.")
		return
	var root := packed.instantiate()
	var layer: TileMapLayer = root.get_node_or_null("Ground") as TileMapLayer
	if layer == null:
		root.free()
		_fail("Generated scene has no native TileMapLayer named Ground.")
		return
	if layer.tile_set == null:
		root.free()
		_fail("Generated TileMapLayer has no TileSet.")
		return
	if layer.tile_set.has_meta(&"_better_terrain"):
		root.free()
		_fail("Generated TileSet retained Better Tile Editor metadata.")
		return
	if layer.get_used_cells() != [Vector2i(2, 1)]:
		root.free()
		_fail("Generated TileMapLayer does not contain exactly the authored cell.")
		return
	if layer.get_cell_source_id(Vector2i(2, 1)) != 0:
		root.free()
		_fail("Authored cell source id changed.")
		return
	if layer.get_cell_atlas_coords(Vector2i(2, 1)) != Vector2i.ZERO:
		root.free()
		_fail("Authored cell atlas coordinate changed.")
		return

	root.free()
	print("BTE_NATIVE_CLEAN_OPEN_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
