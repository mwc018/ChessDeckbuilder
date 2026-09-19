extends Control

# Emitted after a drop target (e.g. the board) has accepted this card and
# is about to free it. Let listeners (Match, a hand manager, etc.) react to
# the card being played before the node disappears.
signal played

# Emitted on a plain click — a press immediately followed by a release with
# no drag in between. Unused by the hand (which only ever drags a card to
# play it), but needed by anything that wants "click to select" instead,
# like the victory screen's card draft.
signal clicked

enum CardType { ACTION, MODIFIER, POWER }

const CARD_TYPE_LABELS := {
    CardType.ACTION: "Action",
    CardType.MODIFIER: "Modifier",
    CardType.POWER: "Power",
}
const CARD_TYPE_COLORS := {
    CardType.ACTION: Color(0.72, 0.20, 0.16, 1.0),
    CardType.MODIFIER: Color(0.20, 0.42, 0.68, 1.0),
    CardType.POWER: Color(0.62, 0.48, 0.14, 1.0),
}

const CARD_BODY_COLOR := Color(0.93, 0.87, 0.76, 1.0)
const COST_BADGE_COLOR := Color(0.16, 0.28, 0.46, 1.0)
const TEXT_COLOR := Color(0.16, 0.12, 0.08, 1.0)
const FLAVOR_TEXT_COLOR := Color(0.40, 0.34, 0.27, 1.0)
const IMAGE_PLACEHOLDER_COLOR := Color(0.72, 0.68, 0.62, 1.0)

const PADDING: float = 14.0
const HEADER_HEIGHT: float = 42.0
const TYPE_LABEL_HEIGHT: float = 20.0
const FLAVOR_TEXT_HEIGHT: float = 44.0
const COST_BADGE_SIZE: float = 34.0

@export var card_name: String = "Card Name":
    set(value):
        card_name = value
        _refresh_if_ready()

@export var cost: int = 1:
    set(value):
        cost = value
        _refresh_if_ready()

@export var card_type: CardType = CardType.ACTION:
    set(value):
        card_type = value
        _refresh_if_ready()

@export_multiline var description: String = "Describe what this card does.":
    set(value):
        description = value
        _refresh_if_ready()

# Left empty, no flavor text block is shown and the description gets that
# space back — not every card needs flavor text.
@export_multiline var flavor_text: String = "":
    set(value):
        flavor_text = value
        _refresh_if_ready()

# Left null, this just shows the placeholder swatch below the name — set it
# once real card art exists.
@export var art: Texture2D = null:
    set(value):
        art = value
        _refresh_if_ready()

@export var card_size: Vector2 = Vector2(240, 340):
    set(value):
        card_size = value
        custom_minimum_size = value
        size = value
        _refresh_if_ready()

func _ready() -> void:
    custom_minimum_size = card_size
    size = card_size
    refresh_display()

func _refresh_if_ready() -> void:
    if is_inside_tree():
        refresh_display()

# Rebuilds the card's visuals from its current properties. Safe to call
# again any time after changing card_name/cost/card_type/description/art/card_size.
func refresh_display() -> void:
    # free(), not queue_free() — the latter defers removal to end-of-frame,
    # so a same-named child added immediately below would collide with the
    # not-yet-removed old one and get silently auto-renamed by Godot,
    # leaving get_node_or_null("NameLabel") etc. pointing at stale nodes.
    for child in get_children():
        child.free()

    var content_width: float = card_size.x - PADDING * 2.0
    var image_height: float = card_size.y * 0.30
    var image_top: float = PADDING + HEADER_HEIGHT + 8.0
    var type_label_top: float = image_top + image_height + 8.0
    var description_top: float = type_label_top + TYPE_LABEL_HEIGHT + 6.0
    var flavor_height: float = FLAVOR_TEXT_HEIGHT if flavor_text != "" else 0.0
    var flavor_top: float = card_size.y - PADDING - flavor_height
    var description_height: float = max(flavor_top - (8.0 if flavor_height > 0.0 else 0.0) - description_top, 20.0)

    _build_frame()
    _build_image_placeholder(content_width, image_top, image_height)
    _build_name_label(content_width)
    _build_type_label(content_width, type_label_top)
    _build_description_label(content_width, description_top, description_height)
    if flavor_height > 0.0:
        _build_flavor_label(content_width, flavor_top, flavor_height)
    _build_cost_badge()

func _build_frame() -> void:
    var frame := Panel.new()
    frame.name = "Frame"
    frame.position = Vector2.ZERO
    frame.size = card_size
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = CARD_BODY_COLOR
    style.border_color = CARD_TYPE_COLORS.get(card_type, CARD_TYPE_COLORS[CardType.ACTION])
    style.set_border_width_all(2)
    style.border_width_top = 10
    style.set_corner_radius_all(14)
    frame.add_theme_stylebox_override("panel", style)
    add_child(frame)

func _build_image_placeholder(content_width: float, top: float, height: float) -> void:
    var container := Control.new()
    container.name = "Art"
    container.position = Vector2(PADDING, top)
    container.size = Vector2(content_width, height)
    container.clip_contents = true
    container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(container)

    var background := ColorRect.new()
    background.name = "Placeholder"
    background.color = IMAGE_PLACEHOLDER_COLOR
    background.size = container.size
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.add_child(background)

    if art != null:
        var texture_rect := TextureRect.new()
        texture_rect.name = "Art"
        texture_rect.texture = art
        texture_rect.size = container.size
        texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        container.add_child(texture_rect)

