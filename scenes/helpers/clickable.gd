class_name Clickable extends Area2D


signal selectionChanged(selected: bool)
signal scroll(scrollDirection: int)
signal drag(dragDistance: Vector2)


var clickable: bool = false

var selected: bool = false
var dragged: bool = false
var clickPosition: Vector2
var clickResetTime: int = 0


func _ready() -> void:
	set_process(false)


func _input(event) -> void:
	if not clickable: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if !selected:
					toggleSelect()
				else:
					clickResetTime = Time.get_ticks_msec()
				dragged = true
				clickPosition = event.position
			elif !event.pressed and selected:
				dragged = false
				if Time.get_ticks_msec() - clickResetTime < 500:
					toggleSelect()
		elif (event.button_index == 4 or event.button_index == 5) and selected:
			scroll.emit(2 * (event.button_index - 4) - 1)
	elif event is InputEventMouseMotion and event.button_mask == 1 and dragged:
		drag.emit(event.position - clickPosition)
		clickPosition = event.position


func toggleSelect():
	selected = !selected
	selectionChanged.emit(selected)


func _on_mouse_entered() -> void:
	clickable = true


func _on_mouse_exited() -> void:
	clickable = false
