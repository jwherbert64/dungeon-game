extends Node2D

@onready var floor: TileMapLayer = $tile_maps/floor
@onready var player: CharacterBody2D = $player
@onready var enemies: Node2D = $enemies
@onready var trap: Node2D = $trap
@onready var camera: Camera2D = $camera

var level_bounds: Rect2

func _ready() -> void:
	camera.zoom = Vector2(7, 7)
	camera.enabled = true
	calculate_level_bounds()
	
	if player.has_signal("player_attacked"):
		player.player_attacked.connect(_on_player_attacked)
	
	for enemy in enemies.get_children():
		if enemy.has_signal("enemy_attacked"):
			enemy.enemy_attacked.connect(_on_enemy_attacked)
			
	if trap.has_signal("trap_attacked"):
		trap.trap_attacked.connect(_on_trap_attacked)

func _process(delta: float) -> void:
	if is_instance_valid(player):
		var target_position = player.global_position
		camera.global_position = clamp_to_level_bounds(target_position)

func calculate_level_bounds() -> void:
	var used_rect: Rect2i = floor.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		level_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
		return
		
	# Convert tile_size from Vector2i to Vector2 (float)
	var tile_size_i = floor.tile_set.tile_size
	var tile_size = Vector2(tile_size_i.x, tile_size_i.y)
	
	var origin_world = floor.global_position + Vector2(used_rect.position.x, used_rect.position.y) * tile_size
	var size = Vector2(used_rect.size.x, used_rect.size.y) * tile_size
	
	level_bounds = Rect2(origin_world, size)

func clamp_to_level_bounds(pos: Vector2) -> Vector2:
	var viewport_size = get_viewport_rect().size
	var zoom = camera.zoom
	var visible_world_size = viewport_size / zoom
	var half_visible = visible_world_size / 2.0
	
	var min_x: float
	var max_x: float
	var min_y: float
	var max_y: float
	
	if level_bounds.size.x < visible_world_size.x:
		min_x = level_bounds.position.x + level_bounds.size.x / 2
		max_x = min_x
	else:
		min_x = level_bounds.position.x + half_visible.x
		max_x = level_bounds.position.x + level_bounds.size.x - half_visible.x
		
	if level_bounds.size.y < visible_world_size.y:
		min_y = level_bounds.position.y + level_bounds.size.y / 2
		max_y = min_y
	else:
		min_y = level_bounds.position.y + half_visible.y
		max_y = level_bounds.position.y + level_bounds.size.y - half_visible.y
		
	return Vector2(
		clamp(pos.x, min_x, max_x),
		clamp(pos.y, min_y, max_y)
	)

func _on_player_attacked(enemy: Node, from_position: Vector2, amount: int) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(from_position, amount)

func _on_enemy_attacked(from_position: Vector2, amount: int) -> void:
	player.take_damage(from_position, amount)

func _on_trap_attacked(body: Node, from_position: Vector2, amount: int) -> void:
	print('hit main')
	body.take_damage(from_position, amount)
