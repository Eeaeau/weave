class_name Web3D
extends Node3D

@export var polygons: Array[WebPolygon3D] = []

func _ready() -> void:
	for polygon in polygons:
		polygon._ready()
