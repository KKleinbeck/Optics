class_name Beam extends Node2D


var offset: Vector2 = Vector2.ZERO
var intensity: float = 1.
var isReady: bool = false


@export var orientation: float = 0.:
	set(value):
		orientation = value
		redraw()
@export var spread: float = 0.1
#@export var rayOffsets: Array[float] = [0.]
@export var beamWidth: float = 7.

var rays: Array[Ray] = []

var shape: PackedVector2Array

var selected: bool = false:
	set(value):
		selected = value
		beamColor = Color(0.3, 0.3, 0.9, intensity) if selected else Color(Color.WHITE, intensity)
		for child in get_children():
			child.selected = selected
		redraw()
var dragged: bool = false
var clickPosition: Vector2
var clickResetTime: int = 0
var beamColor: Color = Color.WHITE
var maxBeamLength: float = 2000.
var beamLength: float = 0.:
	set(value):
		if beamLength != value:
			beamLength = value
			redraw()


func _ready() -> void:
	var screensize = get_viewport().size
	for s in [-1, 1]:
		var ray = Ray.new(orientation + s * spread, screensize.length())
		rays.append(ray)
	maxBeamLength = screensize.length()
	_raycast()
	isReady = true


func _draw() -> void:
	for s in [-1, 1]:
		var rayDir = Vector2.UP.rotated(orientation + s * spread);
		draw_line(offset, offset + beamLength * rayDir, beamColor, beamWidth, true);
		draw_colored_polygon(shape, Color.SEA_GREEN)
		draw_circle(offset, 5., Color.RED)


func _process(_delta: float) -> void:
	pass


func _raycast():
	var space_state = get_world_2d().direct_space_state
	var innerRays = []
	var shapes = [PackedVector2Array([Vector2.ZERO]), PackedVector2Array()]
	
	print("  ")
	for n in [0, 1]: # Forward pass, backwards pass
		var s = 1 if n == 0 else -1
		var thresholdAngle = innerRays[-1].angle if innerRays else s * spread
		innerRays = [rays[n]]
		
		for m in range(GlobalDefinitions.MAX_SUB_RAYS):
			if m == innerRays.size(): break
			
			var result = innerRays[m].raycast(space_state, global_position + offset, orientation, bool(n))
			shapes[n].append(result.localPosition)
			if "corner" in result and result.corner != Vector2.INF:
				var targetVector = result.collider.position + result.corner - global_position - offset
				var targetAngle = Vector2.UP.angle_to(targetVector) + s * 1e-5
				#print(s * targetAngle, "  ", s * innerRays[-1].angle, "  ", s * thresholdAngle, "  ", s * targetAngle < s * innerRays[-1].angle + 1e-4)
				if s * targetAngle < s * innerRays[-1].angle + 5e-3:
					targetAngle = innerRays[-1].angle + s * 5e-3
					innerRays.append(Ray.new(targetAngle, rays[0].maxBeamLength))
				elif s * targetAngle < s * thresholdAngle:
					shapes[n].append(targetVector)
					innerRays.append(Ray.new(targetAngle, rays[0].maxBeamLength))
		print(shapes[n])
	
	shapes[1].reverse()
	var preShape = shapes[0] + shapes[1]
	shape = PackedVector2Array([Vector2.ZERO])
	for n in preShape.size() - 1:
		if (preShape[n+1] - preShape[n]).length() / (preShape[n+1] + preShape[n]).length() > 0.01:
			shape.append(preShape[n+1])
		else:
			print("Filtered")
	print(shape)
	
	
	
	# use global coordinates, not local to node
	var rayDir = Vector2.UP.rotated(orientation)
	var viewport_position = global_position + offset
	var query = PhysicsRayQueryParameters2D.create(
		viewport_position, viewport_position + maxBeamLength * rayDir
	)
	query.collide_with_areas = true
	query.collision_mask &= ~GlobalDefinitions.clickableMask
	var result = space_state.intersect_ray(query)
	if result:
		beamLength = (result.position - viewport_position).length()
		#print(result.position - result.collider.position)
		#print(result.collider.shape)
		#_onOpticalCollision(
			#result.collider, result.position, result.normal
		#)
	else:
		beamLength = maxBeamLength


func _onOpticalCollision(
		optics: AbstractOptics, intersectionPoint: Vector2, normal: Vector2
	) -> void:
	if intensity < 0.1: return
	
	var viewport_position = global_position + offset
	if optics is Mirror:
		var instance = (load(scene_file_path) as PackedScene).instantiate()
		var sourceToIntersection = intersectionPoint - viewport_position
		var angle = sourceToIntersection.angle_to(-normal)
		
		instance.position = intersectionPoint
		instance.offset = offset - viewport_position
		instance.beamLength = 0.
		instance.orientation = Vector2.UP.angle_to(normal) + angle
		instance.intensity = 0.85 * intensity
		instance.selected = selected
		add_child(instance)


func redraw() -> void:
	for child in get_children():
		child.queue_free()
	if isReady:
		_raycast()
	queue_redraw()
