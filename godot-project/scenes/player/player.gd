extends CharacterBody2D

@export var speed: float = 150.0

@onready var state_machine: Node = $state_machine
@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var damaged_cooldown: Timer = $damaged_cooldown
@onready var animation_player: AnimationPlayer = $animation_player
@onready var attacking_area: Area2D = $attacking_area

var last_direction := "front"
var last_hit_direction := "front"
var health = 100

var damaged_on_cooldown = false

signal player_attacked(body: Node, global_position: Vector2, amount: int)

func _ready() -> void:
	sprite.play("idle_front")
	animation_player.animation_finished.connect(_on_attacking_animation_finished)
	attacking_area.body_entered.connect(_on_attacking_area_entered)
	damaged_cooldown.timeout.connect(_on_damaged_cooldown_timeout)

func _physics_process(delta: float) -> void:
	if state_machine.current_state.name in ["damaged", "died"]:
		# Apply knockback and dampen over time
		velocity = velocity.move_toward(Vector2.ZERO, 1200 * delta)  # smooth deceleration
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
	if event.is_action_pressed("attack"):
		state_machine.transition("attacking")
		if !animation_player.is_playing():
			var anim_name = "attacking_%s" % last_direction
			animation_player.play(anim_name)

func get_facing_direction(input_vector: Vector2) -> String:
	if input_vector == Vector2.ZERO:
		return last_direction  # retain previous facing direction
		
	if abs(input_vector.x) > abs(input_vector.y):
		last_direction = "right" if input_vector.x > 0 else "left"
	else:
		last_direction = "front" if input_vector.y > 0 else "back"
		
	return last_direction

func take_damage(from_position: Vector2, amount: int) -> void:
	print("damaged_on_cooldown: ", damaged_on_cooldown)
	print("state_machine.current_state.name: ", state_machine.current_state.name)
	if damaged_on_cooldown || state_machine.current_state.name == "died":
		print("hit skip")
		return
		
	print("hit here")
	health -= amount
	
	var hit_direction = (global_position - from_position).normalized()
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
	sprite.play(anim_name)
	
	if not sprite.animation_finished.is_connected(_on_damaged_animation_finished):
		sprite.animation_finished.connect(_on_damaged_animation_finished)
		
	last_direction = anim_direction
	state_machine.transition("damaged")

func _on_damaged_animation_finished() -> void:
	print("hit")
	if sprite.animation_finished.is_connected(_on_damaged_animation_finished):
		sprite.animation_finished.disconnect(_on_damaged_animation_finished)
		
	damaged_cooldown.start()  # Start invulnerability buffer
	state_machine.transition("idle")

func _on_damaged_cooldown_timeout() -> void:
	damaged_on_cooldown = false

func _on_attacking_animation_finished(anim_name: String) -> void:
	if anim_name == "attacking_%s" % last_direction:
		state_machine.transition("idle")

func _on_attacking_area_entered(body: Node) -> void:
	if body.get_parent().name == "enemies":
		emit_signal("player_attacked", body, global_position, 20)

func _on_died_animation_finished() -> void:
	if sprite.animation_finished.is_connected(_on_died_animation_finished):
		sprite.animation_finished.disconnect(_on_died_animation_finished)
		
	queue_free()
