## Manages terrain generation and rendering using chunks.
extends Node3D

var Player: CharacterBody3D

## Initializes the terrain generation.
func _ready() -> void:
	Player = get_parent().find_child("Player")
	print(Player.name)