func _build_name_label(content_width: float) -> void:
    var label := Label.new()
    label.name = "NameLabel"
    label.text = card_name
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    # autowrap_mode must be set before size — see _build_description_label.
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    label.clip_text = true
    label.position = Vector2(PADDING, PADDING)
    label.size = Vector2(content_width, HEADER_HEIGHT)
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", TEXT_COLOR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)

func _build_type_label(content_width: float, top: float) -> void:
    var label := Label.new()
    label.name = "TypeLabel"
    label.text = CARD_TYPE_LABELS.get(card_type, "").to_upper()
    label.position = Vector2(PADDING, top)
    label.size = Vector2(content_width, TYPE_LABEL_HEIGHT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", CARD_TYPE_COLORS.get(card_type, TEXT_COLOR))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)

func _build_description_label(content_width: float, top: float, height: float) -> void:
    var label := Label.new()
    label.name = "DescriptionLabel"
    label.text = description
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    # clip_text forces single-line clipping and overrides word wrap, so it's
    # deliberately left off here — clip_contents clips any overflow instead,
    # without preventing the wrap. autowrap_mode must be set before size:
    # Control.size is clamped to at least get_combined_minimum_size(), and
    # with autowrap off that minimum is the width of the whole unwrapped
    # line, which would force size right back past the card's edge.
    label.autowrap_mode = TextServer.AUTOWRAP_WORD
    label.clip_contents = true
    label.position = Vector2(PADDING, top)
    label.size = Vector2(content_width, height)
    label.add_theme_font_size_override("font_size", 13)
    label.add_theme_color_override("font_color", TEXT_COLOR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)

# RichTextLabel + BBCode, not Label — plain Label has no italic toggle short
# of swapping in a whole separate italic font resource.
func _build_flavor_label(content_width: float, top: float, height: float) -> void:
    var label := RichTextLabel.new()
    label.name = "FlavorLabel"
    label.text = "[center][i]%s[/i][/center]" % flavor_text
    label.bbcode_enabled = true
    label.fit_content = false
    label.scroll_active = false
    label.position = Vector2(PADDING, top)
    label.size = Vector2(content_width, height)
    label.add_theme_font_size_override("normal_font_size", 12)
    label.add_theme_font_size_override("italics_font_size", 12)
    label.add_theme_color_override("default_color", FLAVOR_TEXT_COLOR)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)

func _build_cost_badge() -> void:
    var badge := Panel.new()
    badge.name = "CostBadge"
    badge.position = Vector2(-4.0, -4.0)
    badge.size = Vector2(COST_BADGE_SIZE, COST_BADGE_SIZE)
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = COST_BADGE_COLOR
    style.set_corner_radius_all(int(COST_BADGE_SIZE / 2.0))
    style.border_color = Color(1.0, 1.0, 1.0, 0.85)
    style.set_border_width_all(2)
    badge.add_theme_stylebox_override("panel", style)
    add_child(badge)

    var label := Label.new()
    label.text = str(cost)
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge.add_child(label)

var _is_drag_source: bool = false
var _press_local_pos: Vector2 = Vector2.ZERO
var _pressed: bool = false
var _preview: Control = null

# force_drag() is called on the first hint of motion after the press,
# rather than returning data from _get_drag_data (which only runs once
# Godot's built-in drag-detection threshold has been crossed, by which
# point the mouse has already moved a bit from where the card was grabbed).
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _pressed = true
            _press_local_pos = event.position
        else:
            # A release while _pressed was still true (never cleared by a
            # drag starting) means this was a plain click, not a drag.
            if _pressed:
                clicked.emit()
            _pressed = false
        return

    if _pressed and not _is_drag_source and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
        _preview = duplicate()
        visible = false
        _is_drag_source = true
        _pressed = false
        force_drag({"type": "card", "card": self}, _preview)
        accept_event()

# Re-applied every frame rather than set once, so the preview tracks the
# original grab point regardless of whether/when Godot's own drag-preview
# code touches the preview's position — this runs after input handling for
# the frame, so it's always the last word on where the preview ends up.
func _process(_delta: float) -> void:
    if _is_drag_source and is_instance_valid(_preview):
        _preview.global_position = get_global_mouse_position() - _press_local_pos

# Broadcast to every Control when any drag ends, regardless of who started
# or received it — used here just to reveal this card again once its own
# drag is over, whether it was cancelled or dropped nowhere. A successful
# play frees the card first, so this never has to run for that case.
func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        visible = true
        _is_drag_source = false
        _preview = null

# Node._input still reaches this card while its preview is being dragged
# elsewhere on screen, so a right-click can cancel the drag no matter where
# the mouse currently is.
func _input(event: InputEvent) -> void:
    if not _is_drag_source:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        get_viewport().gui_cancel_drag()
        get_viewport().set_input_as_handled()

# Called by a drop target (e.g. the board) once it accepts this card.
func confirm_played() -> void:
    played.emit()
    queue_free()
