extends Node

static func disable_all_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.hide()
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = true
		if child is Area2D:
			child.monitoring = false
			child.monitorable = false
		if child is PhysicsBody2D:
			child.set_physics_process(false)
		disable_all_children(child)

static func enable_all_children(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			child.show()
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = false
		if child is Area2D:
			child.monitoring = true
			child.monitorable = true
		if child is PhysicsBody2D:
			child.set_physics_process(true)
		enable_all_children(child)
