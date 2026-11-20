class_name MiniHandFan
extends Control

var count := 0
var variant := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size = Vector2(44, 26)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var cw := 11.0
	var chh := 15.0
	var base := Vector2(4, size.y * 0.5 - chh * 0.5)
	var layers := mini(3, maxi(1, mini(count, 3)))
	var dim := count <= 0
	var alpha := 0.35 if dim else 1.0
	for i in range(layers):
		var r := Rect2(base + Vector2(-float(i) * 2.0, -float(i) * 1.2), Vector2(cw, chh))
		var bg := Color(0.36, 0.47, 0.55, alpha) if variant == 0 else Color(0.55, 0.44, 0.30, alpha)
		draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0.1, 0.08, 0.05, 0.20 * alpha))
		draw_rect(r, bg)
		draw_rect(r, Color(0.25, 0.19, 0.14, 0.8 * alpha), false, 1.0)
		if variant == 0:
			draw_line(Vector2(r.position.x + 2, r.get_center().y), Vector2(r.end.x - 2, r.get_center().y), Color(0.93, 0.90, 0.8, 0.5 * alpha), 1.0, true)
		else:
			draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), Color(0.93, 0.90, 0.8, 0.5 * alpha), 1.0, true)
	var txt := str(count)
	var fs := 11
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var col := Palette.TEXT_MUTED if dim else Palette.TEXT
	draw_string(font, Vector2(snappedf(base.x + cw + 3.0, 1.0), snappedf(base.y + chh * 0.5 + ts.y * 0.32, 1.0)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
