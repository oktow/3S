class_name Crosshair
extends Control

enum Style { CROSS, DOT, CIRCLE, RING, CROSSHAIR }

var style := Style.CROSS:
	set(v):
		style = v
		queue_redraw()

var crosshair_color := Color.WHITE:
	set(v):
		crosshair_color = v
		queue_redraw()

var crosshair_size := 20.0:
	set(v):
		crosshair_size = v
		queue_redraw()

var thickness := 4.0:
	set(v):
		thickness = v
		queue_redraw()

var gap := 6.0:
	set(v):
		gap = v
		queue_redraw()

var crosshair_opacity := 0.8:
	set(v):
		crosshair_opacity = v
		queue_redraw()

var outline := false:
	set(v):
		outline = v
		queue_redraw()

var outline_color := Color.BLACK:
	set(v):
		outline_color = v
		queue_redraw()


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var c := crosshair_color
	c.a = crosshair_opacity

	match style:
		Style.CROSS:
			_draw_cross(c)
		Style.DOT:
			_draw_dot(c)
		Style.CIRCLE:
			_draw_circle_style(c)
		Style.RING:
			_draw_ring(c)
		Style.CROSSHAIR:
			_draw_crosshair_style(c)


func _draw_cross(color: Color) -> void:
	var half_t := thickness * 0.5
	var arm_len := crosshair_size * 0.5
	var o := 1.0

	var rects := [
		Rect2(-half_t, -gap - arm_len, thickness, arm_len),
		Rect2(-half_t, gap, thickness, arm_len),
		Rect2(-gap - arm_len, -half_t, arm_len, thickness),
		Rect2(gap, -half_t, arm_len, thickness),
	]

	if outline:
		for r in rects:
			draw_rect(Rect2(r.position - Vector2(o, o), r.size + Vector2(o * 2, o * 2)), outline_color)

	for r in rects:
		draw_rect(r, color)


func _draw_dot(color: Color) -> void:
	var r := crosshair_size * 0.5
	if outline:
		draw_circle(Vector2.ZERO, r + 1.0, outline_color)
	draw_circle(Vector2.ZERO, r, color)


func _draw_circle_style(color: Color) -> void:
	var r := crosshair_size * 0.5
	var dot_r := thickness * 0.5
	var arc_w := 2.0
	if outline:
		draw_arc(Vector2.ZERO, r + 1.0, 0, TAU, 32, outline_color, arc_w + 2.0)
		draw_circle(Vector2.ZERO, dot_r + 1.0, outline_color)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, color, arc_w)
	draw_circle(Vector2.ZERO, dot_r, color)


func _draw_ring(color: Color) -> void:
	var r := crosshair_size * 0.5
	if outline:
		draw_arc(Vector2.ZERO, r + 1.0, 0, TAU, 32, outline_color, thickness + 2.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, color, thickness)


func _draw_crosshair_style(color: Color) -> void:
	var vsize := get_viewport_rect().size
	var half_w := vsize.x * 0.5
	var half_h := vsize.y * 0.5

	var lines := [
		[Vector2(-half_w, 0), Vector2(-gap, 0)],
		[Vector2(gap, 0), Vector2(half_w, 0)],
		[Vector2(0, -half_h), Vector2(0, -gap)],
		[Vector2(0, gap), Vector2(0, half_h)],
	]

	if outline:
		for l in lines:
			draw_line(l[0], l[1], outline_color, thickness + 2.0)

	for l in lines:
		draw_line(l[0], l[1], color, thickness)
