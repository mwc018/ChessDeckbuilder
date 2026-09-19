extends Control

signal status_changed(text: String)
signal card_played(card: Control)
signal energy_changed(energy: int, max_energy: int)
# Fired exactly when control returns to the player (after the AI's move) —
# lets whoever owns the hand (Match) know it's time to draw a fresh 5 cards.
signal turn_started
# Fired on a real win (checkmate) or a debug_win() call — lets Match show
# the victory/card-draft screen.
signal match_won

const FILES: PackedStringArray = ["a", "b", "c", "d", "e", "f", "g", "h"]
const STARTING_LAYOUT := {
    "a8": "♜",
    "b8": "♞",
    "c8": "♝",
    "d8": "♛",
    "e8": "♚",
    "f8": "♝",
    "g8": "♞",
    "h8": "♜",
    "a7": "♟",
    "b7": "♟",
    "c7": "♟",
    "d7": "♟",
    "e7": "♟",
    "f7": "♟",
    "g7": "♟",
    "h7": "♟",
    "a2": "♙",
    "b2": "♙",
    "c2": "♙",
    "d2": "♙",
    "e2": "♙",
    "f2": "♙",
    "g2": "♙",
    "h2": "♙",
    "a1": "♖",
    "b1": "♘",
    "c1": "♗",
    "d1": "♕",
    "e1": "♔",
    "f1": "♗",
    "g1": "♘",
    "h1": "♖",
}

# The human player always plays White; there is no draw outcome — whichever
# side runs out of legal moves (whether checkmated or merely stalemated) loses.
const PLAYER_COLOR: String = "white"

# The only four king "from+to" coordinate pairs that can ever be a castle
# (standard chess, no chess960), each mapped to the rook move that goes with it.
const CASTLE_ROOK_MOVES := {
    "e1g1": {"from": "h1", "to": "f1"},
    "e1c1": {"from": "a1", "to": "d1"},
    "e8g8": {"from": "h8", "to": "f8"},
    "e8c8": {"from": "a8", "to": "d8"},
}

const LIGHT_SQUARE := Color(0.84, 0.72, 0.58, 1.0)
const DARK_SQUARE := Color(0.38, 0.26, 0.20, 1.0)
const PIECE_SCENE := preload("res://scenes/Piece.tscn")
const PROMOTION_POPUP_SCENE := preload("res://scenes/PromotionPopup.tscn")

var square_nodes: Dictionary = {}
var piece_nodes: Dictionary = {}
var square_base_colors: Dictionary = {}
var square_highlight_overlays: Dictionary = {}
var highlighted_moves: Array[String] = []
var highlighted_paths: Array[String] = []
var hovered_piece_coord: String = ""
var selected_piece_coord: String = ""
var selected_piece_moves: Array[String] = []

# Logical board state (coord -> piece symbol), kept in sync with piece_nodes.
# Separate from the visual layer so moves can be simulated without touching the scene tree.
var board_state: Dictionary = {}
# Whether each side still has the right to castle on that side, i.e. neither
# the king nor that rook has moved (or been captured) yet this game. Kept as
# plain instance state — separate from board_state — because it depends on
# move history, not just the current position.
var castle_rights: Dictionary = {}
# The square a pawn skipped over on its last two-square advance (e.g. "e3"),
# or "" if the last move wasn't one — the only square an en passant capture
# can currently land on. Reset every move since the right only lasts one ply.
var en_passant_target: String = ""
var current_turn: String = "white"
var game_over: bool = false
var last_status_text: String = ""
# Set while the player is being asked what to promote a pawn to — input is
# blocked and the move itself hasn't happened yet (see _show_promotion_popup).
var awaiting_promotion: bool = false
var promotion_popup: Control = null

# Set by playing the Overextend card; lets the human's own next pawn move
# from its original square advance 3 squares instead of 2 (see
# _collect_legal_moves_for_piece). Cleared once that move happens, whether
# or not it was actually a qualifying pawn move — the effect only lasts for
# the player's very next move ("this turn" — a chess turn is one move).
var pending_overextend: bool = false

# Set by playing the Stride card; lets the human's own next pawn move advance
# 2 squares regardless of whether that pawn has already moved this game (see
# _collect_legal_moves_for_piece). Cleared once that move happens, whether or
# not it was actually a qualifying pawn move — same "next move only" window
# as Overextend, not "the next pawn to move" (which could be turns away).
var pending_stride: bool = false

# Set by playing the Square Dance card; lets the human's own next piece to
# move swap places with an adjacent friendly piece instead of moving normally
# (see _add_square_dance_destinations/_move_piece's swap branch). Same
# "next move only" window as Overextend/Stride, not "the next piece to move"
# in some open-ended sense — it's spent by whatever the player's very next
# move turns out to be, swap or not.
var pending_square_dance: bool = false

# Set by playing the Trample card; lets the human's own next pawn move capture
# the piece directly ahead of it (normally a pawn can only capture diagonally
# and is blocked by any piece straight ahead — see _add_trample_destination).
# Same "next move only" window as Overextend/Stride/Square Dance, not "the
# next pawn to move" (which could be turns away).
var pending_trample: bool = false

# Set by playing the Sidestep card; lets the human's own next pawn move step
# one square sideways onto an empty square instead of moving normally (see
# _add_sidestep_destinations/_move_piece's sidestep branch) — pawns can never
# normally move sideways at all. Same "next move only" window as the other
# next-move cards, and like Square Dance's swap, this is exempt from
# spending the player's one action for the turn (see _finish_move) — it's
# an ACTION-type card, not a Modifier.
var pending_sidestep: bool = false

# Set by playing the Strafe card; lets the human's own next pawn move step
# onto either diagonally-forward square even when it's empty (see
# _add_strafe_destinations/_move_piece's strafe branch) — normally a pawn
# can only reach those two squares by capturing. Same "next move only"
# window as the other next-move cards. A Modifier card, not an ACTION —
# unlike Sidestep this does spend the player's one action for the turn.
var pending_strafe: bool = false

# Set by playing the Free Rein card; lets the human's own next Knight move
# happen without spending the player's one action for the turn — unlike
# Square Dance/Sidestep it doesn't add any new destinations, the Knight
# still just moves normally (see _move_piece/_restrict_to_action_exempt_
# destinations), it's exempt from the action economy entirely. Same "next
# move only" window as the other next-move cards. An ACTION-type card, not
# a Modifier.
var pending_free_rein: bool = false

# Set by playing the Homecoming card; the human's own next Knight to move
# has its normal destinations replaced entirely with whichever of its
# side's two starting squares (b1/g1 for White) are currently empty (see
# _add_homecoming_destinations) — it can go home and nowhere else. Since
# that's the only kind of move it can make, that move is exempt from
# spending the player's one action for the turn (see _move_piece/
# _restrict_to_action_exempt_destinations). Same "next move only" window as
# the other next-move cards. An ACTION-type card, not a Modifier.
var pending_homecoming: bool = false

# Set by playing the Withdrawal card; same idea as Homecoming but for a
# Rook — its next move's destinations are replaced entirely with whichever
# of its side's two starting squares (a1/h1 for White) are currently empty
# (see _add_withdrawal_destinations), and that move is exempt from spending
# the player's one action. Same "next move only" window as the other
# next-move cards. An ACTION-type card, not a Modifier.
var pending_withdrawal: bool = false

# Set by playing the Absolution card; same idea as Homecoming but for a
# Bishop — its next move's destinations are replaced entirely with whichever
# of its side's two starting squares (c1/f1 for White) are currently empty
# (see _add_absolution_destinations), and that move is exempt from spending
# the player's one action. Same "next move only" window as the other
# next-move cards. An ACTION-type card, not a Modifier.
var pending_absolution: bool = false

# Set by playing the Return to Court card; same idea as Homecoming but for
# the Queen — its next move's destinations are replaced entirely with its
# one starting square (d1 for White) if empty (see
# _add_return_to_court_destinations), and that move is exempt from spending
# the player's one action. Same "next move only" window as the other
# next-move cards. An ACTION-type card, not a Modifier.
var pending_return_to_court: bool = false

# Set by playing the Royal Recall card; same idea as Homecoming but for the
# King — its next move's destinations are replaced entirely with its one
# starting square (e1 for White) if empty (see
# _add_royal_recall_destinations), and that move is exempt from spending
# the player's one action. Same "next move only" window as the other
# next-move cards. An ACTION-type card, not a Modifier.
var pending_royal_recall: bool = false

# Set by playing the Open Gate card; lets the human's own next Rook move
# happen without spending the player's one action for the turn — same idea
# as Free Rein but for a Rook (see _move_piece/_restrict_to_action_exempt_
# destinations). Same "next move only" window as the other next-move cards.
# An ACTION-type card, not a Modifier.
var pending_open_gate: bool = false

# Set by playing the Divine Exception card; lets the human's own next Bishop
# move happen without spending the player's one action for the turn — same
# idea as Free Rein/Open Gate but for a Bishop (see _move_piece/_restrict_
# to_action_exempt_destinations). Same "next move only" window as the other
# next-move cards. An ACTION-type card, not a Modifier.
var pending_divine_exception: bool = false

# Set by playing the Battering Ram card; lets the human's own next Rook move
# that captures a piece continue through it and capture a second piece
# further along the same line, if one is there to hit. Unlike Overextend this
# waits for a Rook actually moving (see _move_piece), not just the player's
# very next move — "the next Rook to move" may not be it — but it still
# expires at end_turn() same as every other pending_* card effect: it can
# survive an earlier, unrelated move within the same turn (e.g. a Square
# Dance swap of some other piece), never into a future turn.
var pending_battering_ram: bool = false

# Set by playing the Gallop card; lets the human's own next Knight move
# continue 1 additional square in any direction after a non-capturing leap
# (see _add_gallop_destinations). Like Battering Ram this waits for a Knight
# actually moving, not just the player's very next move — "the next Knight
# to move" may not be it — but likewise never survives past end_turn().
var pending_gallop: bool = false

# Set by playing the Leap of Faith card; lets the human's own next Bishop
# move jump over the first piece blocking its diagonal (whether friend or
# foe) and keep sliding from beyond it, landing on an empty square or
# capturing an enemy piece there (see _add_leap_of_faith_destinations). Like
# Battering Ram/Gallop this waits for a Bishop actually moving, not just the
# player's very next move, but likewise never survives past end_turn().
var pending_leap_of_faith: bool = false

# The resource cards cost to play. Refills to MAX_ENERGY at the start of
# each of the player's turns; spent energy otherwise carries through the
# opponent's turn unchanged.
const MAX_ENERGY: int = 3
var energy: int = MAX_ENERGY

# Logical-only (card names, not scenes/nodes) — Match owns turning these into
# actual Card instances in the hand. Populated by initialize_deck(), drawn
# from by draw_card_names(), refilled by discard_card_name().
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []

# The player's one normal chess move (relocate/capture/castle — everything
# _move_piece does except a Square Dance swap, which is an ACTION-type card
# and explicitly exempt from this). Modifier cards never grant more of these,
# they just change what this one move can do. Refills to MAX_ACTIONS at the
# start of each of the player's turns, same cadence as energy.
const MAX_ACTIONS: int = 1
var actions_remaining: int = MAX_ACTIONS

