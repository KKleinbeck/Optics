extends Node


const DEBUG: Dictionary = {
	"DrawRays": true
}

const MAX_SUB_RAYS = 5

const clickableMask = 0b10000000_00000000_00000000_00000000


func _ready() -> void:
	set_process(false)
