extends CharacterBody2D
class_name Enemy
const NodeUtils = preload("res://scripts/utils/node_utils.gd")

@onready var state_machine: Node = $state_machine
@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var chasing_area: Area2D = $chasing_area
@onready var attacking_area: Area2D = $attacking_area
@onready var collectable_drop: Node = $collectable_drop

signal enemy_attacked(damage: Damage)

var initial_health := 60
var health := 60
var damage_amount := 20

var idle_move_speed: float = 10.0  # Slower than chase speed
var idle_target_position: Vector2 = Vector2.ZERO
var idle_wander_radius: float = 64.0  # Radius around spawn to wander
var idle_timer := Timer.new()

var is_in_chasing_range = false
var chasing_move_speed: float = 30.0

var is_in_attacking_range = false
var attacking_timer := Timer.new()
var attacking_on_cooldown = false

var spawn_position := Vector2.ZERO
var respawn_timer := Timer.new()

var player: CharacterBody2D = null
var current_platforms: Array = []

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	
	idle_timer.wait_time = 2.0  # Change direction every 2 seconds
	idle_timer.one_shot = false
	idle_timer.autostart = true
	add_child(idle_timer)
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	
	chasing_area.body_entered.connect(_on_chasing_area_entered)
	chasing_area.body_exited.connect(_on_chasing_area_exited)
	
	attacking_timer.wait_time = 0.1 
	attacking_timer.one_shot = true
	add_child(attacking_timer)
	attacking_area.body_entered.connect(_on_attacking_area_entered)
	attacking_area.body_exited.connect(_on_attacking_area_exited)
	attacking_timer.timeout.connect(_on_attacking_timer_timeout)
	
	respawn_timer.wait_time = 3.0
	respawn_timer.one_shot = true
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	
	# Set first wander point
	_on_idle_timer_timeout()
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if state_machine.current_state.name in ["damaged", "died"]:
		velocity = velocity.move_toward(Vector2.ZERO, 1200 * delta)  # smooth deceleration
		move_and_slide()
		return
	
	# Determine current state based on area status
	if is_in_attacking_range:
		state_machine.transition("attacking")
	elif is_in_chasing_range:
		state_machine.transition("chasing")
	else:
		state_machine.transition("idle")

	match state_machine.current_state.name:
		"idle":
			# Move toward the idle target position
			var direction = (idle_target_position - global_position)
			if direction.length() > 4.0:
				velocity = direction.normalized() * idle_move_speed
			else:
				velocity = Vector2.ZERO
		"chasing":
			if player:
				var direction = (player.global_position - global_position).normalized()
				velocity = direction * chasing_move_speed
			else:
				velocity = Vector2.ZERO
		"attacking":
			if player:
				var to_player = player.global_position - global_position
				var distance = to_player.length()
				
				# Apply gentle separation if too close
				if distance < 16:
					velocity = -to_player.normalized() * 40
				else:
					velocity = Vector2.ZERO
				
				# Perform attack
				if not attacking_on_cooldown:
					var damage = Damage.new()
					damage.from_position = global_position
					damage.amount = damage_amount
					emit_signal("enemy_attacked", damage)
					
					attacking_on_cooldown = true
					attacking_timer.start()
			else:
				velocity = Vector2.ZERO
	
	move_and_slide()
	sprite.play("idle")

func respawn() -> void:
	global_position = spawn_position
	health = initial_health
	velocity = Vector2.ZERO
	NodeUtils.enable_all_children(self)
	state_machine.transition("idle")
	sprite.play("idle")

func _on_idle_timer_timeout() -> void:
	# Pick a new random target around spawn position
	var angle = randf() * TAU
	var distance = randf_range(16.0, idle_wander_radius)
	idle_target_position = spawn_position + Vector2.RIGHT.rotated(angle) * distance

func _on_chasing_area_entered(body: Node) -> void:
	if body.name == "player":
		player = body
		is_in_chasing_range = true

func _on_chasing_area_exited(body: Node) -> void:
	if body == player:
		is_in_chasing_range = false

func _on_attacking_area_entered(body: Node) -> void:
	if body.name == "player":
		is_in_attacking_range = true

func _on_attacking_area_exited(body: Node) -> void:
	if body == player:
		is_in_attacking_range = false
		attacking_on_cooldown = false
		attacking_timer.stop()

func _on_attacking_timer_timeout() -> void:
	attacking_on_cooldown = false

func receive_damage(damage: Damage) -> void:
	health -= damage.amount
	
	var hit_direction = (global_position - damage.from_position).normalized()
	velocity = hit_direction * 200
	
	if health <= 0:
		state_machine.transition("died")
		sprite.play("died")
		
		if not sprite.animation_finished.is_connected(_on_died_animation_finished):
			sprite.animation_finished.connect(_on_died_animation_finished)
			
		return
	
	state_machine.transition("damaged")
	sprite.play("damaged")
	
	if not sprite.animation_finished.is_connected(_on_damaged_animation_finished):
		sprite.animation_finished.connect(_on_damaged_animation_finished)

func _on_damaged_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_damaged_animation_finished):
		sprite.animation_finished.disconnect(_on_damaged_animation_finished)
		
	state_machine.transition("idle")

func _on_died_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_died_animation_finished):
		sprite.animation_finished.disconnect(_on_died_animation_finished)
	
	NodeUtils.disable_all_children(self)
	respawn_timer.start()
	
	if collectable_drop:
		collectable_drop.drop_collectable(global_position)

func _on_respawn_timer_timeout():
	respawn()

# Virtual method to allow override
func has_collectable() -> bool:
	return collectable_drop != null

# Virtual method to allow override
func has_direction() -> bool:
	return collectable_drop != null