# The opponent is always the color the human doesn't play.
var ai_color: String = "black" if PLAYER_COLOR == "white" else "white"
@export var ai_enabled: bool = true
# Each game picks a fresh difficulty at random from this range, so set the
# spread you want the AI to vary across here rather than a single fixed value.
@export_range(0.0, 1.0, 0.01) var ai_difficulty_min: float = 0.1
@export_range(0.0, 1.0, 0.01) var ai_difficulty_max: float = 0.4
var ai_difficulty: float = 0.15
# At low difficulty the search can finish in single-digit milliseconds, which
# reads as a glitch rather than a move — this floors how long "thinking"
# takes, without adding to searches that are already slower than this.
@export_range(0.0, 3.0, 0.05) var ai_min_think_seconds: float = 0.6
var ai := ChessAI.new()
var ai_thread: Thread = null
var ai_think_started_ms: int = 0

func _ready() -> void:
    randomize_ai_difficulty()
    _build_square_grid()
    _place_pieces()
    _layout_board()
    _update_status()

func reset_game() -> void:
    randomize_ai_difficulty()
    if promotion_popup != null:
        promotion_popup.queue_free()
        promotion_popup = null
    awaiting_promotion = false
    selected_piece_coord = ""
    _clear_move_highlights()
    for coord in piece_nodes.keys():
        var piece: Control = piece_nodes[coord]
        if piece != null:
            piece.queue_free()
    piece_nodes.clear()
    current_turn = "white"
    game_over = false
    pending_overextend = false
    pending_stride = false
    pending_square_dance = false
    pending_trample = false
    pending_sidestep = false
    pending_strafe = false
    pending_free_rein = false
    pending_homecoming = false
    pending_withdrawal = false
    pending_absolution = false
    pending_return_to_court = false
    pending_royal_recall = false
    pending_open_gate = false
    pending_divine_exception = false
    pending_battering_ram = false
    pending_gallop = false
    pending_leap_of_faith = false
    energy = MAX_ENERGY
    energy_changed.emit(energy, MAX_ENERGY)
    actions_remaining = MAX_ACTIONS
    draw_pile.append_array(discard_pile)
    discard_pile.clear()
    draw_pile.shuffle()
    _place_pieces()
    _layout_board()
    _update_status()

# Picks a new difficulty within [ai_difficulty_min, ai_difficulty_max] for the
# upcoming game. Called on load and on every reset, so difficulty varies game
# to game instead of ratcheting up over a run.
func randomize_ai_difficulty() -> void:
    var lo: float = min(ai_difficulty_min, ai_difficulty_max)
    var hi: float = max(ai_difficulty_min, ai_difficulty_max)
    ai_difficulty = randf_range(lo, hi)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _layout_board()

func _build_square_grid() -> void:
    var existing: Node = get_node_or_null("Squares")
    if existing != null:
        existing.queue_free()

    var squares := Control.new()
    squares.name = "Squares"
    squares.set_anchors_preset(Control.PRESET_FULL_RECT)
    squares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    squares.size_flags_vertical = Control.SIZE_EXPAND_FILL
    squares.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(squares)

    for rank in range(8, 0, -1):
        for file_index in range(FILES.size()):
            var file_name: String = FILES[file_index]
            var square := ColorRect.new()
            square.name = "Square_%s%d" % [file_name, rank]
            square.color = LIGHT_SQUARE if (file_index + (8 - rank)) % 2 == 0 else DARK_SQUARE
            square_base_colors["%s%d" % [file_name, rank]] = square.color
            square.set_anchors_preset(Control.PRESET_TOP_LEFT)
            square.offset_left = 0
            square.offset_top = 0
            square.offset_right = 0
            square.offset_bottom = 0
            # PASS, not STOP: clicks are still handled below, but a card
            # dropped on this square needs to bubble up to Board's own
            # _can_drop_data/_drop_data to register as "played on the board".
            square.mouse_filter = Control.MOUSE_FILTER_PASS
            square.connect("gui_input", Callable(self, "_on_square_input").bind("%s%d" % [file_name, rank]))
            squares.add_child(square)
            square_nodes["%s%d" % [file_name, rank]] = square

func _layout_board() -> void:
    var board_size: float = min(size.x, size.y)
    var inset: float = board_size * 0.05
    var square_size: float = (board_size - (inset * 2.0)) / 8.0
    var origin_x: float = (size.x - board_size) * 0.5 + inset
    var origin_y: float = (size.y - board_size) * 0.5 + inset

    var rank_values: Array[int] = [8, 7, 6, 5, 4, 3, 2, 1]
    for rank in rank_values:
        for file_index in range(FILES.size()):
            var file_name: String = FILES[file_index]
            var coord: String = "%s%d" % [file_name, rank]
            var square: ColorRect = square_nodes.get(coord)
            if square == null:
                continue

            var row_index: int = 8 - rank
            var x: float = origin_x + (file_index * square_size)
            var y: float = origin_y + (row_index * square_size)
            square.position = Vector2(x, y)
            square.size = Vector2(square_size, square_size)

    for coord in piece_nodes.keys():
        var piece: Control = piece_nodes[coord]
        var square: ColorRect = square_nodes.get(coord)
        if piece == null or square == null:
            continue
        if piece.get_parent() != square:
            square.add_child(piece)
        piece.set_anchors_preset(Control.PRESET_FULL_RECT)
        piece.position = Vector2.ZERO
        piece.offset_left = 0
        piece.offset_top = 0
        piece.offset_right = 0
        piece.offset_bottom = 0

    for coord in square_nodes.keys():
        var square: ColorRect = square_nodes.get(coord)
        if square == null:
            continue
        var overlay: ColorRect = square_highlight_overlays.get(coord)
        if overlay != null:
            overlay.size = Vector2(max(square.size.x - 14.0, 0.0), max(square.size.y - 14.0, 0.0))
            overlay.position = Vector2(7.0, 7.0)

func _place_pieces() -> void:
    board_state.clear()
    castle_rights = {
        "white_king_side": true,
        "white_queen_side": true,
        "black_king_side": true,
        "black_queen_side": true,
    }
    en_passant_target = ""
    for coord in STARTING_LAYOUT.keys():
        var square: ColorRect = square_nodes.get(coord)
        if square == null:
            continue

        var piece: Control = PIECE_SCENE.instantiate()
        piece.name = coord
        piece.symbol = STARTING_LAYOUT[coord]
        piece.dark = _is_dark_piece(STARTING_LAYOUT[coord])
        piece.board = self
        piece.square_coord = coord
        piece.mouse_filter = Control.MOUSE_FILTER_STOP
        square.add_child(piece)
        piece.set_anchors_preset(Control.PRESET_FULL_RECT)
        piece.position = Vector2.ZERO
        piece.offset_left = 0
        piece.offset_top = 0
        piece.offset_right = 0
        piece.offset_bottom = 0
        piece_nodes[coord] = piece
        board_state[coord] = STARTING_LAYOUT[coord]

func _on_piece_hovered(coord: String) -> void:
    hovered_piece_coord = coord
    if game_over or awaiting_promotion:
        return
    # Pieces still receive mouse-enter/exit while a card is being dragged
    # over them (their mouse_filter has to be PASS so a card can be dropped
    # on an occupied square), so without this check dragging a card across
    # the board would light up move highlights along the way.
    if get_viewport().gui_is_dragging():
        return
    if selected_piece_coord == "" and _is_current_turn_piece(coord):
        _show_moves_for_piece(coord)

func _on_piece_unhovered() -> void:
    hovered_piece_coord = ""
    if selected_piece_coord == "":
        _clear_move_highlights()

func _on_piece_clicked(coord: String) -> void:
    if game_over or awaiting_promotion:
        return

    if coord == selected_piece_coord:
        selected_piece_coord = ""
        _clear_move_highlights()
        _set_piece_selection_state()
        return

    if selected_piece_coord != "":
        if coord in selected_piece_moves:
            _attempt_move(selected_piece_coord, coord)
            return
        selected_piece_coord = ""
        _clear_move_highlights()

    if not _is_current_turn_piece(coord):
        return

    selected_piece_coord = coord
    _show_moves_for_piece(coord)
    selected_piece_moves = highlighted_moves.duplicate()
    _set_piece_selection_state()

# _can_drop_data/_drop_data walk up from whatever's under the mouse (a
# square, a piece, ...) until a control accepts, so implementing these here
# on Board is enough to accept a card dropped anywhere on the board. A card
# that costs more than the player's current energy is rejected here, same
# as a drop outside the board — it just snaps back to the hand. Also
# rejected outside the player's own turn — with turns no longer flipping
# instantly on every move, the AI's "thinking" pause is long enough that
# without this a card could otherwise be played while it's not the player's
# turn at all.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY or data.get("type") != "card":
        return false
    if game_over or awaiting_promotion or current_turn != PLAYER_COLOR:
        return false
    var card: Control = data.get("card")
    return card != null and is_instance_valid(card) and card.cost <= energy

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    var card: Control = data.get("card")
    if card == null or not is_instance_valid(card):
        return
    _apply_card_effect(card.card_name)
    discard_card_name(card.card_name)
    energy -= card.cost
    energy_changed.emit(energy, MAX_ENERGY)
    card_played.emit(card)
    card.confirm_played()

# --- Deck/hand API (used by Match, which owns the actual Card node
# instances and the registry mapping a card name to its scene). Board only
# ever deals in card-name strings — see draw_pile/discard_pile above. ---

# Called once by Match after wiring signals, with the run's current deck
# (RunState.deck_card_names) — a singleton deck, one copy of each unique
# card, not multiple copies of the same one.
func initialize_deck(card_names: Array) -> void:
    draw_pile.clear()
    draw_pile.append_array(card_names)
    draw_pile.shuffle()
    discard_pile.clear()

# Pops up to count names off the draw pile, reshuffling the discard pile
# into it first whenever it runs dry. Returns fewer than count only if both
# piles combined don't have enough cards left.
func draw_card_names(count: int) -> Array[String]:
    var drawn: Array[String] = []
    for i in range(count):
        if draw_pile.is_empty():
            if discard_pile.is_empty():
                break
            draw_pile.append_array(discard_pile)
            discard_pile.clear()
            draw_pile.shuffle()
        drawn.append(draw_pile.pop_back())
    return drawn

func discard_card_name(card_name: String) -> void:
    discard_pile.append(card_name)

# The End Turn button's entry point: discards whatever's left in hand (that
# part is Match's job, done before calling this), spends the "next move
# only" card windows that went unused, and hands control to the AI. Every
# pending_* card effect expires here at the latest — none of them are meant
# to survive into a future turn, only within the turn they were played
# (Battering Ram/Gallop can still survive an earlier, unrelated move within
# this same turn — e.g. a Square Dance swap of some other piece — via the
# piece-type-gated clears in _finish_move; they just don't carry past
# end_turn() the way they used to).
func end_turn() -> void:
    if game_over or awaiting_promotion or current_turn != PLAYER_COLOR:
        return
    pending_overextend = false
    pending_stride = false
    pending_square_dance = false
    pending_trample = false
    pending_sidestep = false
    pending_strafe = false
    pending_free_rein = false
    pending_homecoming = false
    pending_withdrawal = false
    pending_absolution = false
    pending_return_to_court = false
    pending_royal_recall = false
    pending_open_gate = false
    pending_divine_exception = false
    pending_battering_ram = false
    pending_gallop = false
    pending_leap_of_faith = false
    selected_piece_coord = ""
    _clear_move_highlights()
    _set_piece_selection_state()
    current_turn = ai_color
    _update_status()

