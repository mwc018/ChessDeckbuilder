extends Control

# Space reserved below the board for the hand, so centering the board
# doesn't push it down into that area as the window grows.
const RESERVED_BOTTOM_HEIGHT: float = 340.0

@onready var board: Control = $Board
@onready var status_label: Label = $StatusLabel
@onready var progress_label: Label = $ProgressLabel
@onready var energy_display: Control = $EnergyDisplay
@onready var hand_container: Control = $Hand
@onready var end_turn_button: Button = $EndTurnButton
@onready var pile_label: Label = $PileLabel

const ENERGY_DISPLAY_GAP: float = 24.0
const END_TURN_BUTTON_GAP: float = 24.0

# The only place that maps a card's name to its scene. Every card that
# exists gets an entry here, whether or not it's in the starting deck below
# — Match needs to know the scene for any name Board might ever hand back
# (e.g. a card found mid-run later on). Board only ever deals in names (see
# draw_pile/discard_pile there); it has no idea these scenes exist.
const CARD_SCENES: Dictionary = {
    "Overextend": preload("res://scenes/cards/Overextend.tscn"),
    "Battering Ram": preload("res://scenes/cards/BatteringRam.tscn"),
    "Stride": preload("res://scenes/cards/Stride.tscn"),
    "Square Dance": preload("res://scenes/cards/SquareDance.tscn"),
    "Gallop": preload("res://scenes/cards/Gallop.tscn"),
    "Trample": preload("res://scenes/cards/Trample.tscn"),
    "Sidestep": preload("res://scenes/cards/Sidestep.tscn"),
    "Free Rein": preload("res://scenes/cards/FreeRein.tscn"),
}

# The singleton starting deck — one copy of each card the player begins
# with. Square Dance is deliberately left out: it's a card found later in a
# run rather than something every game starts with (that "find it later"
# mechanic doesn't exist yet, so for now it's simply not dealt at all).
const STARTING_DECK_CARD_NAMES: Array[String] = [
    "Overextend", "Battering Ram", "Stride", "Gallop", "Trample", "Sidestep", "Free Rein",
]

# AI difficulty is randomized per game within board.ai_difficulty_min/max
# (set in the editor on the Board node) — see Board.randomize_ai_difficulty().
# Match number is just a play counter; it no longer drives difficulty.
var match_number: int = 1

func _ready() -> void:
    _center_board()
    if board != null:
        board.status_changed.connect(_on_board_status_changed)
        board.card_played.connect(_on_card_played)
        board.energy_changed.connect(_on_energy_changed)
        board.turn_started.connect(_on_turn_started)
        board.initialize_deck(STARTING_DECK_CARD_NAMES)
        _on_board_status_changed(board.last_status_text)
        _on_energy_changed(board.energy, board.MAX_ENERGY)
        # The game starts on the player's turn already, so turn_started never
        # fires for it "for free" — prime the very first hand manually, same
        # reason the two lines above prime energy/status manually too.
        _on_turn_started()
    if end_turn_button != null:
        end_turn_button.pressed.connect(_on_end_turn_pressed)
    _update_progress_label()

func _on_board_status_changed(text: String) -> void:
    if status_label != null:
        status_label.text = text
    _update_end_turn_button()

# Each card's actual rule effect is applied by Board itself (the one place
# that owns board/turn state) — this is just left as a hook for any future
# non-gameplay reaction to a card being played.
func _on_card_played(card: Control) -> void:
    print("Card played: ", card.card_name)

func _on_energy_changed(energy: int, max_energy: int) -> void:
    if energy_display != null:
        energy_display.energy = energy
        energy_display.max_energy = max_energy

# Fired by Board right when control returns to the player (after the AI's
# move) — draw a fresh 5-card hand to match the energy/action refill Board
# just did on its own side.
func _on_turn_started() -> void:
    if board == null or hand_container == null:
        return
    for card_name in board.draw_card_names(5):
        var scene: PackedScene = CARD_SCENES.get(card_name)
        if scene == null:
            continue
        hand_container.add_child(scene.instantiate())
    _update_pile_label()

# The End Turn button: whatever's left in hand is discarded (not played —
# freed directly rather than via confirm_played(), so no card effect
# applies and no energy is spent), then Board ends the turn.
func _on_end_turn_pressed() -> void:
    if board == null or hand_container == null:
        return
    for card in hand_container.get_children():
        board.discard_card_name(card.card_name)
        card.queue_free()
    board.end_turn()
    _update_pile_label()

func _update_end_turn_button() -> void:
    if end_turn_button == null or board == null:
        return
    end_turn_button.disabled = board.game_over or board.awaiting_promotion or board.current_turn != board.PLAYER_COLOR

func _update_pile_label() -> void:
    if pile_label == null or board == null:
        return
    pile_label.text = "Draw: %d\nDiscard: %d" % [board.draw_pile.size(), board.discard_pile.size()]

func _update_progress_label() -> void:
    if progress_label == null or board == null:
        return
    progress_label.text = "Match %d — AI difficulty %d%%" % [match_number, int(round(board.ai_difficulty * 100.0))]

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _center_board()

func _center_board() -> void:
    if board == null:
        board = get_node_or_null("Board")
    if board == null:
        return

    var available_height: float = max(size.y - RESERVED_BOTTOM_HEIGHT, 100.0)
    var target_size: float = min(size.x, available_height) * 0.85
    target_size = clamp(target_size, 320.0, 640.0)
    var x := (size.x - target_size) * 0.5
    var y := (available_height - target_size) * 0.5
    board.size = Vector2(target_size, target_size)
    board.position = Vector2(x, y)

    if energy_display != null:
        var display_size: Vector2 = energy_display.size
        energy_display.position = Vector2(
            x - ENERGY_DISPLAY_GAP - display_size.x,
            y + (target_size - display_size.y) * 0.5
        )

    if end_turn_button != null:
        var button_size: Vector2 = end_turn_button.size
        end_turn_button.position = Vector2(
            x + target_size + END_TURN_BUTTON_GAP,
            y + (target_size - button_size.y) * 0.5
        )
        if pile_label != null:
            pile_label.position = Vector2(
                x + target_size + END_TURN_BUTTON_GAP,
                end_turn_button.position.y + button_size.y + 12.0
            )
