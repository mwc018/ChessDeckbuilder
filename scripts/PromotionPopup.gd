extends Control

# Emitted once the player clicks one of the four options, with the promoted
# piece's symbol (e.g. "♕"). The caller (Board) is responsible for freeing
# this popup afterward.
signal piece_chosen(symbol: String)

# A pawn may promote to any of these — queen, rook, bishop, knight — never a
# king and never staying a pawn.
const WHITE_OPTIONS: Array[String] = ["♕", "♖", "♗", "♘"]
const BLACK_OPTIONS: Array[String] = ["♛", "♜", "♝", "♞"]

const OPTION_SIZE: float = 88.0
const OPTION_GAP: float = 14.0
const PANEL_PADDING: float = 20.0

# Board sets this (and this node's size/position to match the board) before
# add_child, so it's already correct by the time _ready() builds the panel.
var is_white: bool = true

func _ready() -> void:
    var dim := ColorRect.new()
    dim.name = "Dim"
    dim.color = Color(0.0, 0.0, 0.0, 0.55)
    dim.size = size
    dim.position = Vector2.ZERO
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)

    _build_panel()

func _build_panel() -> void:
    var options: Array[String] = WHITE_OPTIONS if is_white else BLACK_OPTIONS
    var panel_width: float = PANEL_PADDING * 2.0 + OPTION_SIZE * options.size() + OPTION_GAP * (options.size() - 1)
    var panel_height: float = PANEL_PADDING * 2.0 + OPTION_SIZE

    var panel := ColorRect.new()
    panel.name = "Panel"
    panel.color = Color(0.31, 0.22, 0.15, 1.0)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.size = Vector2(panel_width, panel_height)
    panel.position = Vector2((size.x - panel_width) * 0.5, (size.y - panel_height) * 0.5)
    add_child(panel)

    for i in range(options.size()):
        var option := _make_option(options[i])
        option.position = Vector2(PANEL_PADDING + i * (OPTION_SIZE + OPTION_GAP), PANEL_PADDING)
        option.size = Vector2(OPTION_SIZE, OPTION_SIZE)
        panel.add_child(option)

func _make_option(symbol: String) -> Control:
    var swatch := ColorRect.new()
    swatch.color = Color(0.84, 0.72, 0.58, 1.0)
    swatch.mouse_filter = Control.MOUSE_FILTER_STOP
    swatch.set_meta("base_color", swatch.color)

    var label := Label.new()
    label.text = symbol
    # Match Piece.gd's own coloring so the option glyphs look identical to
    # how the promoted piece will actually render on the board.
    label.modulate = Color(0.15, 0.12, 0.08, 1.0) if not is_white else Color(1.0, 1.0, 1.0, 1.0)
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 44)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    swatch.add_child(label)

    swatch.connect("mouse_entered", Callable(self, "_on_option_hovered").bind(swatch))
    swatch.connect("mouse_exited", Callable(self, "_on_option_unhovered").bind(swatch))
    swatch.connect("gui_input", Callable(self, "_on_option_input").bind(symbol))

    return swatch

func _on_option_hovered(swatch: ColorRect) -> void:
    swatch.color = Color(0.95, 0.85, 0.68, 1.0)

func _on_option_unhovered(swatch: ColorRect) -> void:
    swatch.color = swatch.get_meta("base_color", swatch.color)

func _on_option_input(event: InputEvent, symbol: String) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        piece_chosen.emit(symbol)
