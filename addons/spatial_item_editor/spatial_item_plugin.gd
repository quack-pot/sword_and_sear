@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin

func _enter_tree() -> void:
	_inspector_plugin = preload("spatial_item_inspector_plugin.gd").new()
	add_inspector_plugin(_inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)
