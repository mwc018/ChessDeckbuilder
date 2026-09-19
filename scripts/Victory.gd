extends Control

# A standalone scene (Match.gd change_scene_to_file's here on a win, rather
# than adding this as a child overlay) so the board/hand behind it aren't
# visible while this is up. Since the previous scene is gone by the time
# this one exists, offered_card_names comes from the RunState autoload
# (RunState.pending_reward_offer, set by Match right before the scene
# change) instead of being set directly by a caller.
const MATCH_SCENE_PATH: String = "res://scenes/Match.tscn"

const TITLE_COLOR := Color(1.0, 0.85, 0.4, 1.0)
const SUBTITLE_COLOR := Color(0.9, 0.9, 0.9, 1.0)

# Matches Card.gd's own default card_size, so these look identical in size
# to cards in hand.
const CARD_WIDTH: float = 240.0
const CARD_HEIGHT: float = 340.0
const CARD_GAP: float = 36.0
const BUTTON_SIZE: Vector2 = Vector2(160, 48)
const BUTTON_GAP: float = 18.0
const FADE_DURATION: float = 0.3
const SLIDE_DURATION: float = 0.35

# Everything (title through the Cancel button) is laid out as one block,
# offset from _content_top (computed in _ready() to vertically center that
# whole block in the viewport) rather than from fixed distances from the
# top of the screen — see _layout_content_top().
const TITLE_HEIGHT: float = 48.0
const TITLE_SUBTITLE_GAP: float = 8.0
const SUBTITLE_HEIGHT: float = 30.0
const SUBTITLE_CARDS_GAP: float = 30.0
const CARDS_BUTTONS_GAP: float = 24.0

var _content_top: float = 0.0
var _title_y: float = 0.0
var _subtitle_y: float = 0.0
var _cards_y: float = 0.0
var _buttons_y: float = 0.0

# Read from RunState/CardCatalog in _ready() rather than set by a caller —
# see the note above on why (this scene has no caller by the time it exists).
var offered_card_names: Array[String] = []
var card_scenes: Dictionary = {}

var _card_nodes: Array[Control] = []
var _original_positions: Array[Vector2] = []
var _center_slot: Vector2 = Vector2.ZERO
var _selected_index: int = -1

var _skip_button: Button
var _confirm_button: Button
var _cancel_button: Button

func _ready() -> void:
    # No dimming background — just stop clicks from passing through to
    # whatever's underneath (nothing's actually behind this scene now that
    # it's a full scene change rather than an overlay, but this keeps the
    # cards/buttons from receiving input before they're actually built).
    mouse_filter = Control.MOUSE_FILTER_STOP

    offered_card_names = RunState.pending_reward_offer
    # Cleared immediately after reading so a stale offer can never leak into
    # a later run (e.g. if this scene were ever reached some other way).
    RunState.pending_reward_offer = []
    card_scenes = CardCatalog.CARD_SCENES

    _layout_content_top()
    _build_title()
    _build_cards()
    _build_buttons()

# Computes where the whole title-through-Cancel-button block starts so that
# block sits vertically centered in the viewport, rather than every piece
# being offset from a handful of small fixed distances from the top of the
# screen (which left most of the screen's bottom half empty).
func _layout_content_top() -> void:
    var buttons_height: float = BUTTON_SIZE.y * 2.0 + BUTTON_GAP
    var content_height: float = (
        TITLE_HEIGHT + TITLE_SUBTITLE_GAP + SUBTITLE_HEIGHT +
        SUBTITLE_CARDS_GAP + CARD_HEIGHT + CARDS_BUTTONS_GAP + buttons_height
    )
    _content_top = (size.y - content_height) * 0.5
    _title_y = _content_top
    _subtitle_y = _title_y + TITLE_HEIGHT + TITLE_SUBTITLE_GAP
    _cards_y = _subtitle_y + SUBTITLE_HEIGHT + SUBTITLE_CARDS_GAP
    _buttons_y = _cards_y + CARD_HEIGHT + CARDS_BUTTONS_GAP

