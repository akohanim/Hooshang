@tool
const PROP = preload("res://scenes/props/material_lab/OfficeProp.tscn")
func post_import(layer: LDTKEntityLayer) -> LDTKEntityLayer:
	for data: Dictionary in layer.entities:
		var node: Node2D
		if data.identifier == "PlayerStart":
			node = Marker2D.new()
			node.name = "PlayerStart"
		else:
			node = PROP.instantiate()
			var choices: Array = data.fields.get("Variants", [])
			if not choices.is_empty():
				node.variant = str(choices[absi(str(data.iid).hash()) % choices.size()]).get_slice(".", 1)
				if node.variant.is_empty():
					node.variant = str(choices[0])
			node.z_index = -5 if data.identifier == "BackgroundProp" else 5
		node.position = data.position
		layer.add_child(node)
	return layer
