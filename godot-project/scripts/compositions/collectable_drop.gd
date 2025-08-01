extends Node

@export var drop_scene: PackedScene
@export var y_offset := Vector2(0, 1)

func drop_collectable(at_position: Vector2):
	if drop_scene:
		var instance = drop_scene.instantiate()
		instance.global_position = at_position - y_offset
		get_tree().current_scene.get_node("collectables").add_child(instance)
