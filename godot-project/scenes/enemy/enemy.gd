extends CharacterBody2D

@onready var state_machine: Node = $state_machine
@onready var sprite: AnimatedSprite2D = $sprite_anchor/sprite
@onready var chasing_area: Area2D = $chasing_area
@onready var attacking_area: Area2D = $attacking_area
@onready var attacking_cooldown: Timer = $attacking_cooldown

var player: CharacterBody2D = null

var health = 60
var move_speed: int = 20

var is_in_chasing_range = false
var is_in_attacking_range = false
var attacking_on_cooldown = false

signal enemy_attacked(global_position: Vector2, amount: int)

func _ready() -> void:
	sprite.play("idle")
	chasing_area.body_entered.connect(_on_chasing_area_entered)
	chasing_area.body_exited.connect(_on_chasing_area_exited)
	attacking_area.body_entered.connect(_on_attacking_area_entered)
	attacking_area.body_exited.connect(_on_attacking_area_exited)
	attacking_cooldown.timeout.connect(_on_attacking_cooldown_timeout)

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
			velocity = Vector2.ZERO
		"chasing":
			if player:
				var direction = (player.global_position - global_position).normalized()
				velocity = direction * move_speed
			else:
				velocity = Vector2.ZERO
		"attacking":
			velocity = Vector2.ZERO
			if player and !attacking_on_cooldown:
				attacking_on_cooldown = true
				emit_signal("enemy_attacked", global_position, 20)
				attacking_cooldown.start()

	move_and_slide()

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
		attacking_cooldown.stop()

func _on_attacking_cooldown_timeout() -> void:
	attacking_on_cooldown = false

func take_damage(from_position, amount) -> void:
	health -= amount
	
	var hit_direction = (global_position - from_position).normalized()
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
		
	queue_free()