func _build_title() -> void:
    var title := Label.new()
    title.text = "Victory!"
    title.position = Vector2(0, _title_y)
    title.size = Vector2(size.x, TITLE_HEIGHT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", TITLE_COLOR)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Choose a card to add to your deck"
    subtitle.position = Vector2(0, _subtitle_y)
    subtitle.size = Vector2(size.x, SUBTITLE_HEIGHT)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
    subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(subtitle)

# Lays out however many cards were actually offered (normally 3, but fewer
# once most of the reward pool has already been drafted) evenly centered as
# a group. The center slot this computes is where a selected card slides to
# — for a 3-card layout this works out to be exactly the middle card's own
# starting position (the math cancels out), so selecting the middle card
# never visibly moves it, only the two side cards fade.
func _build_cards() -> void:
    var count: int = offered_card_names.size()
    var row_width: float = count * CARD_WIDTH + max(count - 1, 0) * CARD_GAP
    var start_x: float = (size.x - row_width) * 0.5
    var group_center_x: float = size.x * 0.5
    _center_slot = Vector2(group_center_x - CARD_WIDTH * 0.5, _cards_y)

    for i in range(count):
        var card_name: String = offered_card_names[i]
        var scene: PackedScene = card_scenes.get(card_name)
        if scene == null:
            continue
        var card: Control = scene.instantiate()
        card.card_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
        var pos := Vector2(start_x + i * (CARD_WIDTH + CARD_GAP), _cards_y)
        card.position = pos
        add_child(card)
        card.clicked.connect(_on_card_clicked.bind(i))
        _card_nodes.append(card)
        _original_positions.append(pos)

func _build_buttons() -> void:
    var button_x: float = (size.x - BUTTON_SIZE.x) * 0.5
    var button_y: float = _buttons_y

    _skip_button = Button.new()
    _skip_button.text = "Skip"
    _skip_button.position = Vector2(button_x, button_y)
    _skip_button.size = BUTTON_SIZE
    _skip_button.pressed.connect(_on_skip_pressed)
    add_child(_skip_button)

    _confirm_button = Button.new()
    _confirm_button.text = "Confirm"
    _confirm_button.position = Vector2(button_x, button_y)
    _confirm_button.size = BUTTON_SIZE
    _confirm_button.visible = false
    _confirm_button.pressed.connect(_on_confirm_pressed)
    add_child(_confirm_button)

    _cancel_button = Button.new()
    _cancel_button.text = "Cancel"
    _cancel_button.position = Vector2(button_x, button_y + BUTTON_SIZE.y + BUTTON_GAP)
    _cancel_button.size = BUTTON_SIZE
    _cancel_button.visible = false
    _cancel_button.pressed.connect(_on_cancel_pressed)
    add_child(_cancel_button)

func _on_card_clicked(index: int) -> void:
    if _selected_index != -1:
        return
    _selected_index = index

    for i in range(_card_nodes.size()):
        var card: Control = _card_nodes[i]
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if i == index:
            var tween := create_tween()
            tween.tween_property(card, "position", _center_slot, SLIDE_DURATION)
        else:
            var tween := create_tween()
            tween.tween_property(card, "modulate:a", 0.0, FADE_DURATION)

    _skip_button.visible = false
    _confirm_button.visible = true
    _cancel_button.visible = true

func _on_cancel_pressed() -> void:
    if _selected_index == -1:
        return
    var picked_index: int = _selected_index
    _selected_index = -1

    for i in range(_card_nodes.size()):
        var card: Control = _card_nodes[i]
        card.mouse_filter = Control.MOUSE_FILTER_STOP
        if i == picked_index:
            var tween := create_tween()
            tween.tween_property(card, "position", _original_positions[i], SLIDE_DURATION)
        else:
            var tween := create_tween()
            tween.tween_property(card, "modulate:a", 1.0, FADE_DURATION)

    _skip_button.visible = true
    _confirm_button.visible = false
    _cancel_button.visible = false

func _on_confirm_pressed() -> void:
    if _selected_index == -1:
        return
    RunState.deck_card_names.append(offered_card_names[_selected_index])
    RunState.advance_to_new_match()
    get_tree().change_scene_to_file(MATCH_SCENE_PATH)

func _on_skip_pressed() -> void:
    if _selected_index != -1:
        return
    RunState.advance_to_new_match()
    get_tree().change_scene_to_file(MATCH_SCENE_PATH)
