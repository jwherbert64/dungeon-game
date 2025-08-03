extends Node2D

@export_enum("up", "down", "left", "right") var direction: String = "right"
@export var travel_distance: float = 100.0
@export var move_speed: float = 40.0

@onready var area: Area2D = $area
@onready var bounding_body: StaticBody2D = $bounding_body

signal platform_exited(body: Node)

var point_a: Vector2
var point_b: Vector2
var moving_to_b := true
var last_position: Vector2
var overlapping_bodies: Array = []
var platform_exit_timer := Timer.new()
var exiting_body: Node = null

func _ready() -> void:
	add_to_group("platforms")
	
	#area.body_entered.connect(_on_area_body_entered)
	#area.body_exited.connect(_on_area_body_exited)
	area.area_entered.connect(_on_area_area_entered)
	area.area_exited.connect(_on_area_area_exited)
	
	add_child(platform_exit_timer)
	platform_exit_timer.wait_time = 0.05
	platform_exit_timer.one_shot = true
	platform_exit_timer.timeout.connect(_on_platform_exit_timer_timeout)
	
	point_a = global_position
	point_b = point_a + get_direction_vector() * travel_distance
	last_position = global_position

func _physics_process(delta: float) -> void:
	var target = point_b if moving_to_b else point_a
	var direction_vector = (target - global_position).normalized()
	
	# Move platform
	global_position += direction_vector * move_speed * delta
	var movement = global_position - last_position

	# Carry any bodies standing on it
	for body in overlapping_bodies:
		if body and body.is_inside_tree():
			body.global_position += movement
	
	last_position = global_position

	if global_position.distance_to(target) < 1.0:
		moving_to_b = !moving_to_b

func get_direction_vector() -> Vector2:
	match direction:
		"up":
			return Vector2(0, -1)
		"down":
			return Vector2(0, 1)
		"left":
			return Vector2(-1, 0)
		"right":
			return Vector2(1, 0)
		_:
			return Vector2.ZERO

#func _on_area_body_entered(body: Node) -> void:
	#if body.get_parent().name == "enemies":
		## disable enemy colliding with water_tile_map
		#await get_tree().process_frame  # avoid collision loop
		#const collision_layer := 1 << 10
		#body.collision_layer &= ~collision_layer
		#body.collision_mask &= ~collision_layer
		#
	#if body.name == "water_tile_map":
		#for hitbox in bounding_body.get_children():
			#
			#hitbox.set_deferred("disabled", false)
#
#func _on_area_body_exited(body: Node) -> void:
	#if body.get_parent().name == "enemies":
		## enable enemy colliding with water_tile_map
		#await get_tree().process_frame
		#const collision_layer := 1 << 10
		#body.collision_layer |= collision_layer
		#body.collision_mask |= collision_layer
	#
	#if body.name == "water_tile_map":
		#for hitbox in bounding_body.get_children():
			#hitbox.set_deferred("disabled", true)

func _on_area_area_entered(area: Area2D) -> void:
	print("platform entered")
	var parent = area.get_parent()
	
	if parent.name == "player" or parent.is_in_group("enemies"):
		overlapping_bodies.append(parent)
		if not parent.current_platforms.has(self):
			parent.current_platforms.append(self)
	
	if parent.is_in_group("enemies"):
		pass
		# disable enemy colliding with water_tile_map
		await get_tree().process_frame  # avoid collision loop
		const collision_layer := 1 << 8
		parent.collision_layer &= ~collision_layer

func _on_area_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	
	if parent.name == "player" or parent.is_in_group("enemies"):
		print("platform exited (delayed)")
		exiting_body = parent
		platform_exit_timer.start()
	
	if parent.is_in_group("enemies"):
		# enable enemy colliding with water_tile_map
		await get_tree().process_frame
		const collision_layer := 1 << 8
		parent.collision_layer |= collision_layer

func _on_platform_exit_timer_timeout() -> void:
	if exiting_body and exiting_body.is_inside_tree():
		exiting_body.current_platforms.erase(self)
		overlapping_bodies.erase(exiting_body)
		
	if exiting_body.name == "player":
		emit_signal("platform_exited", exiting_body)
	
	exiting_body = null
