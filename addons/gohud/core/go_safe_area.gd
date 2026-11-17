## Safe-area helper adapted from gohud v1.3.0.
## Source: thruthesky/gohud@5d48e694d572625dcd3a7d22bd2a2357c6b78c32 (MIT).
class_name GoSafeArea
extends RefCounted


static func usable_rect(window: Window) -> Rect2:
	if window == null:
		return Rect2()
	var area := window.get_visible_rect()
	var platform := OS.get_name()
	if platform != "Android" and platform != "iOS":
		return area
	var safe_px := Rect2(DisplayServer.get_display_safe_area())
	return clip_to_safe(area, safe_px, window.get_final_transform())


static func clip_to_safe(area: Rect2, safe_px: Rect2, to_screen: Transform2D) -> Rect2:
	if safe_px.size.x <= 0.0 or safe_px.size.y <= 0.0:
		return area
	if is_zero_approx(to_screen.determinant()):
		return area
	var result := area.intersection(to_screen.affine_inverse() * safe_px)
	return result if result.size.x > 1.0 and result.size.y > 1.0 else area