# Debug-only: immediately ends the match as a win, bypassing the actual
# board state entirely, so the victory/card-draft flow can be tested
# without having to play out and win a full game. Mirrors exactly what
# _update_status() does on a real win.
func debug_win() -> void:
    if game_over:
        return
    game_over = true
    _set_status("You win!")
    match_won.emit()

# Dispatches by card name to whatever rule change that card makes. Cards
# with no effect implemented yet still play (leave the hand) — they just
# don't do anything, same as before any card had a real effect.
func _apply_card_effect(card_name: String) -> void:
    if card_name == "Overextend" and current_turn == PLAYER_COLOR:
        pending_overextend = true
    elif card_name == "Stride" and current_turn == PLAYER_COLOR:
        pending_stride = true
    elif card_name == "Square Dance" and current_turn == PLAYER_COLOR:
        pending_square_dance = true
    elif card_name == "Trample" and current_turn == PLAYER_COLOR:
        pending_trample = true
    elif card_name == "Sidestep" and current_turn == PLAYER_COLOR:
        pending_sidestep = true
    elif card_name == "Strafe" and current_turn == PLAYER_COLOR:
        pending_strafe = true
    elif card_name == "Free Rein" and current_turn == PLAYER_COLOR:
        pending_free_rein = true
    elif card_name == "Homecoming" and current_turn == PLAYER_COLOR:
        pending_homecoming = true
    elif card_name == "Withdrawal" and current_turn == PLAYER_COLOR:
        pending_withdrawal = true
    elif card_name == "Absolution" and current_turn == PLAYER_COLOR:
        pending_absolution = true
    elif card_name == "Return to Court" and current_turn == PLAYER_COLOR:
        pending_return_to_court = true
    elif card_name == "Royal Recall" and current_turn == PLAYER_COLOR:
        pending_royal_recall = true
    elif card_name == "Open Gate" and current_turn == PLAYER_COLOR:
        pending_open_gate = true
    elif card_name == "Divine Exception" and current_turn == PLAYER_COLOR:
        pending_divine_exception = true
    elif card_name == "Battering Ram" and current_turn == PLAYER_COLOR:
        pending_battering_ram = true
    elif card_name == "Gallop" and current_turn == PLAYER_COLOR:
        pending_gallop = true
    elif card_name == "Leap of Faith" and current_turn == PLAYER_COLOR:
        pending_leap_of_faith = true

func _on_square_input(event: InputEvent, coord: String) -> void:
    if game_over or awaiting_promotion:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if selected_piece_coord != "" and coord in selected_piece_moves:
            _attempt_move(selected_piece_coord, coord)

# Routes a human move through the promotion popup first if it's a pawn
# reaching the last rank; otherwise executes it immediately. The AI never
# comes through here — it always auto-queens (see _on_ai_move_ready).
func _attempt_move(from_coord: String, to_coord: String) -> void:
    if current_turn == PLAYER_COLOR and _is_promotion_move(from_coord, to_coord):
        _show_promotion_popup(from_coord, to_coord)
        return
    _move_piece(from_coord, to_coord)

func _is_promotion_move(from_coord: String, to_coord: String) -> bool:
    var symbol: String = board_state.get(from_coord, "")
    if symbol != "♙" and symbol != "♟":
        return false
    var promotion_rank: int = 8 if symbol == "♙" else 1
    return int(to_coord.substr(1)) == promotion_rank

func _show_promotion_popup(from_coord: String, to_coord: String) -> void:
    if promotion_popup != null:
        return
    awaiting_promotion = true
    selected_piece_coord = ""
    _clear_move_highlights()
    _set_piece_selection_state()

    var popup: Control = PROMOTION_POPUP_SCENE.instantiate()
    popup.is_white = board_state.get(from_coord, "") == "♙"
    popup.size = size
    popup.position = Vector2.ZERO
    add_child(popup)
    promotion_popup = popup
    popup.piece_chosen.connect(func(symbol: String) -> void:
        _on_promotion_chosen(from_coord, to_coord, symbol)
    )

func _on_promotion_chosen(from_coord: String, to_coord: String, symbol: String) -> void:
    if promotion_popup != null:
        promotion_popup.queue_free()
        promotion_popup = null
    awaiting_promotion = false
    _move_piece(from_coord, to_coord, symbol)

func _is_current_turn_piece(coord: String) -> bool:
    if not board_state.has(coord):
        return false
    return _is_white_piece(board_state[coord]) == (current_turn == "white")

func _show_moves_for_piece(coord: String) -> void:
    _clear_move_highlights()
    if coord == "" or not piece_nodes.has(coord):
        return

    var piece: Control = piece_nodes[coord]
    var symbol: String = piece.symbol
    var moves: Dictionary = _collect_legal_moves_for_piece(symbol, coord, board_state, castle_rights, en_passant_target)
    var destinations: Array[String] = moves.get("destinations", [])
    var paths: Array[String] = moves.get("paths", [])
    var destination_lookup: Dictionary = {}

    for destination in destinations:
        destination_lookup[destination] = true
        _apply_move_square_style(destination, "destination")
        highlighted_moves.append(destination)

    for path_coord in paths:
        if destination_lookup.has(path_coord):
            continue
        _apply_move_square_style(path_coord, "path")
        highlighted_paths.append(path_coord)

func _apply_move_square_style(coord: String, style: String) -> void:
    var square: ColorRect = square_nodes.get(coord)
    if square == null:
        return

    var overlay: ColorRect
    if square_highlight_overlays.has(coord):
        overlay = square_highlight_overlays[coord]
    else:
        overlay = ColorRect.new()
        overlay.name = "MoveHighlight"
        overlay.mouse_filter = Control.MOUSE_FILTER_PASS
        square.add_child(overlay)
        square_highlight_overlays[coord] = overlay
        overlay.connect("mouse_entered", Callable(self, "_on_destination_hovered").bind(coord))
        overlay.connect("mouse_exited", Callable(self, "_on_destination_unhovered").bind(coord))

    if style == "destination":
        square.color = Color(0.80, 1.0, 0.84, 1.0)
        overlay.color = Color(0.12, 0.60, 0.24, 1.0)
        overlay.z_index = 2
        overlay.set_meta("default_color", overlay.color)
    else:
        square.color = Color(0.18, 0.54, 0.25, 0.78)
        overlay.color = Color(0.10, 0.35, 0.17, 0.72)
        overlay.z_index = 1
        overlay.set_meta("default_color", overlay.color)

    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.offset_left = 7.0
    overlay.offset_top = 7.0
    overlay.offset_right = -7.0
    overlay.offset_bottom = -7.0
    square.modulate = Color(1, 1, 1, 1)

func _on_destination_hovered(coord: String) -> void:
    var overlay: ColorRect = square_highlight_overlays.get(coord)
    if overlay == null:
        return
    if overlay.get_meta("default_color", Color(0.12, 0.60, 0.24, 1.0)) == Color(0.12, 0.60, 0.24, 1.0):
        overlay.color = Color(0.28, 0.92, 0.38, 1.0)

func _on_destination_unhovered(coord: String) -> void:
    var overlay: ColorRect = square_highlight_overlays.get(coord)
    if overlay == null:
        return
    overlay.color = overlay.get_meta("default_color", Color(0.12, 0.60, 0.24, 1.0))

func _clear_move_highlights() -> void:
    for coord in highlighted_moves:
        var square: ColorRect = square_nodes.get(coord)
        if square != null:
            square.modulate = Color(1, 1, 1, 1)
            square.color = square_base_colors.get(coord, square.color)
            var overlay: ColorRect = square_highlight_overlays.get(coord)
            if overlay != null:
                overlay.queue_free()
                square_highlight_overlays.erase(coord)
    for coord in highlighted_paths:
        var square: ColorRect = square_nodes.get(coord)
        if square != null:
            square.modulate = Color(1, 1, 1, 1)
            square.color = square_base_colors.get(coord, square.color)
            var overlay: ColorRect = square_highlight_overlays.get(coord)
            if overlay != null:
                overlay.queue_free()
                square_highlight_overlays.erase(coord)
    highlighted_moves.clear()
    highlighted_paths.clear()
    selected_piece_moves.clear()

func _set_piece_selection_state() -> void:
    for coord in piece_nodes.keys():
        var piece: Control = piece_nodes[coord]
        if piece == null:
            continue
        if piece.has_method("set_selected"):
            piece.set_selected(coord == selected_piece_coord)

