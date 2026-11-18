# Better Tile Editor authoring smoke

This directory is ignored by the gameplay project and is used only by GitHub Actions as an isolated editor-authoring fixture.

- Source: `cidwel/BetterTileEditor`
- Version: `0.3.0`
- Pinned commit: `67ce337a2b7f56dec46ac4ad40ec90e2ffca2b9d`
- Better Tile Editor license at that commit: Mozilla Public License 2.0 (`addons/better-tile-editor/LICENSE.md`)
- Upstream BetterTerrain attribution remains documented by Better Tile Editor and is not vendored into the TAMU runtime project.

CI fetches the pinned addon only into a temporary authoring project. The authoring script uses Better Tile Editor to place one tile, then bakes ordinary Godot `TileSet` and `TileMapLayer` resources after removing tool metadata. A second clean project opens those resources with neither the addon directory nor a `BetterTerrain` autoload.
