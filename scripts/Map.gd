extends Control

# The run map: a full-screen chessboard with the boss at its center and
# rings of nodes around it (layout and progress live in RunState — see the
# Map section there). Everything is drawn directly in _draw() and clicks
# are hit-tested against node positions, rather than building a Control per
# node, since the node positions depend on the window size anyway.

const MATCH_SCENE_PATH: String = "res://scenes/Match.tscn"

# Same colors as Board's squares, so the map reads as "the same board,
# zoomed out" — then dimmed with SHADE so the nodes on top stand out.
const LIGHT_SQUARE := Color(0.84, 0.72, 0.58, 1.0)
const DARK_SQUARE := Color(0.38, 0.26, 0.20, 1.0)
const SHADE := Color(0.0, 0.0, 0.0, 0.45)
const SQUARE_SIZE: float = 80.0

# Space kept clear between the outermost ring and the window edge, and
# above the map for the hint text.
const EDGE_MARGIN: float = 24.0
const TOP_RESERVED: float = 44.0

const NODE_RADIUS: float = 20.0
const BOSS_RADIUS: float = 32.0
const HOVER_SCALE: float = 1.2

const EDGE_COLOR := Color(0.95, 0.88, 0.72, 0.35)
const EDGE_REACHABLE_COLOR := Color(1.0, 0.85, 0.4, 0.95)
const EDGE_WIDTH: float = 2.0
const EDGE_REACHABLE_WIDTH: float = 4.0
const EDGE_SEGMENTS: int = 16

const NODE_FILL := Color(0.22, 0.17, 0.14, 1.0)
const NODE_CLEARED_FILL := Color(0.30, 0.30, 0.30, 1.0)
const NODE_CURRENT_FILL := Color(0.95, 0.88, 0.72, 1.0)
const BOSS_FILL := Color(0.55, 0.10, 0.10, 1.0)
const NODE_OUTLINE := Color(0.95, 0.88, 0.72, 0.8)
const NODE_REACHABLE_OUTLINE := Color(1.0, 0.85, 0.4, 1.0)

const GLYPH_COLOR := Color(0.95, 0.88, 0.72, 1.0)
const GLYPH_ON_CURRENT_COLOR := Color(0.15, 0.12, 0.08, 1.0)
const GLYPH_CLEARED_COLOR := Color(0.75, 0.75, 0.75, 1.0)
const ENEMY_GLYPH: String = "♟"
const BOSS_GLYPH: String = "♚"
const PLAYER_GLYPH: String = "♔"
const CLEARED_GLYPH: String = "✓"

const HINT_FONT_SIZE: int = 22

var _hovered_node: int = -1

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    if not RunState.has_map():
        RunState.generate_map()
    _build_debug_upgrade_button()

# Debug-only, like Match's "Win (Debug)": upgrades the first bishop in the
# army to an Archbishop, until shrines exist to do it for real.
func _build_debug_upgrade_button() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.62, 0.14, 0.14, 1)
    style.set_corner_radius_all(8)
    var button := Button.new()
    button.text = "Upgrade Bishop (Debug)"
    button.position = Vector2(16, 16)
    button.add_theme_font_size_override("font_size", 14)
    button.add_theme_stylebox_override("normal", style)
    add_child(button)
    var bishop_coord: Callable = func() -> String:
        for coord in RunState.army_layout.keys():
            if RunState.army_layout[coord] == "♗":
                return coord
        return ""
    button.disabled = bishop_coord.call() == ""
    button.pressed.connect(func() -> void:
        RunState.upgrade_piece(bishop_coord.call())
        button.disabled = bishop_coord.call() == ""
    )

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _map_center() -> Vector2:
    return Vector2(size.x * 0.5, TOP_RESERVED + (size.y - TOP_RESERVED) * 0.5)

func _ring_spacing() -> float:
    var usable_radius: float = min(size.x, size.y - TOP_RESERVED) * 0.5 - EDGE_MARGIN - NODE_RADIUS * HOVER_SCALE
    return usable_radius / RunState.MAP_RING_NODE_COUNTS.size()

func _node_position(id: int) -> Vector2:
    var ring: int = RunState.map_node_ring[id]
    var angle: float = RunState.map_node_angle[id]
    return _map_center() + Vector2(cos(angle), sin(angle)) * ring * _ring_spacing()

func _node_radius(id: int) -> float:
    return BOSS_RADIUS if id == RunState.BOSS_NODE else NODE_RADIUS

func _draw() -> void:
    _draw_background()
    var reachable: Array = RunState.reachable_map_nodes()
    _draw_edges(reachable)
    for id in RunState.map_node_ring.size():
        _draw_node(id, reachable)
    _draw_hint(reachable)

func _draw_background() -> void:
    # Anchor the checker pattern on the map center so the boss always sits
    # on a square corner, however the window is sized.
    var center: Vector2 = _map_center()
    var first_col: int = int(floor(-center.x / SQUARE_SIZE))
    var last_col: int = int(ceil((size.x - center.x) / SQUARE_SIZE))
    var first_row: int = int(floor(-center.y / SQUARE_SIZE))
    var last_row: int = int(ceil((size.y - center.y) / SQUARE_SIZE))
    for row in range(first_row, last_row):
        for col in range(first_col, last_col):
            var color: Color = LIGHT_SQUARE if posmod(row + col, 2) == 0 else DARK_SQUARE
            draw_rect(Rect2(center + Vector2(col, row) * SQUARE_SIZE, Vector2(SQUARE_SIZE, SQUARE_SIZE)), color)
    draw_rect(Rect2(Vector2.ZERO, size), SHADE)

