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
@onready var debug_win_button: Button = $DebugWinButton

const ENERGY_DISPLAY_GAP: float = 24.0
const END_TURN_BUTTON_GAP: float = 24.0

const MATCH_SCENE_PATH: String = "res://scenes/Match.tscn"
const VICTORY_SCENE_PATH: String = "res://scenes/Victory.tscn"

# AI difficulty is randomized per game within board.ai_difficulty_min/max
# (set in the editor on the Board node) — see Board.randomize_ai_difficulty().

func _ready() -> void:
    _center_board()
    if board != null:
        board.status_changed.connect(_on_board_status_changed)
        board.card_played.connect(_on_card_played)
        board.energy_changed.connect(_on_energy_changed)
        board.turn_started.connect(_on_turn_started)
        board.match_won.connect(_on_match_won)
        board.initialize_deck(RunState.deck_card_names)
        _on_board_status_changed(board.last_status_text)
        _on_energy_changed(board.energy, board.MAX_ENERGY)
        # The game starts on the player's turn already, so turn_started never
        # fires for it "for free" — prime the very first hand manually, same
        # reason the two lines above prime energy/status manually too.
        _on_turn_started()
    if end_turn_button != null:
        end_turn_button.pressed.connect(_on_end_turn_pressed)
    if debug_win_button != null and board != null:
        debug_win_button.pressed.connect(board.debug_win)
    _update_progress_label()

func _on_board_status_changed(text: String) -> void:
    if status_label != null:
        status_label.text = text
    _update_end_turn_button()

# Most cards' actual rule effect is applied by Board itself (the one place
# that owns board/turn state) — Clean Slate is the one exception, since its
# effect (discard the rest of hand, draw that many back) is purely about
# the hand, which only Match owns; Board has no idea individual Card nodes
# exist. card_played fires from Board._drop_data before confirm_played()
# frees the played card, so it's still in hand_container here — excluded by
# identity rather than freed along with the rest.
func _on_card_played(card: Control) -> void:
    print("Card played: ", card.card_name)
    if card.card_name == "Clean Slate":
        _resolve_clean_slate(card)

func _resolve_clean_slate(played_card: Control) -> void:
    if board == null or hand_container == null:
        return
    var remaining: Array = []
    for card in hand_container.get_children():
        if card != played_card:
            remaining.append(card)
    for card in remaining:
        board.discard_card_name(card.card_name)
        card.queue_free()
    _draw_cards(remaining.size())

func _on_energy_changed(energy: int, max_energy: int) -> void:
    if energy_display != null:
        energy_display.energy = energy
        energy_display.max_energy = max_energy

# Fired by Board right when control returns to the player (after the AI's
# move) — draw a fresh 5-card hand to match the energy/action refill Board
# just did on its own side.
func _on_turn_started() -> void:
    _draw_cards(5)

func _draw_cards(count: int) -> void:
    if board == null or hand_container == null:
        return
    for card_name in board.draw_card_names(count):
        var scene: PackedScene = CardCatalog.CARD_SCENES.get(card_name)
        if scene == null:
            continue
        hand_container.add_child(scene.instantiate())
    _update_pile_label()

# Fired by Board on a win (real checkmate or the debug win button). Offers
# up to 3 cards drawn from CardCatalog.REWARD_POOL_CARD_NAMES, excluding
# whatever's already in RunState.deck_card_names (no offering a duplicate
# of something already drafted). If nothing's left in the pool, skip the
# draft screen entirely and go straight to the next match. This changes
# scenes to Victory.tscn (rather than showing it as an overlay) so the
# board/hand aren't visible — and distracting — behind it.
func _on_match_won() -> void:
    var eligible: Array[String] = []
    for card_name in CardCatalog.REWARD_POOL_CARD_NAMES:
        if not (card_name in RunState.deck_card_names):
            eligible.append(card_name)
    if eligible.is_empty():
        # Nothing left in the reward pool — skip the draft screen entirely
        # and go straight into the next match.
        RunState.advance_to_new_match()
        get_tree().change_scene_to_file(MATCH_SCENE_PATH)
        return
    eligible.shuffle()
    RunState.pending_reward_offer = eligible.slice(0, min(3, eligible.size()))
    get_tree().change_scene_to_file(VICTORY_SCENE_PATH)

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
    progress_label.text = "Match %d — AI difficulty %d%%" % [RunState.match_number, int(round(board.ai_difficulty * 100.0))]

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
