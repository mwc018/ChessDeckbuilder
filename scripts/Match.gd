extends Control

# Space reserved below the board for the hand, so centering the board
# doesn't push it down into that area as the window grows.
const RESERVED_BOTTOM_HEIGHT: float = 340.0

@onready var board: Control = $Board
@onready var status_label: Label = $StatusLabel
@onready var progress_label: Label = $ProgressLabel
@onready var energy_display: Control = $EnergyDisplay

const ENERGY_DISPLAY_GAP: float = 24.0

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
        _on_board_status_changed(board.last_status_text)
        _on_energy_changed(board.energy, board.MAX_ENERGY)
    _update_progress_label()

func _on_board_status_changed(text: String) -> void:
    if status_label != null:
        status_label.text = text

# Each card's actual rule effect is applied by Board itself (the one place
# that owns board/turn state) — this is just left as a hook for any future
# non-gameplay reaction to a card being played.
func _on_card_played(card: Control) -> void:
    print("Card played: ", card.card_name)

func _on_energy_changed(energy: int, max_energy: int) -> void:
    if energy_display != null:
        energy_display.energy = energy
        energy_display.max_energy = max_energy

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
