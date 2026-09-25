extends RefCounted
class_name ChessAI

## A minimax/negamax search with alpha-beta pruning, evaluated purely against
## the state Dictionary format used by Board.gd (coord -> piece symbol). It
## never touches the scene tree, so it can search hypothetical future
## positions cheaply.
##
## "difficulty" is a single 0.0 (weakest) .. 1.0 (strongest) knob, the same
## way chess.com/Stockfish fake weaker play: a shallower search, a chance to
## play a random legal move instead of the best one ("blunder chance"), and
## noise added to the evaluation so close positions get misjudged.

const NO_MOVES_SCORE: float = 100000.0

var rng := RandomNumberGenerator.new()

func _init() -> void:
    rng.randomize()

# Returns {"from": coord, "to": coord}, or {} if there is no legal move at all.
# castle_rights/en_passant_target, if given, are only applied to this root
# move choice — deeper search plies (_search below) don't thread them
# further, so the AI can castle or capture en passant as its immediate move
# but won't plan multi-ply lines around either happening again later.
func choose_move(board: Node, state: Dictionary, is_white: bool, difficulty: float, castle_rights: Dictionary = {}, en_passant_target: String = "") -> Dictionary:
    difficulty = clampf(difficulty, 0.0, 1.0)
    var legal_moves: Array = board.get_all_legal_moves(is_white, state, castle_rights, en_passant_target)
    if legal_moves.is_empty():
        return {}

    var depth: int = 1 + int(round(difficulty * 2.0))  # 1..3 plies of lookahead beyond this move
    var blunder_chance: float = lerpf(0.35, 0.0, difficulty)
    var eval_noise: float = lerpf(150.0, 0.0, difficulty)

    if rng.randf() < blunder_chance:
        return legal_moves[rng.randi_range(0, legal_moves.size() - 1)]

    legal_moves = _order_moves(legal_moves, state)
    var best_score: float = -INF
    var best_moves: Array = []
    for move in legal_moves:
        var next_state: Dictionary = board.simulate_move(state, move.get("from"), move.get("to"))
        var score: float = -_search(board, next_state, not is_white, depth - 1, -INF, INF, eval_noise)
        if score > best_score + 0.01:
            best_score = score
            best_moves = [move]
        elif score > best_score - 0.01:
            best_moves.append(move)

    return best_moves[rng.randi_range(0, best_moves.size() - 1)]

# Negamax: returns a score from the perspective of the side about to move in `state`.
func _search(board: Node, state: Dictionary, is_white: bool, depth: int, alpha: float, beta: float, eval_noise: float) -> float:
    if depth <= 0:
        # At a leaf we only need to know whether a legal move exists, not the
        # full list — has_any_legal_move short-circuits on the first one found,
        # which is far cheaper than enumerating every piece's full move list.
        if not board.has_any_legal_move(is_white, state):
            return -NO_MOVES_SCORE
        return _evaluate(state, is_white, eval_noise)

    var legal_moves: Array = board.get_all_legal_moves(is_white, state)
    if legal_moves.is_empty():
        # No draws in this project: no legal move means the side to move has lost.
        return -NO_MOVES_SCORE

    legal_moves = _order_moves(legal_moves, state)
    var best_score: float = -INF
    for move in legal_moves:
        var next_state: Dictionary = board.simulate_move(state, move.get("from"), move.get("to"))
        var score: float = -_search(board, next_state, not is_white, depth - 1, -beta, -alpha, eval_noise)
        if score > best_score:
            best_score = score
        if best_score > alpha:
            alpha = best_score
        if alpha >= beta:
            break  # opponent already has a better alternative; prune

    return best_score

# Trying captures first gives alpha-beta a strong early bound, which is where
# nearly all of its pruning power comes from without a fuller move-ordering scheme.
func _order_moves(moves: Array, state: Dictionary) -> Array:
    var captures: Array = []
    var quiets: Array = []
    for move in moves:
        if state.has(move.get("to")):
            captures.append(move)
        else:
            quiets.append(move)
    captures.append_array(quiets)
    return captures

func _evaluate(state: Dictionary, perspective_is_white: bool, eval_noise: float) -> float:
    var material: float = 0.0
    for coord in state.keys():
        var symbol: String = state[coord]
        var value: float = PieceCatalog.value(symbol)
        material += value if PieceCatalog.is_white(symbol) else -value

    if eval_noise > 0.0:
        material += rng.randf_range(-eval_noise, eval_noise)

    return material if perspective_is_white else -material
