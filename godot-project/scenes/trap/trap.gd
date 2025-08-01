extends Node2D

@onready var animation_player: AnimationPlayer = $animation_player
@onready var sprite: AnimatedSprite2D = $sprite
@onready var area: Area2D = $area

signal trap_attacked(body: Node, damage: Damage)

func _ready() -> void:
	area.body_entered.connect(_on_area_entered)
	animation_player.play("default")

func _on_area_entered(body: Node) -> void:
	if body.name == "player" || body.get_parent().name == "enemies":
		if body.current_platforms.is_empty():
			var damage = Damage.new()
			damage.from_position = global_position
			damage.amount = 20
			emit_signal("trap_attacked", body, damage)
