extends Node2D

@onready var camera: Camera2D = $camera
@onready var floor_tile_map: TileMapLayer = $tile_maps/floor_tile_map
@onready var player: CharacterBody2D = $player
@onready var enemies: Node2D = $enemies
@onready var traps: Node2D = $traps
@onready var platforms: Node2D = $platforms
@onready var health_bar: TextureProgressBar = $canvas/health_bar

var level_bounds: Rect2

func _ready() -> void:
	if player.has_signal("player_attacked"):
		player.player_attacked.connect(_on_player_attacked)
	
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
	
	for enemy in enemies.get_children():
		if enemy.has_signal("enemy_attacked"):
			enemy.enemy_attacked.connect(_on_enemy_attacked)
	
	for trap in traps.get_children():
		if trap.has_signal("trap_attacked"):
			trap.trap_attacked.connect(_on_trap_attacked)
	
	for platform in platforms.get_children():
		if platform.has_signal("platform_exited"):
			platform.platform_exited.connect(_on_platform_exited)
		
	#Handle camera
	camera.zoom = Vector2(7, 7)
	camera.enabled = true
	calculate_level_bounds()
	
	#Handle UI
	health_bar.max_value = player.health
	health_bar.value = player.health

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		var target_position = player.global_position
		camera.global_position = clamp_to_level_bounds(target_position)

func calculate_level_bounds() -> void:
	var used_rect: Rect2i = floor_tile_map.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		level_bounds = Rect2(Vector2.ZERO, Vector2.ZERO)
		return
		
	# Convert tile_size from Vector2i to Vector2 (float)
	var tile_size_i = floor_tile_map.tile_set.tile_size
	var tile_size = Vector2(tile_size_i.x, tile_size_i.y)
	
	var origin_world = floor_tile_map.global_position + Vector2(used_rect.position.x, used_rect.position.y) * tile_size
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

func _on_player_attacked(body: Node, damage: Damage) -> void:
	if body.has_method("receive_damage"):
		body.receive_damage(damage)
	elif body.get_parent().has_method("receive_damage"):
		body.get_parent().receive_damage(damage)
		
func _on_player_health_changed(new_health: int) -> void:
	health_bar.value = new_health

func _on_enemy_attacked(damage: Damage) -> void:
	player.receive_damage(damage)

func _on_trap_attacked(body: Node, damage: Damage) -> void:
	body.receive_damage(damage)

func _on_platform_exited(body: Node):
	if body.current_platforms.is_empty() && body.is_on_falling_area:
		body.start_falling()

#Project notes:
	#Layers/Masks:
		#Static:
			#1: walls
			#2: player
			#3: enemies
		#Dynamic:
			#9: water, enemy hitbox
			#10: platforms, traps, player position, enemy position
			#11: water, platforms, player position, enemy position
