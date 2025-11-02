class_name Ray extends Resource

var angleAtBeam: float = 0.
var offsetAtBeam: Vector2 = Vector2.ZERO
var maxBeamLength: float = 2000.


func _init(_angleAtBeam: float, _offsetAtBeam: Vector2, _maxBeamLength: float) -> void:
	angleAtBeam = _angleAtBeam
	offsetAtBeam = _offsetAtBeam
	maxBeamLength = _maxBeamLength


func raycast(
		space_state: PhysicsDirectSpaceState2D, beamPositionAtVP: Vector2,
		beamOrientation: float, backwardsPass: bool = false) -> Array:
	var rayDirAtVP = Vector2.UP.rotated(beamOrientation + angleAtBeam)
	var rayPositionAtVP = beamPositionAtVP + offsetAtBeam.rotated(beamOrientation)
	var query = PhysicsRayQueryParameters2D.create(
		rayPositionAtVP, rayPositionAtVP + maxBeamLength * rayDirAtVP
	)
	query.collide_with_areas = true
	query.collision_mask &= ~GlobalDefinitions.clickableMask
	var result = space_state.intersect_ray(query)
	
	var beamData = {"startAtBeam" = offsetAtBeam}
	if result:
		result["corner"] = _determineRelevantCorner(
			result.collider, result.position - result.collider.position, backwardsPass
		)
		beamData.intersectionAtBeam = result.position - beamPositionAtVP
	else:
		beamData.intersectionAtBeam = maxBeamLength * rayDirAtVP + offsetAtBeam
	return [beamData, result]


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