func _move_piece(from_coord: String, to_coord: String, promotion_symbol: String = "") -> void:
    if not piece_nodes.has(from_coord):
        return

    var moving_piece: Control = piece_nodes[from_coord]
    if moving_piece == null:
        return

    var moving_symbol: String = board_state.get(from_coord, "")

    # Square Dance: the only way to_coord can already hold a piece of the
    # mover's own color is via the swap destinations _add_square_dance_
    # destinations added — a normal move never targets a friendly-occupied
    # square. Handled as its own short-circuit since none of the capture,
    # castling, en passant, or promotion handling below applies to it.
    var to_symbol: String = board_state.get(to_coord, "")
    var is_square_dance_swap: bool = to_symbol != "" and _is_white_piece(to_symbol) == _is_white_piece(moving_symbol)
    if is_square_dance_swap:
        _update_castle_rights_for_move(from_coord, to_coord)
        _swap_piece_nodes(from_coord, to_coord)
        en_passant_target = ""
        _finish_move(moving_symbol, true)
        return

    # Sidestep: the only way a pawn destination can share its origin's rank
    # is via _add_sidestep_destinations (pawns never normally move sideways
    # at all). Also handled as its own short-circuit — without this, the
    # en passant check just below would misfire on it (same file-differs/
    # target-empty pattern an actual en passant capture has), erasing the
    # square the pawn just landed on.
    var is_pawn_mover: bool = moving_symbol == "♙" or moving_symbol == "♟"
    var is_sidestep_move: bool = is_pawn_mover and to_symbol == "" and to_coord.substr(1) == from_coord.substr(1) and to_coord.substr(0, 1) != from_coord.substr(0, 1)
    if is_sidestep_move:
        _update_castle_rights_for_move(from_coord, to_coord)
        _relocate_piece_node(from_coord, to_coord)
        en_passant_target = ""
        _finish_move(moving_symbol, true)
        return

    # Strafe: a pawn move onto an empty, different-file square is normally
    # only ever a real en passant capture (see the comment below) — the one
    # exception is a Strafe move onto a diagonally-forward square that
    # *isn't* the current en_passant_target (only _add_strafe_destinations
    # ever offers such a square, so this can't be confused with a real
    # capture). Handled as its own short-circuit for the same reason as
    # Sidestep: the en passant check just below would otherwise misfire on
    # it and erase whatever happens to be sitting on an unrelated square.
    var is_strafe_move: bool = is_pawn_mover and to_symbol == "" and to_coord.substr(0, 1) != from_coord.substr(0, 1) and to_coord != en_passant_target
    if is_strafe_move:
        _update_castle_rights_for_move(from_coord, to_coord)
        _relocate_piece_node(from_coord, to_coord)
        en_passant_target = ""
        if promotion_symbol != "":
            _apply_promotion(to_coord, promotion_symbol)
        _finish_move(moving_symbol)
        return

    if piece_nodes.has(to_coord):
        var captured: Control = piece_nodes[to_coord]
        if captured != null:
            captured.queue_free()
        piece_nodes.erase(to_coord)

    var is_king: bool = moving_symbol == "♔" or moving_symbol == "♚"
    var rook_move: Dictionary = CASTLE_ROOK_MOVES.get(from_coord + to_coord, {}) if is_king else {}
    # A pawn moving diagonally onto an empty square that IS the current
    # en_passant_target can only be a real en passant capture (a Strafe move
    # onto any other empty diagonal square is already handled and returned
    # above, and a same-rank sidestep above that) — a normal diagonal pawn
    # move is otherwise always onto an occupied square.
    var is_en_passant_capture: bool = is_pawn_mover and from_coord.substr(0, 1) != to_coord.substr(0, 1) and not board_state.has(to_coord)
    var en_passant_capture_coord: String = to_coord.substr(0, 1) + from_coord.substr(1) if is_en_passant_capture else ""
    var next_en_passant_target: String = _compute_en_passant_target(from_coord, to_coord, moving_symbol)
    var battering_ram_pierced_coord: String = _resolve_battering_ram_pierce(from_coord, to_coord, moving_symbol)

    _update_castle_rights_for_move(from_coord, to_coord)
    _relocate_piece_node(from_coord, to_coord)
    if not rook_move.is_empty():
        _relocate_piece_node(rook_move["from"], rook_move["to"])
    if battering_ram_pierced_coord != "":
        if piece_nodes.has(battering_ram_pierced_coord):
            var pierced_piece: Control = piece_nodes[battering_ram_pierced_coord]
            if pierced_piece != null:
                pierced_piece.queue_free()
            piece_nodes.erase(battering_ram_pierced_coord)
        board_state.erase(battering_ram_pierced_coord)
    if en_passant_capture_coord != "":
        if piece_nodes.has(en_passant_capture_coord):
            var captured_pawn: Control = piece_nodes[en_passant_capture_coord]
            if captured_pawn != null:
                captured_pawn.queue_free()
            piece_nodes.erase(en_passant_capture_coord)
        board_state.erase(en_passant_capture_coord)
    en_passant_target = next_en_passant_target

    if promotion_symbol != "":
        _apply_promotion(to_coord, promotion_symbol)

    # Free Rein/Homecoming/Withdrawal/Absolution/Open Gate/Divine Exception:
    # a normal Knight/Rook/Bishop/Queen/King move needs no special handling
    # of its own — a Homecoming/Withdrawal/Absolution/Return to Court/Royal
    # Recall destination is just an empty square like any other, no capture/
    # castle/en passant/promotion rule treats it differently (Royal Recall's
    # destination is always e1/e8, which never matches a CASTLE_ROOK_MOVES
    # key — those all require the king starting from e1/e8, not returning to
    # it), so the move already went through all that logic above like any
    # other move — it just needs to skip spending the action once it's done.
    var is_free_rein_knight_move: bool = pending_free_rein and moving_symbol == "♘"
    var is_homecoming_knight_move: bool = pending_homecoming and moving_symbol == "♘"
    var is_withdrawal_rook_move: bool = pending_withdrawal and moving_symbol == "♖"
    var is_absolution_bishop_move: bool = pending_absolution and moving_symbol == "♗"
    var is_return_to_court_queen_move: bool = pending_return_to_court and moving_symbol == "♕"
    var is_royal_recall_king_move: bool = pending_royal_recall and moving_symbol == "♔"
    var is_open_gate_rook_move: bool = pending_open_gate and moving_symbol == "♖"
    var is_divine_exception_bishop_move: bool = pending_divine_exception and moving_symbol == "♗"
    var is_action_exempt_move: bool = (
        is_free_rein_knight_move or is_homecoming_knight_move or
        is_withdrawal_rook_move or is_absolution_bishop_move or
        is_return_to_court_queen_move or is_royal_recall_king_move or
        is_open_gate_rook_move or is_divine_exception_bishop_move
    )
    _finish_move(moving_symbol, is_action_exempt_move)

# Shared end-of-move bookkeeping: clears the current selection/highlights,
# consumes whichever "next move" card effects applied to this move, and
# spends the player's one action for the turn (unless this was a Square
# Dance swap or a Sidestep, which are ACTION-type cards and exempt — see
# Board.end_turn/actions_remaining). Turns no longer end here: a player move
# never flips current_turn (only Board.end_turn does, via the End Turn
# button); the AI's own move still flips control straight back to the
# player, refilling energy/actions and signaling turn_started so Match knows
# to draw a fresh hand. Used by every kind of move — normal, Square Dance
# swap, Sidestep — which otherwise share none of the rest of _move_piece's
# capture/castle/en passant handling.
func _finish_move(moving_symbol: String, is_action_exempt: bool = false) -> void:
    selected_piece_coord = ""
    _clear_move_highlights()
    _set_piece_selection_state()

    # The Overextend/Stride/Square Dance/Trample/Sidestep/Strafe/Free Rein/
    # Homecoming/Withdrawal/Absolution/Return to Court/Royal Recall/Open
    # Gate/Divine Exception windows only ever cover the player's very next
    # move — win or lose the bonus, it's spent once that move (this one)
    # happens.
    if current_turn == PLAYER_COLOR:
        pending_overextend = false
        pending_stride = false
        pending_square_dance = false
        pending_trample = false
        pending_sidestep = false
        pending_strafe = false
        pending_free_rein = false
        pending_homecoming = false
        pending_withdrawal = false
        pending_absolution = false
        pending_return_to_court = false
        pending_royal_recall = false
        pending_open_gate = false
        pending_divine_exception = false
        # Battering Ram, Gallop, and Leap of Faith each wait for the next
        # move of their own piece type specifically, however many other
        # moves happen first — spent once that piece moves, whether or not
        # the bonus was used.
        if moving_symbol == "♖":
            pending_battering_ram = false
        if moving_symbol == "♘":
            pending_gallop = false
        if moving_symbol == "♗":
            pending_leap_of_faith = false
        if not is_action_exempt:
            actions_remaining = max(actions_remaining - 1, 0)
    elif current_turn == ai_color:
        # The AI just made its one move for the turn — hand control straight
        # back to the player rather than waiting for an End Turn click of
        # its own, since the AI has no hand/energy/action economy of its own.
        current_turn = PLAYER_COLOR
        energy = MAX_ENERGY
        energy_changed.emit(energy, MAX_ENERGY)
        actions_remaining = MAX_ACTIONS
        turn_started.emit()

    _update_status()

# Moves the pieces at from_coord and to_coord (both board_state + their
# visual nodes) into each other's squares — the primitive a Square Dance swap
# uses in place of _relocate_piece_node, which assumes only one side of the
# move is an occupied piece.
func _swap_piece_nodes(from_coord: String, to_coord: String) -> void:
    var piece_a: Control = piece_nodes.get(from_coord)
    var piece_b: Control = piece_nodes.get(to_coord)
    var square_a: ColorRect = square_nodes.get(from_coord)
    var square_b: ColorRect = square_nodes.get(to_coord)

    if piece_a != null and square_a != null and piece_a.get_parent() == square_a:
        square_a.remove_child(piece_a)
    if piece_b != null and square_b != null and piece_b.get_parent() == square_b:
        square_b.remove_child(piece_b)

    if piece_a != null and square_b != null:
        square_b.add_child(piece_a)
        piece_a.square_coord = to_coord
        piece_a.position = Vector2.ZERO
        piece_a.offset_left = 0
        piece_a.offset_top = 0
        piece_a.offset_right = 0
        piece_a.offset_bottom = 0
    if piece_b != null and square_a != null:
        square_a.add_child(piece_b)
        piece_b.square_coord = from_coord
        piece_b.position = Vector2.ZERO
        piece_b.offset_left = 0
        piece_b.offset_top = 0
        piece_b.offset_right = 0
        piece_b.offset_bottom = 0

    piece_nodes[from_coord] = piece_b
    piece_nodes[to_coord] = piece_a

    var symbol_a: String = board_state.get(from_coord, "")
    var symbol_b: String = board_state.get(to_coord, "")
    board_state[from_coord] = symbol_b
    board_state[to_coord] = symbol_a

# Rewrites the piece now sitting at coord (board_state + the visual node) to
# a different symbol — used once a pawn reaching the last rank has an actual
# promotion choice to apply.
func _apply_promotion(coord: String, symbol: String) -> void:
    board_state[coord] = symbol
    var piece: Control = piece_nodes.get(coord)
    if piece != null and piece.has_method("set_symbol"):
        piece.set_symbol(symbol, _is_dark_piece(symbol))

# The queen of the moving pawn's color if from/to is a promotion move,
# otherwise "". The AI always promotes to a queen rather than being asked —
# see ChessAI.gd/Board.simulate_move for why under-promotion isn't modeled.
func _auto_promotion_symbol(from_coord: String, to_coord: String) -> String:
    if not _is_promotion_move(from_coord, to_coord):
        return ""
    return "♕" if board_state.get(from_coord, "") == "♙" else "♛"

# Moves one piece's node + board_state entry from one square to another,
# with no capture/rights/turn handling — the shared primitive _move_piece
# uses for both the moving piece and, on a castle, the rook that comes with it.
func _relocate_piece_node(from_coord: String, to_coord: String) -> void:
    if not piece_nodes.has(from_coord):
        return
    var piece: Control = piece_nodes[from_coord]
    var origin_square: ColorRect = square_nodes.get(from_coord)
    var destination_square: ColorRect = square_nodes.get(to_coord)
    if piece != null and origin_square != null and destination_square != null:
        if piece.get_parent() == origin_square:
            origin_square.remove_child(piece)
        if piece.get_parent() != destination_square:
            destination_square.add_child(piece)
        piece.square_coord = to_coord
        piece.position = Vector2.ZERO
        piece.offset_left = 0
        piece.offset_top = 0
        piece.offset_right = 0
        piece.offset_bottom = 0

    piece_nodes.erase(from_coord)
    piece_nodes[to_coord] = piece

    board_state[to_coord] = board_state[from_coord]
    board_state.erase(from_coord)

# A king or rook leaving (or a rook being captured on) its home square
# permanently revokes that side's castling right, regardless of the piece
# ever returning to that square.
func _update_castle_rights_for_move(from_coord: String, to_coord: String) -> void:
    for coord in [from_coord, to_coord]:
        match coord:
            "e1":
                castle_rights["white_king_side"] = false
                castle_rights["white_queen_side"] = false
            "a1":
                castle_rights["white_queen_side"] = false
            "h1":
                castle_rights["white_king_side"] = false
            "e8":
                castle_rights["black_king_side"] = false
                castle_rights["black_queen_side"] = false
            "a8":
                castle_rights["black_queen_side"] = false
            "h8":
                castle_rights["black_king_side"] = false

