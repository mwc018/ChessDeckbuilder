extends Control

const BODY_COLOR := Color(0.16, 0.28, 0.46, 1.0)
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const VALUE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CAPTION_COLOR := Color(0.75, 0.85, 1.0, 1.0)

@export var energy: int = 3:
    set(value):
        energy = value
        _refresh_if_ready()

@export var max_energy: int = 3:
    set(value):
        max_energy = value
        _refresh_if_ready()

@export var display_size: Vector2 = Vector2(90, 90):
    set(value):
        display_size = value
        custom_minimum_size = value
        size = value
        _refresh_if_ready()

func _ready() -> void:
    custom_minimum_size = display_size
    size = display_size
    refresh_display()

func _refresh_if_ready() -> void:
    if is_inside_tree():
        refresh_display()

func refresh_display() -> void:
    for child in get_children():
        child.free()

    var panel := Panel.new()
    panel.name = "Panel"
    panel.size = display_size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = BODY_COLOR
    style.set_corner_radius_all(16)
    style.border_color = BORDER_COLOR
    style.set_border_width_all(2)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    var value_label := Label.new()
    value_label.name = "ValueLabel"
    value_label.text = "%d/%d" % [energy, max_energy]
    value_label.position = Vector2(0, display_size.y * 0.5 - 24)
    value_label.size = Vector2(display_size.x, 34)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    value_label.add_theme_font_size_override("font_size", 24)
    value_label.add_theme_color_override("font_color", VALUE_COLOR)
    value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(value_label)

    var caption := Label.new()
    caption.name = "CaptionLabel"
    caption.text = "ENERGY"
    caption.position = Vector2(0, display_size.y * 0.5 + 8)
    caption.size = Vector2(display_size.x, 18)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 11)
    caption.add_theme_color_override("font_color", CAPTION_COLOR)
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(caption)
