@tool
extends EditorInspectorPlugin

const GridPatternEditor := preload("grid_pattern_editor.gd")

func _can_handle(object: Object) -> bool:
	return object is SpatialItem

func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:
	if name == "grid_pattern":
		add_property_editor(name, GridPatternEditor.new())
		return true
	
	return false
