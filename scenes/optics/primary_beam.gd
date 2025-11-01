extends Node2D


func _ready() -> void:
	set_process(false)


func _on_clickable_drag(dragDistance: Vector2) -> void:
	position += dragDistance
	$Beam.redraw()


func _on_clickable_scroll(scrollDirection: int) -> void:
	$Beam.orientation += 0.03 * scrollDirection


func _on_clickable_selection_changed(selected: Variant) -> void:
	$Beam.selected = selected
