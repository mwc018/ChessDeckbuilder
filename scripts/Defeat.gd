extends Control

# Shown when the player loses a match, which ends the run. Built in code,
# like Victory.gd. "New Run" wipes RunState back to a fresh run and returns
# to the map, which generates a new one.

const MAP_SCENE_PATH: String = "res://scenes/Map.tscn"

const TITLE_COLOR := Color(0.85, 0.25, 0.25, 1.0)
const SUBTITLE_COLOR := Color(0.9, 0.9, 0.9, 1.0)
const BUTTON_SIZE := Vector2(180, 52)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

    var column := VBoxContainer.new()
    column.set_anchors_preset(Control.PRESET_CENTER)
    column.grow_horizontal = Control.GROW_DIRECTION_BOTH
    column.grow_vertical = Control.GROW_DIRECTION_BOTH
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 16)
    add_child(column)

    var title := Label.new()
    title.text = "Defeat"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", TITLE_COLOR)
    column.add_child(title)

    # match_number is the match just lost, so every match before it was won.
    var wins: int = RunState.match_number - 1
    var subtitle := Label.new()
    subtitle.text = "Your run is over. You won %d %s." % [wins, "match" if wins == 1 else "matches"]
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 22)
    subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
    column.add_child(subtitle)

    var button := Button.new()
    button.text = "New Run"
    button.custom_minimum_size = BUTTON_SIZE
    button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(_on_new_run_pressed)
    column.add_child(button)

func _on_new_run_pressed() -> void:
    RunState.reset_run()
    get_tree().change_scene_to_file(MAP_SCENE_PATH)
