extends State
class_name PlayerIdle

@export var player : CharacterBody2D

func enter():
	#print("entered player idle")
	pass

func update(_delta):
	# Optional: decentralized transition from state itself
	# emit_signal("transitioned", self, "player_running")
	pass

func physics_update(_delta):
	pass
