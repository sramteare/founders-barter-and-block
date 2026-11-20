class_name MiniHandStack
extends HBoxContainer

var res_fan: MiniHandFan = null
var act_fan: MiniHandFan = null
var res_count := 0:
	set(v):
		res_count = v
		if res_fan != null:
			res_fan.count = v
var act_count := 0:
	set(v):
		act_count = v
		if act_fan != null:
			act_fan.count = v

func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96, 26)
	res_fan = MiniHandFan.new()
	res_fan.variant = 0
	res_fan.tooltip_text = "Resource cards"
	add_child(res_fan)
	act_fan = MiniHandFan.new()
	act_fan.variant = 1
	act_fan.tooltip_text = "Action Cards"
	add_child(act_fan)
