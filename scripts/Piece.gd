extends Control

@export var symbol: String = "♙"
@export var dark: bool = false
var board: Node = null
var square_coord: String = ""
var selected: bool = false
var hover_pulse: Tween = null

@onready var label: Label = $Label

func _ready() -> void:
	label.text = symbol
	label.modulate = Color(0.15, 0.12, 0.08, 1) if dark else Color(1.0, 1.0, 1.0, 1)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.set_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	# PASS, not STOP: piece clicks are still handled below, but a card
	# dropped on an occupied square needs to bubble up to Board's own
	# _can_drop_data/_drop_data to register as "played on the board".
	mouse_filter = Control.MOUSE_FILTER_PASS
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	connect("gui_input", Callable(self, "_on_piece_input"))

func _on_mouse_entered() -> void:
	if board != null and square_coord != "":
		board._on_piece_hovered(square_coord)

func _on_mouse_exited() -> void:
	if board != null:
		board._on_piece_unhovered()

func _on_piece_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if board != null and square_coord != "":
			board._on_piece_clicked(square_coord)

func set_symbol(new_symbol: String, new_dark: bool) -> void:
	symbol = new_symbol
	dark = new_dark
	label.text = symbol
	label.modulate = Color(0.15, 0.12, 0.08, 1) if dark else Color(1.0, 1.0, 1.0, 1)

func set_selected(value: bool) -> void:
	selected = value
	if selected:
		_start_hover_pulse()
	else:
		_stop_hover_pulse()

func _start_hover_pulse() -> void:
	if hover_pulse != null and hover_pulse.is_running():
		return
	var base_scale: Vector2 = Vector2.ONE
	var hover_scale: Vector2 = Vector2(1.06, 1.06)
	hover_pulse = create_tween()
	hover_pulse.set_loops()
	hover_pulse.set_trans(Tween.TRANS_SINE)
	hover_pulse.set_ease(Tween.EASE_IN_OUT)
	hover_pulse.tween_property(self, "scale", hover_scale, 0.45)
	hover_pulse.tween_property(self, "scale", base_scale, 0.45)

func _stop_hover_pulse() -> void:
	if hover_pulse != null:
		hover_pulse.kill()
		hover_pulse = null
	scale = Vector2.ONE
