extends CharacterBody2D

@export var speed: float = 100.0

@onready var state_machine: Node = $state_machine
@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var animation_player: AnimationPlayer = $animation_player
@onready var attacking_area: Area2D = $attacking_area
@onready var position_area: Area2D = $position_area

signal player_attacked(body: Node, damage: Damage)
signal health_changed(new_health: int)

var spawn_position := Vector2.ZERO
var last_direction := "front"
var initial_health := 100
var health := initial_health : set = set_health
var damaged_timer := Timer.new()
var damaged_on_cooldown := false
var is_animation_locked := false
var current_platforms: Array = []
var is_on_falling_area := false
var falling_start_velocity := Vector2.ZERO
var falling_entry_timer := Timer.new()

func set_health(value: int) -> void:
	health = clamp(value, 0, initial_health)
	emit_signal("health_changed", health)

func _ready() -> void:
	spawn_position = global_position
	animation_player.animation_finished.connect(_on_attacking_animation_finished)
	position_area.body_entered.connect(_on_position_area_body_entered)
	position_area.body_exited.connect(_on_position_area_body_exited)
	
	attacking_area.body_entered.connect(_on_attacking_area_entered)
	
	damaged_timer.wait_time = 0.5
	damaged_timer.one_shot = true
	add_child(damaged_timer)
	damaged_timer.timeout.connect(_on_damaged_timer_timeout)

	falling_entry_timer.wait_time = 0.05
	falling_entry_timer.one_shot = true
	add_child(falling_entry_timer)
	falling_entry_timer.timeout.connect(_on_falling_entry_timer_timeout)
	
	sprite.play("idle_front")

func _physics_process(delta: float) -> void:
	if state_machine.current_state.name in ["damaged", "died"]:
		# Apply knockback and dampen over time
		velocity = velocity.move_toward(Vector2.ZERO, 1200 * delta)  # smooth deceleration
		move_and_slide()
		return
		
	if state_machine.current_state.name == "falling":
		set_falling_velocity(delta)
		move_and_slide()
		return
		
	if state_machine.current_state.name == "attacking":
		return
	
	var input_vector = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()
	
	# Move character
	velocity = input_vector * speed
	move_and_slide()
	
	if !is_animation_locked:
		# Handle state transitions
		if input_vector.length() > 0:
			if state_machine.current_state.name != "running":
				state_machine.transition("running")
		else:
			if state_machine.current_state.name != "idle":
				state_machine.transition("idle")
			
		# Determine direction and play correct animation
		var player_state = state_machine.current_state.name  # "running" or "idle"
		var player_direction = get_facing_direction(input_vector)
		
		sprite.play("%s_%s" % [player_state, player_direction])

func _input(event):
	if is_animation_locked or state_machine.current_state.name == "died":
		return
		
	if event.is_action_pressed("attack"):
		state_machine.transition("attacking")
		if !animation_player.is_playing():
			var anim_name = "attacking_%s" % last_direction
			animation_player.play(anim_name)

func respawn() -> void:
	global_position = spawn_position
	set_health(initial_health)
	velocity = Vector2.ZERO
	state_machine.transition("idle")
	# enable player collision
	collision_mask  |= 1
	collision_mask  |= 3
	# order player over platforms
	z_index = 2
	is_animation_locked = false
	sprite.play("idle_front")

func get_facing_direction(input_vector: Vector2) -> String:
	if input_vector == Vector2.ZERO:
		return last_direction  # retain previous facing direction
		
	if abs(input_vector.x) > abs(input_vector.y):
		last_direction = "right" if input_vector.x > 0 else "left"
	else:
		last_direction = "front" if input_vector.y > 0 else "back"
		
	return last_direction

func receive_damage(damage: Damage) -> void:
	if damaged_on_cooldown || state_machine.current_state.name == "died":
		return
		
	set_health(health - damage.amount)
	
	var hit_direction = (global_position - damage.from_position).normalized()
	velocity = hit_direction * 200
	
	if health <= 0:
		sprite.play("died")
		
		if not sprite.animation_finished.is_connected(_on_died_animation_finished):
			sprite.animation_finished.connect(_on_died_animation_finished)
		
		state_machine.transition("died")
		return
	
	damaged_on_cooldown = true
	var anim_direction: String
	if abs(hit_direction.x) > abs(hit_direction.y):
		anim_direction = "left" if hit_direction.x > 0 else "right"
	else:
		anim_direction = "back" if hit_direction.y > 0 else "front"
		
	var anim_name = "damaged_%s" % anim_direction
	is_animation_locked = true  # Lock until animation is done
	sprite.play(anim_name)
	
	if not sprite.animation_finished.is_connected(_on_damaged_animation_finished):
		sprite.animation_finished.connect(_on_damaged_animation_finished)
		
	last_direction = anim_direction
	state_machine.transition("damaged")

func _on_damaged_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_damaged_animation_finished):
		sprite.animation_finished.disconnect(_on_damaged_animation_finished)
	
	is_animation_locked = false
	damaged_timer.start()  # Start invulnerability buffer
	state_machine.transition("idle")

func _on_damaged_timer_timeout() -> void:
	damaged_on_cooldown = false

func receive_health(amount) -> void:
	set_health(health + amount)

func _on_attacking_area_entered(body: Node) -> void:
	for group in ["enemies", "destructables"]:
		if body.is_in_group(group):
			var damage = Damage.new()
			damage.from_position = global_position
			damage.amount = 20
			emit_signal("player_attacked", body, damage)

func _on_attacking_animation_finished(anim_name: String) -> void:
	if anim_name == "attacking_%s" % last_direction:
		state_machine.transition("idle")

func _on_died_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_died_animation_finished):
		sprite.animation_finished.disconnect(_on_died_animation_finished)
		
	respawn()

func set_falling_velocity(delta: float) -> void:
	var direction_multiplier = 1.0

	match last_direction:
		"front":
			direction_multiplier = 1.0
		"left", "right":
			direction_multiplier = 0.3
		"back":
			direction_multiplier = 0.5
			
	# Use stored velocity captured when falling started
	velocity = falling_start_velocity / 10
	
	# Add vertical downward acceleration (gravity-like effect)
	velocity.y += 1200 * direction_multiplier * delta

func start_falling() -> void:
	if state_machine.current_state.name in ["died", "falling"]:
		return
	
	set_health(0)
	falling_start_velocity = velocity
	state_machine.transition("falling")
	# disable player collision
	collision_mask  &= ~1
	collision_mask  &= ~3
	# order player under platforms
	z_index = 0
	is_animation_locked = true
	sprite.play("falling")
	
	if not sprite.animation_finished.is_connected(_on_falling_animation_finished):
		sprite.animation_finished.connect(_on_falling_animation_finished)

func _on_position_area_body_entered(body: Node) -> void:
	if body.name == "water_tile_map":
		is_on_falling_area = true
		
		# Instead of checking immediately, wait 0.1s to ensure platform areas are registered
		if not falling_entry_timer.is_stopped():
			falling_entry_timer.stop()
			
		falling_entry_timer.start()

func _on_position_area_body_exited(body: Node) -> void:
	if body.name == "water_tile_map":
		is_on_falling_area = false

func _on_falling_entry_timer_timeout():
	if is_on_falling_area and current_platforms.is_empty():
		start_falling()

func _on_falling_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_falling_animation_finished):
		sprite.animation_finished.disconnect(_on_falling_animation_finished)
		
	respawn()
