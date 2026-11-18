extends SceneTree

const OUTPUT_DIR := "res://out"
const TILESET_PATH := OUTPUT_DIR + "/native_tileset.tres"
const SCENE_PATH := OUTPUT_DIR + "/native_map.tscn"
const TOOL_META := &"_better_terrain"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _author_native_resources()
	if result != OK:
		push_error("Better Tile Editor authoring smoke failed with error %d." % result)
		quit(result)
		return
	print("BTE_NATIVE_AUTHOR_OK")
	quit(0)


func _author_native_resources() -> int:
	var texture := load("res://native_tile.svg") as Texture2D
	if texture == null:
		return ERR_FILE_CANT_READ

	var output_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIR)
	)
	if output_error != OK and output_error != ERR_ALREADY_EXISTS:
		return output_error

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)

	var terrain_tool := get_root().get_node_or_null("BetterTerrain")
	if terrain_tool == null:
		return ERR_DOES_NOT_EXIST
	terrain_tool.call("set_single_tile", tile_set, 0, Vector2i.ZERO)
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tile_set
	var placed := bool(terrain_tool.call(
		"set_cells",
		layer,
		[Vector2i(2, 1)],
		-4
	))
	if not placed:
		layer.free()
		return FAILED

	if tile_set.has_meta(TOOL_META):
		tile_set.remove_meta(TOOL_META)
	if layer.has_meta(TOOL_META):
		layer.remove_meta(TOOL_META)
	if layer.has_meta(&"_better_terrain_hand_placed"):
		layer.remove_meta(&"_better_terrain_hand_placed")
	if layer.has_meta(&"_better_terrain_seams"):
		layer.remove_meta(&"_better_terrain_seams")

	var save_error := ResourceSaver.save(tile_set, TILESET_PATH)
	if save_error != OK:
		layer.free()
		return save_error

	var baked_tile_set := load(TILESET_PATH) as TileSet
	if baked_tile_set == null:
		layer.free()
		return ERR_FILE_CANT_READ
	layer.tile_set = baked_tile_set

	var root := Node2D.new()
	root.name = "BetterTileEditorNativeSample"
	root.add_child(layer)
	layer.owner = root

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		root.free()
		return pack_error
	save_error = ResourceSaver.save(packed, SCENE_PATH)
	root.free()
	return save_error