# Returns the square a pawn skipped over if this move was a two-square pawn
# advance (the only kind of move that opens up an en passant capture next
# turn), or "" otherwise — including for every non-pawn move, which correctly
# clears any previous target since the right only lasts one ply.
func _compute_en_passant_target(from_coord: String, to_coord: String, moving_symbol: String) -> String:
    if moving_symbol != "♙" and moving_symbol != "♟":
        return ""
    var from_rank: int = int(from_coord.substr(1))
    var to_rank: int = int(to_coord.substr(1))
    if abs(to_rank - from_rank) != 2:
        return ""
    return "%s%d" % [from_coord.substr(0, 1), int((from_rank + to_rank) / 2.0)]

func _update_status() -> void:
    var is_white_turn: bool = current_turn == "white"
    var king_coord: String = _find_king_coord(is_white_turn, board_state)
    var in_check: bool = _is_square_attacked(king_coord, not is_white_turn, board_state)
    var has_move: bool = _has_any_legal_move(is_white_turn, board_state, castle_rights, en_passant_target)
    var color_name: String = "White" if is_white_turn else "Black"

    if not has_move:
        game_over = true
        if current_turn == PLAYER_COLOR:
            _set_status("You lose")
        else:
            _set_status("You win!")
            match_won.emit()
        return

    game_over = false
    if in_check:
        _set_status("%s to move — Check!" % color_name)
    else:
        _set_status("%s to move" % color_name)

    if ai_enabled and current_turn == ai_color:
        call_deferred("_perform_ai_move")

func _perform_ai_move() -> void:
    if game_over or not ai_enabled or current_turn != ai_color:
        return
    if ai_thread != null:
        return  # already thinking; shouldn't happen, but don't double-start

    _set_status("%s is thinking…" % ai_color.capitalize())
    ai_think_started_ms = Time.get_ticks_msec()

    # Run the search on a background thread so a slow (deep/hard) search
    # doesn't freeze the window. The AI only ever touches Board's pure,
    # state-in/state-out rule methods (get_all_legal_moves, simulate_move,
    # etc.) — never piece_nodes/square_nodes or anything else scene-tree
    # related — so calling them off the main thread is safe. It's handed a
    # snapshot of board_state, not the live dictionary, so nothing it does
    # can race with the main thread.
    var state_snapshot: Dictionary = board_state.duplicate()
    var rights_snapshot: Dictionary = castle_rights.duplicate()
    var en_passant_snapshot: String = en_passant_target
    var is_white: bool = ai_color == "white"
    var difficulty: float = ai_difficulty
    ai_thread = Thread.new()
    ai_thread.start(func() -> void:
        var move: Dictionary = ai.choose_move(self, state_snapshot, is_white, difficulty, rights_snapshot, en_passant_snapshot)
        call_deferred("_on_ai_move_ready", move)
    )

func _on_ai_move_ready(move: Dictionary) -> void:
    if ai_thread != null:
        ai_thread.wait_to_finish()
        ai_thread = null

    if move.is_empty() or game_over or current_turn != ai_color:
        return

    var elapsed_seconds: float = (Time.get_ticks_msec() - ai_think_started_ms) / 1000.0
    var remaining_seconds: float = ai_min_think_seconds - elapsed_seconds
    if remaining_seconds > 0.0:
        await get_tree().create_timer(remaining_seconds).timeout
        # The wait was async — re-check nothing invalidated this move while we sat idle
        # (e.g. the player hit "New Match" during the pause).
        if game_over or current_turn != ai_color:
            return

    var from_coord: String = move.get("from")
    var to_coord: String = move.get("to")
    _move_piece(from_coord, to_coord, _auto_promotion_symbol(from_coord, to_coord))

func _set_status(text: String) -> void:
    last_status_text = text
    status_changed.emit(text)

# --- Public rules API (pure functions of a state dict; used by the live board
# and, unchanged, by ChessAI to search hypothetical future positions). ---

# castle_rights (optional) is {"white_king_side": bool, "white_queen_side": bool,
# "black_king_side": bool, "black_queen_side": bool}. en_passant_target (optional)
# is the square a pawn just skipped over ("e3" etc.), or "". Both are separate
# from `state` because they depend on move history, not just piece positions —
# callers that omit them simply get no castling/en passant moves generated
# (safe default). The AI only threads the real values into its root move
# choice, not deeper search plies (see ChessAI.gd) — castling or capturing en
# passant a few plies into a hypothetical line is rare enough not to be worth
# tracking through the whole search.
func get_all_legal_moves(is_white: bool, state: Dictionary, rights: Dictionary = {}, ep_target: String = "") -> Array:
    var king_coord: String = _find_king_coord(is_white, state)
    var king_in_check: bool = _is_square_attacked(king_coord, not is_white, state)
    var moves: Array = []
    for coord in state.keys():
        var symbol: String = state[coord]
        if _is_white_piece(symbol) != is_white:
            continue
        var piece_moves: Dictionary = _collect_legal_moves_for_piece_fast(symbol, coord, state, king_coord, king_in_check, rights, ep_target)
        for destination in piece_moves.get("destinations", []):
            moves.append({"from": coord, "to": destination})
    return moves

func has_any_legal_move(is_white: bool, state: Dictionary, rights: Dictionary = {}, ep_target: String = "") -> bool:
    return _has_any_legal_move(is_white, state, rights, ep_target)

func is_in_check(is_white: bool, state: Dictionary) -> bool:
    var king_coord: String = _find_king_coord(is_white, state)
    return _is_square_attacked(king_coord, not is_white, state)

# Executes whatever from/to is given, including relocating the rook on a
# castle, removing the captured pawn on an en passant capture (detected as a
# pawn moving diagonally onto an empty square — the only way that happens),
# and auto-promoting a pawn that reaches the last rank to a queen (the AI
# never considers under-promotion — see ChessAI.gd). It trusts the caller
# (live board or AI search) to only pass moves that were actually legal to
# generate.
func simulate_move(state: Dictionary, from_coord: String, to_coord: String) -> Dictionary:
    var next_state: Dictionary = state.duplicate()
    var moving_symbol: String = next_state.get(from_coord, "")
    var is_pawn: bool = moving_symbol == "♙" or moving_symbol == "♟"
    var is_diagonal_pawn_move: bool = is_pawn and from_coord.substr(0, 1) != to_coord.substr(0, 1)
    var is_en_passant_capture: bool = is_diagonal_pawn_move and not next_state.has(to_coord)

    next_state[to_coord] = moving_symbol
    next_state.erase(from_coord)

    if moving_symbol == "♔" or moving_symbol == "♚":
        var rook_move: Dictionary = CASTLE_ROOK_MOVES.get(from_coord + to_coord, {})
        if not rook_move.is_empty():
            next_state[rook_move["to"]] = next_state[rook_move["from"]]
            next_state.erase(rook_move["from"])
    elif is_en_passant_capture:
        next_state.erase(to_coord.substr(0, 1) + from_coord.substr(1))
    elif is_pawn:
        if moving_symbol == "♙" and to_coord.substr(1) == "8":
            next_state[to_coord] = "♕"
        elif moving_symbol == "♟" and to_coord.substr(1) == "1":
            next_state[to_coord] = "♛"

    return next_state

func _has_any_legal_move(is_white: bool, state: Dictionary, rights: Dictionary = {}, ep_target: String = "") -> bool:
    var king_coord: String = _find_king_coord(is_white, state)
    var king_in_check: bool = _is_square_attacked(king_coord, not is_white, state)
    for coord in state.keys():
        var symbol: String = state[coord]
        if _is_white_piece(symbol) != is_white:
            continue
        var moves: Dictionary = _collect_legal_moves_for_piece_fast(symbol, coord, state, king_coord, king_in_check, rights, ep_target)
        var destinations: Array[String] = moves.get("destinations", [])
        if not destinations.is_empty():
            return true
    return false

# Convenience single-piece entry point (used by the hover/click preview,
# where recomputing "is my king in check" once per call is not perf-sensitive).
func _collect_legal_moves_for_piece(symbol: String, from_coord: String, state: Dictionary, rights: Dictionary = {}, ep_target: String = "") -> Dictionary:
    var is_white: bool = _is_white_piece(symbol)
    var king_coord: String = _find_king_coord(is_white, state)
    var king_in_check: bool = _is_square_attacked(king_coord, not is_white, state)
    var result: Dictionary = _collect_legal_moves_for_piece_fast(symbol, from_coord, state, king_coord, king_in_check, rights, ep_target)
    if pending_overextend and symbol == "♙" and from_coord.substr(1) == "2":
        _add_overextend_destination(from_coord, state, is_white, result)
    if pending_stride and symbol == "♙":
        _add_stride_destination(from_coord, state, is_white, result)
    if pending_square_dance:
        _add_square_dance_destinations(from_coord, state, is_white, result)
    if pending_trample and symbol == "♙":
        _add_trample_destination(from_coord, state, is_white, result)
    if pending_sidestep and symbol == "♙":
        _add_sidestep_destinations(from_coord, state, is_white, result)
    if pending_strafe and symbol == "♙":
        _add_strafe_destinations(from_coord, state, is_white, result)
    if pending_battering_ram and symbol == "♖":
        _add_battering_ram_destination(from_coord, state, is_white, result)
    if pending_withdrawal and symbol == "♖":
        _add_withdrawal_destinations(from_coord, state, is_white, result)
    if pending_gallop and symbol == "♘":
        _add_gallop_destinations(from_coord, state, is_white, result)
    if pending_homecoming and symbol == "♘":
        _add_homecoming_destinations(from_coord, state, is_white, result)
    if pending_leap_of_faith and symbol == "♗":
        _add_leap_of_faith_destinations(from_coord, state, is_white, result)
    if pending_absolution and symbol == "♗":
        _add_absolution_destinations(from_coord, state, is_white, result)
    if pending_return_to_court and symbol == "♕":
        _add_return_to_court_destinations(from_coord, state, is_white, result)
    if pending_royal_recall and symbol == "♔":
        _add_royal_recall_destinations(from_coord, state, is_white, result)
    if actions_remaining <= 0:
        _restrict_to_action_exempt_destinations(symbol, from_coord, state, is_white, result)
    return result

