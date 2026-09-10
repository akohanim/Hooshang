@tool
## Collision belongs only to the plain IntGrid swatches, never decorative atlases.
func post_import(level: LDTKLevel) -> LDTKLevel:
	for child in level.get_children():
		if child is TileMapLayer:
			child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			child.collision_enabled = child.name == "Solids-values"
			if child.name == "Solids-values":
				child.visible = false
			elif child.name == "BackgroundGeometry-values":
				child.visible = false
			elif child.name == "BackgroundArt":
				child.z_index = -10
				child.set_script(preload("res://scripts/material_lab_background.gd"))
	return level
