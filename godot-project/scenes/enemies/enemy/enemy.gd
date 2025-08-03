extends CharacterBody2D
class_name Enemy
const NodeUtils = preload("res://scripts/utils/node_utils.gd")

@onready var state_machine: Node = $state_machine
@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var chasing_area: Area2D = $chasing_area
@onready var stop_chasing_area: Area2D = $stop_chasing_area
@onready var attacking_area: Area2D = $attacking_area
@onready var collectable_drop: Node = $collectable_drop

signal enemy_attacked(damage: Damage)

var initial_health: int
var health: int
var damage_amount: int
var has_direction := false
var movement_direction := Vector2.ZERO
var last_direction: String

var idle_move_speed: float = 10.0  # Slower than chase speed
var idle_target_position: Vector2 = Vector2.ZERO
var idle_wander_radius: float = 64.0  # Radius around spawn to wander
var idle_timer := Timer.new()

var is_in_chasing_range := false
var chasing_move_speed: float = 30.0

var is_in_attacking_range := false
var has_attacking_anim := false
var is_attacking_animation_playing := false
var has_applied_attack_damage := false
var attacking_timer := Timer.new()
var attacking_on_cooldown := false

var spawn_position := Vector2.ZERO
var respawn_timer := Timer.new()

var player: CharacterBody2D = null
var current_platforms := []

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	
	idle_timer.wait_time = 2.0  # Change direction every 2 seconds
	idle_timer.one_shot = false
	idle_timer.autostart = true
	add_child(idle_timer)
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	
	chasing_area.body_entered.connect(_on_chasing_area_entered)
	stop_chasing_area.body_exited.connect(_on_stop_chasing_area_exited)
	
	attacking_timer.wait_time = 0.1 
	attacking_timer.one_shot = true
	add_child(attacking_timer)
	attacking_area.body_entered.connect(_on_attacking_area_entered)
	attacking_area.body_exited.connect(_on_attacking_area_exited)
	attacking_timer.timeout.connect(_on_attacking_timer_timeout)
	sprite.frame_changed.connect(_on_attacking_frame_changed)
	
	respawn_timer.wait_time = 3.0
	respawn_timer.one_shot = true
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	
	# Set first wander point
	_on_idle_timer_timeout()
	play_anim("idle")

func _get_direction_from_vector(vec: Vector2) -> String:
	if abs(vec.x) > abs(vec.y):
		return "right" if vec.x > 0 else "left"
	else:
		return "front" if vec.y > 0 else "back"

func _make_damage() -> Damage:
	var damage = Damage.new()
	damage.from_position = global_position
	damage.amount = damage_amount
	return damage

func play_anim(base_name: String) -> void:
	if has_direction:
		sprite.play("%s_%s" % [base_name, last_direction])
	else:
		sprite.play(base_name)



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
			var direction = (idle_target_position - global_position)
			if direction.length() > 4.0:
				movement_direction = direction.normalized()
				velocity = movement_direction * idle_move_speed
			else:
				velocity = Vector2.ZERO
		"chasing":
			if player:
				movement_direction = (player.global_position - global_position).normalized()
				velocity = movement_direction * chasing_move_speed
			else:
				velocity = Vector2.ZERO
		"attacking":
			if player:
				velocity = Vector2.ZERO
					
				if not attacking_on_cooldown:
					attacking_on_cooldown = true

					if has_attacking_anim:
						is_attacking_animation_playing = true
						play_anim("attacking")
						if not sprite.animation_finished.is_connected(_on_attacking_animation_finished):
							sprite.animation_finished.connect(_on_attacking_animation_finished)
					else:
						# Instant attack and cooldown start for slimes
						emit_signal("enemy_attacked", _make_damage())
						attacking_timer.start()
				
	if has_direction and velocity.length_squared() > 0:
		last_direction = _get_direction_from_vector(movement_direction)
		
	if is_attacking_animation_playing:
		# Always apply gentle pushback to avoid sticking
		if player:
			var to_player = player.global_position - global_position
			var distance = to_player.length()
			if distance < 16:
				velocity = -to_player.normalized() * 40
			else:
				velocity = Vector2.ZERO
		
	move_and_slide()
	
	if not is_attacking_animation_playing:
		play_anim("idle")

func respawn() -> void:
	global_position = spawn_position
	health = initial_health
	velocity = Vector2.ZERO
	NodeUtils.enable_all_children(self)
	state_machine.transition("idle")
	play_anim("idle")

func _on_idle_timer_timeout() -> void:
	# Pick a new random target around spawn position
	var angle = randf() * TAU
	var distance = randf_range(16.0, idle_wander_radius)
	idle_target_position = spawn_position + Vector2.RIGHT.rotated(angle) * distance

func _on_chasing_area_entered(body: Node) -> void:
	if body.name == "player":
		player = body
		is_in_chasing_range = true

func _on_stop_chasing_area_exited(body: Node) -> void:
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

func _on_attacking_frame_changed():
	if not is_attacking_animation_playing:
		return
		
	if has_attacking_anim and str(sprite.animation).begins_with("attacking"):
		if sprite.frame == 3 and not has_applied_attack_damage:
			if is_in_attacking_range and player != null:
				emit_signal("enemy_attacked", _make_damage())
			has_applied_attack_damage = true

func _on_attacking_animation_finished():
	if sprite.animation_finished.is_connected(_on_attacking_animation_finished):
		sprite.animation_finished.disconnect(_on_attacking_animation_finished)
	
	is_attacking_animation_playing = false
	has_applied_attack_damage = false  # Reset here
	attacking_timer.start()

func receive_damage(damage: Damage) -> void:
	health -= damage.amount
	
	var hit_direction = (global_position - damage.from_position).normalized()
	velocity = hit_direction * 200
	
	if health <= 0:
		state_machine.transition("died")
		play_anim("died")
		
		if not sprite.animation_finished.is_connected(_on_died_animation_finished):
			sprite.animation_finished.connect(_on_died_animation_finished)
			
		return
	
	state_machine.transition("damaged")
	play_anim("damaged")
	
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
