extends Node2D

@onready var animation_player: AnimationPlayer = $animation_player
@onready var sprite: AnimatedSprite2D = $sprite
@onready var area: Area2D = $area

signal trap_attacked(body: Node, damage: Damage)

var trap_entry_timer := Timer.new()
var entering_body: Node = null

func _ready() -> void:
	area.area_entered.connect(_on_area_area_entered)
	
	add_child(trap_entry_timer)
	trap_entry_timer.wait_time = 0.05
	trap_entry_timer.one_shot = true
	trap_entry_timer.timeout.connect(_on_trap_entry_timer_timeout)
	
	animation_player.play("default")

func _on_area_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent.name == "player" || parent.get_parent().name == "enemies":
		entering_body = parent
		trap_entry_timer.start()

func _on_trap_entry_timer_timeout() -> void:
	if entering_body.current_platforms.is_empty():
		var damage = Damage.new()
		damage.from_position = global_position
		damage.amount = 20
		emit_signal("trap_attacked", entering_body, damage)
		
	entering_body = null
