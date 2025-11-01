class_name Ray extends Resource

var angle: float = 0.
var maxBeamLength: float = 2000.


func _init(_angle: float, _maxBeamLength: float) -> void:
	angle = _angle
	maxBeamLength = _maxBeamLength


func raycast(
		space_state: PhysicsDirectSpaceState2D, viewport_position: Vector2,
		orientation: float, backwardsPass: bool = false) -> Dictionary:
	var rayDir = Vector2.UP.rotated(orientation + angle)
	var query = PhysicsRayQueryParameters2D.create(
		viewport_position, viewport_position + maxBeamLength * rayDir
	)
	query.collide_with_areas = true
	query.collision_mask &= ~GlobalDefinitions.clickableMask
	var result = space_state.intersect_ray(query)
	if result:
		result["corner"] = _determineRelevantCorner(
			result.collider, result.position - result.collider.position, backwardsPass
		)
		result.localPosition = result.position - viewport_position
	else:
		result.localPosition = maxBeamLength * rayDir
	return result


func _determineRelevantCorner(
		collider: AbstractOptics, intersectionPoint: Vector2, backwardsPass: bool
		) -> Vector2:
	var shape = []
	for s in collider.shape:
		shape.append(s.rotated(collider.rotation))
	
	var candidate = Vector2.INF
	for n in shape.size():
		var next = shape[n+1 if n+1 < shape.size() else 0]
		var shapeDir = (next - shape[n]).normalized()
		var intersectionDir = (intersectionPoint - shape[n]).normalized()
		
		if (next - intersectionPoint).length() < 1.:
			# Handle intersections close to corners conservative
			if backwardsPass:
				return shape[n+2 if n+2 < shape.size() else n + 1 - shape.size()]
			return shape[n]
		
		if shapeDir.dot(intersectionDir) > 1. - 1e-4:
			# We assume clockwise orientation!
			if backwardsPass: return shape[n+1 if n+1 < shape.size() else 0]
			return shape[n] 
	return candidate
