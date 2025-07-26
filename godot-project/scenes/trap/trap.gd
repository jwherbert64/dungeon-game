extends Node2D

@onready var animation_player: AnimationPlayer = $animation_player
@onready var sprite: AnimatedSprite2D = $sprite
@onready var area: Area2D = $area

signal trap_attacked(body: Node, global_position: Vector2, amount: int)

func _ready() -> void:
	animation_player.play("default")
	area.body_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	pass

func _on_area_entered(body: Node) -> void:
	if body.name == "player":
		emit_signal("trap_attacked", body, global_position, 20)
		print("hit player")
	
	if body.get_parent().name == "enemies":
		pass