func _draw_edges(reachable: Array) -> void:
    var current: int = RunState.map_current_node
    var current_cleared: bool = RunState.map_cleared[current]
    for a in RunState.map_adjacency.size():
        for b in RunState.map_adjacency[a]:
            if b < a:
                continue
            var highlighted: bool = current_cleared and (
                (a == current and b in reachable) or (b == current and a in reachable))
            var color: Color = EDGE_REACHABLE_COLOR if highlighted else EDGE_COLOR
            var width: float = EDGE_REACHABLE_WIDTH if highlighted else EDGE_WIDTH
            if a == RunState.BOSS_NODE:
                draw_line(_node_position(a), _node_position(b), color, width, true)
            else:
                draw_polyline(_edge_points(a, b), color, width, true)

# Every link except the boss's spokes is drawn in polar coordinates — angle
# and radius each interpolated linearly from one end to the other — rather
# than as a straight line. For same-ring neighbors that traces the ring's
# own circle, so each ring reads as a circle. For links between rings, the
# radius only ever moves between the two rings, so the curve can't dip
# across the inner ring the way a long, slanted straight line would; and
# since RunState assigns inward links in angular order, two such curves
# never cross each other either.
func _edge_points(a: int, b: int) -> PackedVector2Array:
    var center: Vector2 = _map_center()
    var spacing: float = _ring_spacing()
    var start_angle: float = RunState.map_node_angle[a]
    var sweep: float = wrapf(RunState.map_node_angle[b] - start_angle, -PI, PI)
    var start_radius: float = RunState.map_node_ring[a] * spacing
    var end_radius: float = RunState.map_node_ring[b] * spacing
    var points := PackedVector2Array()
    for i in EDGE_SEGMENTS + 1:
        var t: float = float(i) / EDGE_SEGMENTS
        var angle: float = start_angle + sweep * t
        points.append(center + Vector2(cos(angle), sin(angle)) * lerpf(start_radius, end_radius, t))
    return points

func _draw_node(id: int, reachable: Array) -> void:
    var pos: Vector2 = _node_position(id)
    var radius: float = _node_radius(id)
    if id == _hovered_node:
        radius *= HOVER_SCALE
    var is_reachable: bool = id in reachable
    var is_current: bool = id == RunState.map_current_node
    var is_cleared: bool = RunState.map_cleared[id]

    var fill: Color = NODE_FILL
    var glyph: String = ENEMY_GLYPH
    var glyph_color: Color = GLYPH_COLOR
    if is_current:
        fill = NODE_CURRENT_FILL
        glyph = PLAYER_GLYPH
        glyph_color = GLYPH_ON_CURRENT_COLOR
    elif id == RunState.BOSS_NODE:
        fill = BOSS_FILL
        glyph = BOSS_GLYPH
    elif is_cleared:
        fill = NODE_CLEARED_FILL
        glyph = CLEARED_GLYPH
        glyph_color = GLYPH_CLEARED_COLOR

    draw_circle(pos, radius, fill)
    draw_arc(pos, radius, 0.0, TAU, 48,
        NODE_REACHABLE_OUTLINE if is_reachable else NODE_OUTLINE,
        4.0 if is_reachable else 2.0, true)
    _draw_centered_text(glyph, pos, int(radius * 1.4), glyph_color)

func _draw_centered_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
    var font: Font = get_theme_default_font()
    var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    # draw_string positions by baseline, so shift down by half of
    # (ascent - descent) to center the glyph's visible body on pos.
    var baseline_offset: float = (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
    draw_string(font, Vector2(pos.x - text_width * 0.5, pos.y + baseline_offset), text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_hint(reachable: Array) -> void:
    var text: String = "Choose your next battle"
    if not RunState.map_cleared[RunState.map_current_node]:
        text = "Click your piece to begin"
    elif reachable.is_empty():
        text = ""
    draw_string(get_theme_default_font(), Vector2(0, 32), text,
        HORIZONTAL_ALIGNMENT_CENTER, size.x, HINT_FONT_SIZE, Color.WHITE)

func _node_at(point: Vector2) -> int:
    var best: int = -1
    var best_distance: float = INF
    for id in RunState.map_node_ring.size():
        var distance: float = point.distance_to(_node_position(id))
        if distance <= _node_radius(id) * HOVER_SCALE and distance < best_distance:
            best = id
            best_distance = distance
    return best

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var hovered: int = _node_at(event.position)
        if not (hovered in RunState.reachable_map_nodes()):
            hovered = -1
        if hovered != _hovered_node:
            _hovered_node = hovered
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered != -1 else Control.CURSOR_ARROW
            queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var clicked: int = _node_at(event.position)
        if clicked != -1 and clicked in RunState.reachable_map_nodes():
            _enter_node(clicked)

func _enter_node(id: int) -> void:
    # Already beaten — just walk there, no match.
    if RunState.map_cleared[id]:
        RunState.map_current_node = id
        _hovered_node = -1
        mouse_default_cursor_shape = Control.CURSOR_ARROW
        queue_redraw()
        return
    RunState.map_pending_node = id
    get_tree().change_scene_to_file(MATCH_SCENE_PATH)