# Once the player's one action for the turn is spent, only an ACTION-type
# card's destinations remain available — a Square Dance swap (a same-color-
# occupied destination), a Sidestep (a same-rank, different-file, empty
# destination for a pawn — pawns never normally move sideways, so this
# pattern is unambiguous), or, for a Knight while Free Rein is pending,
# every destination it has (Free Rein exempts the whole move rather than
# specific destinations, since it grants no new ones — a Knight just moves
# normally, and likewise for a Rook while Open Gate is pending, or a Bishop
# while Divine Exception is pending). Homecoming/Withdrawal/Absolution/
# Return to Court/Royal Recall need the same "keep everything" treatment for
# a different reason: by the time this runs, that piece's destinations have
# already been replaced entirely with its (empty) starting square(s) — see
# _replace_with_home_square_destinations — so every destination left really
# is exempt and none of it should be stripped by the generic swap/sidestep
# check below. The swap/sidestep predicates are exactly what _move_piece
# itself uses to detect each move type, so this can't drift out of sync with
# what actually gets treated as exempt there. Every other destination this
# function generated would consume an action the player no longer has.
# Paths are cleared too since none of these exempt moves are a slide.
func _restrict_to_action_exempt_destinations(symbol: String, from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    if pending_free_rein and symbol == "♘":
        return
    if pending_homecoming and symbol == "♘":
        return
    if pending_withdrawal and symbol == "♖":
        return
    if pending_absolution and symbol == "♗":
        return
    if pending_return_to_court and symbol == "♕":
        return
    if pending_royal_recall and symbol == "♔":
        return
    if pending_open_gate and symbol == "♖":
        return
    if pending_divine_exception and symbol == "♗":
        return
    var is_pawn: bool = symbol == "♙" or symbol == "♟"
    var from_rank: String = from_coord.substr(1)
    var exempt_only: Array[String] = []
    for destination in result.get("destinations", []):
        var is_swap: bool = state.has(destination) and _is_white_piece(state[destination]) == is_white
        var is_sidestep: bool = is_pawn and not state.has(destination) and destination.substr(1) == from_rank
        if is_swap or is_sidestep:
            exempt_only.append(destination)
    result["destinations"] = exempt_only
    # Must stay a typed Array[String], not a bare [] literal — callers (e.g.
    # _show_moves_for_piece) assign moves.get("paths", []) straight into an
    # Array[String] variable, which fails at runtime if what's actually
    # stored in the dictionary is an untyped Array.
    var no_paths: Array[String] = []
    result["paths"] = no_paths

# Gallop: adds the Knight's "long" leaps — 1 square in one direction and 3 in
# the other, instead of the usual 1-and-2 — as extra destinations. Like any
# normal Knight leap it jumps clean over whatever's between from_coord and
# the landing square (nothing in between blocks it), and it can land on an
# empty square or capture an enemy piece the same as a normal Knight move; a
# friendly piece on the landing square blocks that one leap same as usual.
# Only reachable from _collect_legal_moves_for_piece (the human preview/
# selection entry point), never from the AI/attack-detection paths, so this
# can't affect the AI's search or leak the bonus onto the opponent's knights.
func _add_gallop_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var destinations: Array[String] = result.get("destinations", [])
    var file_index: int = _file_to_index(from_coord.substr(0, 1))
    var rank_index: int = int(from_coord.substr(1)) - 1
    var leap_offsets: Array[Vector2i] = [
        Vector2i(1, 3), Vector2i(1, -3), Vector2i(-1, 3), Vector2i(-1, -3),
        Vector2i(3, 1), Vector2i(3, -1), Vector2i(-3, 1), Vector2i(-3, -1),
    ]

    for offset in leap_offsets:
        var x: int = file_index + offset.x
        var y: int = rank_index + offset.y
        if x < 0 or x >= 8 or y < 0 or y >= 8:
            continue
        var coord: String = _index_to_coord(x, y)
        if coord in destinations:
            continue
        if state.has(coord) and _is_white_piece(state[coord]) == is_white:
            continue
        if state.has(coord) and _is_king(state[coord]):
            continue
        if _move_leaves_king_in_check(from_coord, coord, is_white, state):
            continue
        destinations.append(coord)

    result["destinations"] = destinations

# Shared by Homecoming/Withdrawal/Absolution: REPLACES a piece's
# destinations entirely with whichever of its side's two given starting
# squares are currently empty — unlike every other _add_*_destinations
# helper, which adds to the destinations a piece already has, this one
# deliberately discards them, since the whole point of these cards is "only
# home, nowhere else." The square the piece is already standing on is
# skipped (nothing to "return" to) — if that leaves nothing, this piece
# simply has no legal moves at all this turn. Only reachable from
# _collect_legal_moves_for_piece (the human preview/selection entry point),
# never from the AI/attack-detection paths, so this can't affect the AI's
# search or leak the bonus onto the opponent's pieces.
func _replace_with_home_square_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary, white_home_squares: Array, black_home_squares: Array) -> void:
    # Not a ternary — white_home_squares if is_white else black_home_squares
    # evaluates to an untyped Array at runtime, which fails when assigned
    # into an Array[String] variable.
    var home_squares: Array[String] = []
    if is_white:
        home_squares.append_array(white_home_squares)
    else:
        home_squares.append_array(black_home_squares)
    var destinations: Array[String] = []
    for home_coord in home_squares:
        if home_coord == from_coord or _piece_exists_at(home_coord, state):
            continue
        if _move_leaves_king_in_check(from_coord, home_coord, is_white, state):
            continue
        destinations.append(home_coord)
    result["destinations"] = destinations
    var no_paths: Array[String] = []
    result["paths"] = no_paths

func _add_homecoming_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    _replace_with_home_square_destinations(from_coord, state, is_white, result, ["b1", "g1"], ["b8", "g8"])

func _add_withdrawal_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    _replace_with_home_square_destinations(from_coord, state, is_white, result, ["a1", "h1"], ["a8", "h8"])

func _add_absolution_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    _replace_with_home_square_destinations(from_coord, state, is_white, result, ["c1", "f1"], ["c8", "f8"])

func _add_return_to_court_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    _replace_with_home_square_destinations(from_coord, state, is_white, result, ["d1"], ["d8"])

func _add_royal_recall_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    _replace_with_home_square_destinations(from_coord, state, is_white, result, ["e1"], ["e8"])

# Leap of Faith: for each of the 4 diagonals, finds the first occupied
# square (the blocker — friend or foe, it doesn't matter which) and, if
# there's anything on the board beyond it, treats it as jumped over and
# keeps sliding from there exactly like a normal Bishop move would: every
# empty square along the way is a destination, and the slide stops (adding
# one final capturing destination) at the next occupied square, whether
# that's an enemy piece to capture or a friendly one that blocks. The
# blocker's own square is added as a path (not a destination — it's jumped
# over, never landed on) purely so the jump reads visually as passing over
# it. Only reachable from _collect_legal_moves_for_piece (the human preview/
# selection entry point), never from the AI/attack-detection paths, so this
# can't affect the AI's search or leak the bonus onto the opponent's bishops.
func _add_leap_of_faith_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var destinations: Array[String] = result.get("destinations", [])
    var paths: Array[String] = result.get("paths", [])
    var file_index: int = _file_to_index(from_coord.substr(0, 1))
    var rank_index: int = int(from_coord.substr(1)) - 1
    var directions: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

    for dir in directions:
        var x: int = file_index
        var y: int = rank_index
        var blocker_coord: String = ""
        while true:
            x += dir.x
            y += dir.y
            if x < 0 or x >= 8 or y < 0 or y >= 8:
                break
            var coord: String = _index_to_coord(x, y)
            if state.has(coord):
                blocker_coord = coord
                break
        if blocker_coord == "":
            continue  # nothing blocks this diagonal — nothing to jump over

        var reached: Array[String] = []
        x += dir.x
        y += dir.y
        while x >= 0 and x < 8 and y >= 0 and y < 8:
            var coord: String = _index_to_coord(x, y)
            if state.has(coord):
                if _is_white_piece(state[coord]) != is_white and not _is_king(state[coord]):
                    reached.append(coord)
                break
            reached.append(coord)
            x += dir.x
            y += dir.y

        if reached.is_empty():
            continue  # the blocker was the last thing on the board this way

        if not (blocker_coord in paths):
            paths.append(blocker_coord)
        for index in range(reached.size() - 1):
            if not (reached[index] in paths):
                paths.append(reached[index])
        for coord in reached:
            if coord in destinations:
                continue
            if _move_leaves_king_in_check(from_coord, coord, is_white, state):
                continue
            destinations.append(coord)

    result["destinations"] = destinations
    result["paths"] = paths

# Square Dance: any friendly piece adjacent to this one (any of the 8
# surrounding squares) can be swapped into, regardless of what this piece
# would normally be able to reach — a swap isn't a slide/jump along this
# piece's usual move pattern, so it's added independent of symbol. Only
# reachable from _collect_legal_moves_for_piece (the human preview/selection
# entry point), never from the AI/attack-detection paths, so this can't
# affect the AI's search or leak the bonus onto the opponent's pieces.
func _add_square_dance_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var destinations: Array[String] = result.get("destinations", [])
    var file_index: int = _file_to_index(from_coord.substr(0, 1))
    var rank_index: int = int(from_coord.substr(1)) - 1
    var offsets: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
        Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
    ]
    for offset in offsets:
        var x: int = file_index + offset.x
        var y: int = rank_index + offset.y
        if x < 0 or x >= 8 or y < 0 or y >= 8:
            continue
        var coord: String = _index_to_coord(x, y)
        if coord in destinations or not state.has(coord):
            continue
        if _is_white_piece(state[coord]) != is_white:
            continue
        if _swap_leaves_king_in_check(from_coord, coord, is_white, state):
            continue
        destinations.append(coord)
    result["destinations"] = destinations

# Whether swapping the pieces at from_coord and to_coord would leave the
# mover's own king in check — unlike a normal move, both squares change
# occupant at once (neither is simply vacated), so it needs its own
# simulation rather than the generic single-square _move_leaves_king_in_check.
func _swap_leaves_king_in_check(from_coord: String, to_coord: String, is_white: bool, state: Dictionary) -> bool:
    var simulated: Dictionary = state.duplicate()
    var symbol_at_from: String = simulated.get(from_coord, "")
    var symbol_at_to: String = simulated.get(to_coord, "")
    simulated[from_coord] = symbol_at_to
    simulated[to_coord] = symbol_at_from

    var king_coord: String
    if symbol_at_from == "♔" or symbol_at_from == "♚":
        king_coord = to_coord
    elif symbol_at_to == "♔" or symbol_at_to == "♚":
        king_coord = from_coord
    else:
        king_coord = _find_king_coord(is_white, simulated)

    return _is_square_attacked(king_coord, not is_white, simulated)

