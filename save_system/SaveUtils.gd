# From CodingQuests Godot Save System v1.0.0.
# Upstream commit: 417e8baab42d44496208e40ee0bc1d9c78985419
class_name SaveUtils
extends RefCounted


static func vec2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


static func dict_to_vec2(d: Dictionary) -> Vector2:
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


static func vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func dict_to_vec3(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
