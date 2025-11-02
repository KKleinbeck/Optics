class_name Beam extends Node2D


var offset: Vector2 = Vector2.ZERO
var intensity: float = 1.
var isReady: bool = false


@export var orientation: float = 0.:
	set(value):
		orientation = value
		redraw()
@export var spread: Vector2 = Vector2(-0.1, 0.1)
@export var beamRadius: float = 14.
# TODO: spread and beamWidth should, on the fly, correct the rays

var rays: Array[Ray] = []

var shape: PackedVector2Array

var selected: bool = false:
	set(value):
		selected = value
		beamColor = Color(Color.LIME_GREEN if selected else Color.DARK_GREEN, intensity)
		for child in get_children():
			child.selected = selected
		redraw()
var dragged: bool = false
var clickPosition: Vector2
var clickResetTime: int = 0
var beamColor: Color = Color.SEA_GREEN
var maxBeamLength: float = 2000.
var _rayDump = []


func _ready() -> void:
	var screensize = get_viewport().size
	for n in [0, 1]:
		var ray = Ray.new(
			orientation + spread[n],
			beamRadius * (Vector2.LEFT if n == 0 else Vector2.RIGHT), #.rotated(orientation),
			screensize.length()
		)
		rays.append(ray)
	maxBeamLength = screensize.length()
	_raycast()
	isReady = true


func _draw() -> void:
	for n in [0, 1]:
		draw_colored_polygon(shape, beamColor)
		for rd in _rayDump:
			draw_line(rd.startAtBeam.rotated(orientation), rd.intersectionAtBeam, Color.WHITE, 3, true)
		draw_circle(offset, 3., Color.RED)


func _process(_delta: float) -> void:
	pass


func _solveScattering():
	var newBeamStarts = _raycast()
	print(shape)
	#for bs in newBeamStarts:
		#print(bs)
	
	
	
	# use global coordinates, not local to node
	var rayDir = Vector2.UP.rotated(orientation)
	var viewport_position = global_position + offset
	var query = PhysicsRayQueryParameters2D.create(
		viewport_position, viewport_position + maxBeamLength * rayDir
	)
	query.collide_with_areas = true
	query.collision_mask &= ~GlobalDefinitions.clickableMask
	#var result = space_state.intersect_ray(query)
	#if result:
		#beamLength = (result.position - viewport_position).length()
		#print(result.position - result.collider.position)
		#print(result.collider.shape)
		#_onOpticalCollision(
			#result.collider, result.position, result.normal
		#)
	#else:
		#beamLength = maxBeamLength


func _raycast() -> Array:
	"""
	Performs a scan along the ray dimensions to try to find every collision
	partner along the beams path.
	
	Side effects: Sets `shape`.
	"""
	var space_state = get_world_2d().direct_space_state
	var innerRays = []
	var shapes = [
		[{"p": beamRadius * Vector2.LEFT.rotated(orientation)}],
		[{"p": beamRadius * Vector2.RIGHT.rotated(orientation)}]
	]
	_rayDump = []
	
	for n in [0, 1]: # Forward pass, backwards pass
		var s = 1 if n == 0 else -1
		var thresholdAngle = -spread[0] if n == 0 else innerRays[-1].angleAtBeam
		innerRays = [rays[n]]
		
		for m in range(GlobalDefinitions.MAX_SUB_RAYS):
			if m == innerRays.size(): break
			
			var result = innerRays[-1].raycast(space_state, global_position + offset, orientation, bool(n))
			_rayDump.append(result)
			if "corner" in result and result.corner != Vector2.INF:
				if m == 0:
					shapes[n].append({"p": result.intersectionAtBeam, "raycastResult": result})
				var pullback = _solveRayPullback(result, bool(n))
				if not pullback: break
				
				shapes[n].append({"p": pullback[2], "raycastResult": result})
				innerRays.append(
					Ray.new(pullback[0] + s * 5e-3, pullback[1] * Vector2.RIGHT, rays[0].maxBeamLength)
				)
				#var targetVector = result.collider.position + result.corner - global_position - offset
				#var targetAngle = Vector2.UP.angle_to(targetVector) + s * 1e-5 - orientation
				##print(s * targetAngle, "  ", s * innerRays[-1].angle, "  ", s * thresholdAngle, "  ", s * targetAngle < s * innerRays[-1].angle + 1e-4)
				#if s * targetAngle < s * innerRays[-1].angleAtRay + 5e-3:
					#targetAngle = innerRays[-1].angleAtRay + s * 5e-3
					#innerRays.append(Ray.new(targetAngle, Vector2.ZERO, rays[0].maxBeamLength))
				#elif s * targetAngle < s * thresholdAngle:
					#shapes[n].append({"p": targetVector, "raycastResult": result})
					#innerRays.append(Ray.new(targetAngle, Vector2.ZERO, rays[0].maxBeamLength))
			else:
				shapes[n].append({"p": result.intersectionAtBeam})
	
	shapes[1].reverse()
	var preShape = shapes[0] + shapes[1]
	shape = PackedVector2Array([preShape[0].p])
	var newBeamStarts = []
	for n in preShape.size() - 1:
		if (preShape[n+1].p - preShape[n].p).length() / (preShape[n+1].p + preShape[n].p).length() > 0.01:
			shape.append(preShape[n+1].p)
			if "raycastResult" in preShape[n] and "raycastResult" in preShape[n+1] and \
				preShape[n+1].raycastResult.collider == preShape[n].raycastResult.collider:
				newBeamStarts.append([preShape[n], preShape[n+1]])
	return newBeamStarts


func _solveRayPullback(raycastResult: Dictionary, backwardsPass: bool) -> Array:
	"""
	On a collision with an object, figure out, whether we can reach the next
	corner within that object or we reach the beam end.
	"""
	var vectorToCorner = raycastResult.collider.position + raycastResult.corner - \
		(global_position + offset)
	var vectorToCornerAtBeam = vectorToCorner.rotated(-orientation)
	
	var target = func (t: float) -> float:
		var alpha = (1. - t) * spread[0] + t * spread[1]
		var x = 2. * t * beamRadius - beamRadius
		
		var vectorToCornerAtRay = vectorToCornerAtBeam
		vectorToCornerAtRay.x -= x
		
		return sin(alpha) * vectorToCornerAtRay.length() - vectorToCornerAtRay.x
	
	var t0 = 0.
	var t1 = 1.
	
	var f0 = target.call(t0)
	var f1 = target.call(t1)
	if f0 > 0 or f1 < 0:
		return []
	
	var fmid = target.call(0.5 * (t0 + t1))
	for m in range(10):
		if fmid > 0:
			t1 = 0.5 * (t0 + t1)
			f1 = fmid
			fmid = target.call(0.5 * (t0 + t1))
		else:
			t0 = 0.5 * (t0 + t1)
			f0 = fmid
			fmid = target.call(0.5 * (t0 + t1))
		
	var tres = t0 if backwardsPass else t1
	return [
		(1. - tres) * spread[0] + tres * spread[1],
		2. * tres * beamRadius - beamRadius,
		vectorToCorner
	]


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
		instance.orientation = Vector2.UP.angle_to(normal) + angle
		instance.intensity = 0.85 * intensity
		instance.selected = selected
		add_child(instance)


func redraw() -> void:
	for child in get_children():
		child.queue_free()
	if isReady:
		_solveScattering()
	queue_redraw()