# Overextend: if the two-square advance is already legal (so the path up to
# it is clear and safe), and the third square ahead is also empty and safe,
# add it as an extra destination/path square. Only reachable from
# _collect_legal_moves_for_piece (the human preview/selection entry point),
# never from the AI/attack-detection paths, so this can't affect the AI's
# search or leak the bonus onto the opponent's pawns.
func _add_overextend_destination(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var file_char: String = from_coord.substr(0, 1)
    var two_step_coord: String = _advance_coord(file_char, 2, 0, 2)
    var destinations: Array[String] = result.get("destinations", [])
    if two_step_coord == "" or not (two_step_coord in destinations):
        return
    var three_step_coord: String = _advance_coord(file_char, 2, 0, 3)
    if three_step_coord == "" or _piece_exists_at(three_step_coord, state):
        return
    if _move_leaves_king_in_check(from_coord, three_step_coord, is_white, state):
        return
    destinations.append(three_step_coord)
    var paths: Array[String] = result.get("paths", [])
    if not (two_step_coord in paths):
        paths.append(two_step_coord)
    result["destinations"] = destinations
    result["paths"] = paths

# Stride: whatever rank this pawn is currently on (not just its original
# rank — unlike Overextend, this is meant to restore the two-square advance
# to a pawn that already spent its one-time right), if the square directly
# ahead is empty and safe and the square beyond that is also empty and safe,
# add the two-square advance as an extra destination/path square. A pawn
# still on its original rank already has this move naturally, so this simply
# does nothing new for it. Only reachable from _collect_legal_moves_for_piece
# (the human preview/selection entry point), never from the AI/attack-
# detection paths, so this can't affect the AI's search or leak the bonus
# onto the opponent's pawns.
func _add_stride_destination(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var file_char: String = from_coord.substr(0, 1)
    var rank_number: int = int(from_coord.substr(1))
    var one_step_coord: String = _advance_coord(file_char, rank_number, 0, 1)
    var two_step_coord: String = _advance_coord(file_char, rank_number, 0, 2)
    if one_step_coord == "" or two_step_coord == "":
        return
    if _piece_exists_at(one_step_coord, state) or _piece_exists_at(two_step_coord, state):
        return
    var destinations: Array[String] = result.get("destinations", [])
    if two_step_coord in destinations:
        return
    if _move_leaves_king_in_check(from_coord, two_step_coord, is_white, state):
        return
    destinations.append(two_step_coord)
    var paths: Array[String] = result.get("paths", [])
    if not (one_step_coord in paths):
        paths.append(one_step_coord)
    result["destinations"] = destinations
    result["paths"] = paths

# Trample: a pawn normally can't move straight ahead onto an occupied square
# at all (friend or foe alike blocks it) — this adds the square directly
# ahead as a capturing destination if an enemy piece sits there, regardless
# of whether the pawn's ordinary diagonal captures are otherwise available.
# Only reachable from _collect_legal_moves_for_piece (the human preview/
# selection entry point), never from the AI/attack-detection paths, so this
# can't affect the AI's search or leak the bonus onto the opponent's pawns.
func _add_trample_destination(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var file_char: String = from_coord.substr(0, 1)
    var rank_number: int = int(from_coord.substr(1))
    var direction: int = 1 if is_white else -1
    var ahead_coord: String = _advance_coord(file_char, rank_number, 0, direction)
    if ahead_coord == "" or not _piece_exists_at(ahead_coord, state):
        return
    if _is_white_piece(_piece_symbol_at(ahead_coord, state)) == is_white:
        return
    if _is_king(_piece_symbol_at(ahead_coord, state)):
        return
    var destinations: Array[String] = result.get("destinations", [])
    if ahead_coord in destinations:
        return
    if _move_leaves_king_in_check(from_coord, ahead_coord, is_white, state):
        return
    destinations.append(ahead_coord)
    result["destinations"] = destinations

# Sidestep: adds the two squares directly beside this pawn (same rank, one
# file left or right) as destinations, if empty — pawns can never normally
# move sideways at all, so this is a dedicated lateral step, not a capture
# (a piece on either side, friend or foe, still blocks that side same as
# anything blocks a normal forward step). Only reachable from
# _collect_legal_moves_for_piece (the human preview/selection entry point),
# never from the AI/attack-detection paths, so this can't affect the AI's
# search or leak the bonus onto the opponent's pawns.
func _add_sidestep_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var file_char: String = from_coord.substr(0, 1)
    var rank_number: int = int(from_coord.substr(1))
    var destinations: Array[String] = result.get("destinations", [])
    for offset in [-1, 1]:
        var side_coord: String = _advance_coord(file_char, rank_number, offset, 0)
        if side_coord == "" or _piece_exists_at(side_coord, state) or side_coord in destinations:
            continue
        if _move_leaves_king_in_check(from_coord, side_coord, is_white, state):
            continue
        destinations.append(side_coord)
    result["destinations"] = destinations

# Strafe: adds the two diagonally-forward squares (the same two squares a
# capture would normally use) as destinations when they're empty — a pawn
# can otherwise only ever reach those squares by capturing, never step onto
# an empty one. Only reachable from _collect_legal_moves_for_piece (the
# human preview/selection entry point), never from the AI/attack-detection
# paths, so this can't affect the AI's search or leak the bonus onto the
# opponent's pawns.
func _add_strafe_destinations(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var file_char: String = from_coord.substr(0, 1)
    var rank_number: int = int(from_coord.substr(1))
    var direction: int = 1 if is_white else -1
    var destinations: Array[String] = result.get("destinations", [])
    for offset in [-1, 1]:
        var diag_coord: String = _advance_coord(file_char, rank_number, offset, direction)
        if diag_coord == "" or _piece_exists_at(diag_coord, state) or diag_coord in destinations:
            continue
        if _move_leaves_king_in_check(from_coord, diag_coord, is_white, state):
            continue
        destinations.append(diag_coord)
    result["destinations"] = destinations

# Battering Ram: for each capturing destination the Rook already has, look
# further past it along the same line for a second enemy piece with nothing
# but empty squares in between (a friendly piece, or the board edge, blocks
# the pierce same as it would block a normal slide). If one is there, add its
# square as an extra destination — the actual removal of the pierced-through
# piece happens in _move_piece, keyed off pending_battering_ram/moving_symbol
# rather than off this generated destination itself. Only reachable from
# _collect_legal_moves_for_piece (the human preview/selection entry point),
# never from the AI/attack-detection paths, so this can't affect the AI's
# search or leak the bonus onto the opponent's rooks.
func _add_battering_ram_destination(from_coord: String, state: Dictionary, is_white: bool, result: Dictionary) -> void:
    var destinations: Array[String] = result.get("destinations", [])
    var paths: Array[String] = result.get("paths", [])
    var extra_destinations: Array[String] = []
    var extra_paths: Array[String] = []

    for first_capture in destinations.duplicate():
        if not state.has(first_capture):
            continue  # a non-capturing destination has nothing to pierce through
        var dir: Vector2i = _rook_direction(from_coord, first_capture)
        if dir == Vector2i.ZERO:
            continue

        var x: int = _file_to_index(first_capture.substr(0, 1)) + dir.x
        var y: int = int(first_capture.substr(1)) - 1 + dir.y
        var between: Array[String] = []
        while x >= 0 and x < 8 and y >= 0 and y < 8:
            var coord: String = _index_to_coord(x, y)
            if state.has(coord):
                if _is_white_piece(state[coord]) != is_white and not _is_king(state[coord]):
                    var state_without_first_capture: Dictionary = state.duplicate()
                    state_without_first_capture.erase(first_capture)
                    if not _move_leaves_king_in_check(from_coord, coord, is_white, state_without_first_capture):
                        extra_destinations.append(coord)
                        extra_paths.append(first_capture)
                        extra_paths.append_array(between)
                break
            between.append(coord)
            x += dir.x
            y += dir.y

    for extra in extra_destinations:
        if not (extra in destinations):
            destinations.append(extra)
    for extra in extra_paths:
        if not (extra in paths):
            paths.append(extra)
    result["destinations"] = destinations
    result["paths"] = paths

# The unit step from from_coord to to_coord if they share a rank or file
# (i.e. a Rook could travel directly between them), otherwise Vector2i.ZERO.
func _rook_direction(from_coord: String, to_coord: String) -> Vector2i:
    var from_file: int = _file_to_index(from_coord.substr(0, 1))
    var from_rank: int = int(from_coord.substr(1))
    var to_file: int = _file_to_index(to_coord.substr(0, 1))
    var to_rank: int = int(to_coord.substr(1))
    if from_file == to_file and from_rank != to_rank:
        return Vector2i(0, 1 if to_rank > from_rank else -1)
    if from_rank == to_rank and from_file != to_file:
        return Vector2i(1 if to_file > from_file else -1, 0)
    return Vector2i.ZERO

# The square of the piece a Battering Ram Rook move pierces through en route
# from from_coord to to_coord, or "" if this move isn't one (no pending
# effect, the mover isn't a Rook, or there's simply nothing between the two
# squares — true for every ordinary Rook move). Used by _move_piece to remove
# that piece in addition to whatever sits on to_coord; based on board_state
# rather than the destinations _add_battering_ram_destination generated, so it
# also naturally covers the AI ever capturing with a Rook while this is
# pending (not currently possible — the effect is human-only — but this way
# the two can't drift out of sync if that ever changes).
func _resolve_battering_ram_pierce(from_coord: String, to_coord: String, moving_symbol: String) -> String:
    if not pending_battering_ram or moving_symbol != "♖":
        return ""
    var dir: Vector2i = _rook_direction(from_coord, to_coord)
    if dir == Vector2i.ZERO:
        return ""
    var to_file: int = _file_to_index(to_coord.substr(0, 1))
    var to_rank: int = int(to_coord.substr(1)) - 1
    var x: int = _file_to_index(from_coord.substr(0, 1)) + dir.x
    var y: int = int(from_coord.substr(1)) - 1 + dir.y
    while x != to_file or y != to_rank:
        var coord: String = _index_to_coord(x, y)
        if board_state.has(coord):
            return coord
        x += dir.x
        y += dir.y
    return ""

# Hot path used by get_all_legal_moves/_has_any_legal_move, which is called at
# every node of the AI's search tree. A piece that isn't the king, isn't on
# the same rank/file/diagonal as its own king, and whose king isn't currently
# in check literally cannot expose that king to check by moving — so its raw
# moves are trivially legal and we skip the expensive check-simulation below.
func _collect_legal_moves_for_piece_fast(symbol: String, from_coord: String, state: Dictionary, king_coord: String, king_in_check: bool, rights: Dictionary = {}, ep_target: String = "") -> Dictionary:
    var raw: Dictionary = _collect_moves_for_piece(symbol, from_coord, state)
    var raw_destinations: Array[String] = raw.get("destinations", [])
    var raw_paths: Array[String] = raw.get("paths", [])
    var is_white: bool = _is_white_piece(symbol)
    var is_king: bool = symbol == "♔" or symbol == "♚"
    var is_pawn: bool = symbol == "♙" or symbol == "♟"

    if is_king and not rights.is_empty():
        raw_destinations.append_array(_collect_castling_destinations(is_white, state, rights))

    # En passant removes a second piece — the captured pawn — from a square
    # other than the mover's own origin, so it can expose the king along a
    # line (e.g. the fifth rank) that the "shares a line with the king" fast
    # path below has no way to know about. It's always validated separately
    # with a check that accounts for both vacated squares, regardless of
    # which branch below is taken.
    var en_passant_destination: String = ""
    if is_pawn and ep_target != "":
        en_passant_destination = _collect_en_passant_destination(is_white, from_coord, state, ep_target)
        if en_passant_destination != "" and _en_passant_leaves_king_in_check(from_coord, en_passant_destination, is_white, king_coord, state):
            en_passant_destination = ""

    if not is_king and not king_in_check and not _shares_line_with_king(from_coord, king_coord):
        var destinations: Array[String] = raw_destinations
        if en_passant_destination != "":
            destinations = destinations.duplicate()
            destinations.append(en_passant_destination)
        return {"destinations": destinations, "paths": raw_paths}

    var legal_destinations: Array[String] = []
    var legal_lookup: Dictionary = {}
    for destination in raw_destinations:
        if not _move_leaves_king_in_check(from_coord, destination, is_white, state):
            legal_destinations.append(destination)
            legal_lookup[destination] = true

    if en_passant_destination != "":
        legal_destinations.append(en_passant_destination)
        legal_lookup[en_passant_destination] = true

    var legal_paths: Array[String] = []
    for path_coord in raw_paths:
        if legal_lookup.has(path_coord):
            legal_paths.append(path_coord)

    return {"destinations": legal_destinations, "paths": legal_paths}

# Returns the king's destination square(s) — "g1"/"c1" etc. — for whichever
# castles are currently legal: the right hasn't been revoked, the rook is
# still on its home square, the squares between are empty, and the king is
# not currently in check, does not pass through, and does not land on an
# attacked square.
func _collect_castling_destinations(is_white: bool, state: Dictionary, rights: Dictionary) -> Array[String]:
    var destinations: Array[String] = []
    var home_rank: int = 1 if is_white else 8
    var king_coord: String = "e%d" % home_rank
    var king_symbol: String = "♔" if is_white else "♚"
    var rook_symbol: String = "♖" if is_white else "♜"
    if state.get(king_coord, "") != king_symbol:
        return destinations

    var attacker_is_white: bool = not is_white

    var king_side_key: String = "white_king_side" if is_white else "black_king_side"
    if rights.get(king_side_key, false):
        var f_coord: String = "f%d" % home_rank
        var g_coord: String = "g%d" % home_rank
        var h_coord: String = "h%d" % home_rank
        if state.get(h_coord, "") == rook_symbol and not state.has(f_coord) and not state.has(g_coord):
            if not _is_square_attacked(king_coord, attacker_is_white, state) and not _is_square_attacked(f_coord, attacker_is_white, state) and not _is_square_attacked(g_coord, attacker_is_white, state):
                destinations.append(g_coord)

    var queen_side_key: String = "white_queen_side" if is_white else "black_queen_side"
    if rights.get(queen_side_key, false):
        var d_coord: String = "d%d" % home_rank
        var c_coord: String = "c%d" % home_rank
        var b_coord: String = "b%d" % home_rank
        var a_coord: String = "a%d" % home_rank
        if state.get(a_coord, "") == rook_symbol and not state.has(b_coord) and not state.has(c_coord) and not state.has(d_coord):
            if not _is_square_attacked(king_coord, attacker_is_white, state) and not _is_square_attacked(d_coord, attacker_is_white, state) and not _is_square_attacked(c_coord, attacker_is_white, state):
                destinations.append(c_coord)

    return destinations

# Returns the capturing pawn's destination square if an en passant capture
# from from_coord is currently available, or "" otherwise: the pawn must be
# on the rank adjacent to ep_target, on a file next to it, and the pawn it
# would capture must actually be sitting where the en passant target implies
# (defensive — ep_target should already guarantee this, but this keeps the
# function correct even if ep_target is ever stale relative to `state`).
func _collect_en_passant_destination(is_white: bool, from_coord: String, state: Dictionary, ep_target: String) -> String:
    var from_file: String = from_coord.substr(0, 1)
    var from_rank: int = int(from_coord.substr(1))
    var target_file: String = ep_target.substr(0, 1)
    var target_rank: int = int(ep_target.substr(1))

    var expected_from_rank: int = 5 if is_white else 4
    if from_rank != expected_from_rank:
        return ""
    if abs(_file_to_index(from_file) - _file_to_index(target_file)) != 1:
        return ""
    var expected_target_rank: int = from_rank + 1 if is_white else from_rank - 1
    if target_rank != expected_target_rank:
        return ""

    var captured_coord: String = "%s%d" % [target_file, from_rank]
    var expected_captured_symbol: String = "♟" if is_white else "♙"
    if state.get(captured_coord, "") != expected_captured_symbol:
        return ""

    return ep_target

# Whether capturing en passant from from_coord to to_coord would leave the
# mover's own king in check — unlike a normal move, this vacates two squares
# (the mover's origin AND the captured pawn's square, which sits beside it
# rather than at the destination), so it needs its own check rather than the
# generic single-square _move_leaves_king_in_check.
func _en_passant_leaves_king_in_check(from_coord: String, to_coord: String, is_white: bool, king_coord: String, state: Dictionary) -> bool:
    var simulated: Dictionary = state.duplicate()
    simulated[to_coord] = simulated.get(from_coord, "")
    simulated.erase(from_coord)
    simulated.erase(to_coord.substr(0, 1) + from_coord.substr(1))
    return _is_square_attacked(king_coord, not is_white, simulated)

func _shares_line_with_king(from_coord: String, king_coord: String) -> bool:
    if king_coord == "" or from_coord == king_coord:
        return false
    var king_file: int = _file_to_index(king_coord.substr(0, 1))
    var king_rank: int = int(king_coord.substr(1))
    var piece_file: int = _file_to_index(from_coord.substr(0, 1))
    var piece_rank: int = int(from_coord.substr(1))
    if king_file == piece_file or king_rank == piece_rank:
        return true
    return abs(king_file - piece_file) == abs(king_rank - piece_rank)

func _move_leaves_king_in_check(from_coord: String, to_coord: String, is_white: bool, state: Dictionary) -> bool:
    var simulated: Dictionary = state.duplicate()
    var moving_symbol: String = simulated.get(from_coord, "")
    simulated[to_coord] = moving_symbol
    simulated.erase(from_coord)

    var king_coord: String
    if moving_symbol == "♔" or moving_symbol == "♚":
        king_coord = to_coord
    else:
        king_coord = _find_king_coord(is_white, simulated)

    return _is_square_attacked(king_coord, not is_white, simulated)

func _find_king_coord(is_white: bool, state: Dictionary) -> String:
    var king_symbol: String = "♔" if is_white else "♚"
    for coord in state.keys():
        if state[coord] == king_symbol:
            return coord
    return ""

func _is_square_attacked(coord: String, by_white: bool, state: Dictionary) -> bool:
    if coord == "":
        return false
    for piece_coord in state.keys():
        var symbol: String = state[piece_coord]
        if _is_white_piece(symbol) != by_white:
            continue
        var moves: Dictionary = _collect_moves_for_piece(symbol, piece_coord, state)
        var destinations: Array[String] = moves.get("destinations", [])
        if coord in destinations:
            return true
    return false

func _collect_moves_for_piece(symbol: String, from_coord: String, state: Dictionary) -> Dictionary:
    var destinations: Array[String] = []
    var paths: Array[String] = []
    var file_index: int = _file_to_index(from_coord.substr(0, 1))
    var rank: int = int(from_coord.substr(1, 1))
    var file_char: String = from_coord.substr(0, 1)
    var rank_number: int = int(from_coord.substr(1))
    var is_white: bool = _is_white_piece(symbol)

    if symbol == "♙" or symbol == "♟":
        var direction: int = 1 if is_white else -1
        var double_step_rank: int = 2 if is_white else 7
        var one_step_coord: String = _advance_coord(file_char, rank_number, 0, direction)
        if one_step_coord != "" and not _piece_exists_at(one_step_coord, state):
            destinations.append(one_step_coord)
            if rank_number == double_step_rank:
                var two_step_coord: String = _advance_coord(file_char, rank_number, 0, direction * 2)
                if two_step_coord != "" and not _piece_exists_at(two_step_coord, state):
                    destinations.append(two_step_coord)
                    paths.append(one_step_coord)

        for offset in [-1, 1]:
            var capture_coord: String = _advance_coord(file_char, rank_number, offset, direction)
            if capture_coord != "" and _piece_exists_at(capture_coord, state) and _is_white_piece(_piece_symbol_at(capture_coord, state)) != is_white:
                destinations.append(capture_coord)
        return {"destinations": destinations, "paths": paths}

    var directions: Array[Vector2i] = []
    match symbol:
        "♖", "♜":
            directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
        "♗", "♝":
            directions = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
        "♕", "♛":
            directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
        "♔", "♚":
            directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
        "♘", "♞":
            directions = [Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1)]

    if symbol == "♔" or symbol == "♚" or symbol == "♘" or symbol == "♞":
        for offset in directions:
            var coord: String = _advance_coord(file_char, rank_number, offset.x, offset.y)
            if coord != "" and (not _piece_exists_at(coord, state) or _is_white_piece(_piece_symbol_at(coord, state)) != is_white):
                destinations.append(coord)
        return {"destinations": destinations, "paths": paths}

    for offset in directions:
        var x: int = file_index
        var y: int = rank - 1
        var reached: Array[String] = []

        while true:
            x += offset.x
            y += offset.y
            if x < 0 or x >= 8 or y < 0 or y >= 8:
                break
            var coord: String = _index_to_coord(x, y)
            if _piece_exists_at(coord, state):
                if _is_white_piece(_piece_symbol_at(coord, state)) != is_white:
                    reached.append(coord)
                break
            reached.append(coord)

        if reached.is_empty():
            continue

        for index in range(reached.size() - 1):
            paths.append(reached[index])
        for coord in reached:
            destinations.append(coord)

    return {"destinations": destinations, "paths": paths}

func _piece_exists_at(coord: String, state: Dictionary) -> bool:
    return state.has(coord)

func _piece_symbol_at(coord: String, state: Dictionary) -> String:
    return state.get(coord, "")

func _is_white_piece(symbol: String) -> bool:
    return ["♙", "♖", "♘", "♗", "♕", "♔"].has(symbol)

# Used by the card-granted "extra capture" bonuses (Trample, Battering Ram,
# Gallop, Leap of Faith) to refuse ever targeting a king. Those bonuses give
# a piece a capturing reach _is_square_attacked doesn't know about (it's
# built entirely on the plain, card-unaware _collect_moves_for_piece — see
# the comments on those _add_*_destinations functions), so a king standing
# in one of these expanded blast radii never registers as being in check —
# the AI won't defend it and the game won't call checkmate. Without this,
# that king would simply be capturable outright instead. This is the direct,
# narrow fix for that; see the card audit that found it for the fuller
# alternative (teaching check detection about these bonuses instead), not
# pursued here since it would touch code shared with the AI's search.
func _is_king(symbol: String) -> bool:
    return symbol == "♔" or symbol == "♚"

func _advance_coord(file_char: String, rank_number: int, file_offset: int, rank_offset: int) -> String:
    var file_index: int = _file_to_index(file_char)
    var new_file_index: int = file_index + file_offset
    var new_rank: int = rank_number + rank_offset
    if new_file_index < 0 or new_file_index >= FILES.size() or new_rank < 1 or new_rank > 8:
        return ""
    return "%s%d" % [FILES[new_file_index], new_rank]

func _index_to_coord(file_index: int, rank_index: int) -> String:
    if file_index < 0 or file_index >= FILES.size() or rank_index < 0 or rank_index >= 8:
        return ""
    return "%s%d" % [FILES[file_index], rank_index + 1]

func _file_to_index(file_name: String) -> int:
    for index in range(FILES.size()):
        if FILES[index] == file_name:
            return index
    return -1

func _is_dark_piece(symbol: String) -> bool:
    return ["♟", "♜", "♞", "♝", "♛", "♚"].has(symbol)
