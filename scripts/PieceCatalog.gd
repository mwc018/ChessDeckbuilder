extends RefCounted
class_name PieceCatalog

# Everything the game knows about each kind of piece: color, class, value,
# and — for fairy pieces — how it moves and how it's drawn. Pieces are still
# identified everywhere by a symbol string (board_state maps coord ->
# symbol); standard pieces use their Unicode glyph, and fairy pieces use
# their class's glyph plus a letter (the Archbishop is "♗A"/"♝A"), since
# Unicode has no glyphs of its own for them.
#
# All static, no scene tree access — ChessAI calls into Board's rules
# (which call into this) from a background thread.

const WHITE_STANDARD: Array[String] = ["♙", "♘", "♗", "♖", "♕", "♔"]
const BLACK_STANDARD: Array[String] = ["♟", "♞", "♝", "♜", "♛", "♚"]

const STANDARD_VALUES := {
    "♙": 100, "♟": 100,
    "♘": 320, "♞": 320,
    "♗": 330, "♝": 330,
    "♖": 500, "♜": 500,
    "♕": 900, "♛": 900,
    "♔": 0, "♚": 0,
}

const ORTHOGONAL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# Fairy pieces, keyed by their white symbol. Each entry:
#   name        shown in the hover tooltip
#   class       the white standard glyph of the piece it replaces
#   badge       letter drawn on the class glyph to tell it apart
#   value       material value for the AI
#   slides      directions it slides any distance in (like a bishop/rook)
#   steps       offsets it moves to in one jump (like a king/knight)
#   description one line for the hover tooltip
const FAIRY := {
    "♗A": {
        "name": "Archbishop",
        "class": "♗",
        "badge": "A",
        "value": 450,
        "slides": DIAGONAL,
        "steps": ORTHOGONAL,
        "description": "Moves like a bishop, or one square orthogonally.",
    },
}

# Each standard piece's direct upgrade (the shrine's "promote"), keyed by
# white symbol. Classes with no fairy piece yet are simply missing.
const UPGRADES := {
    "♗": "♗A",
}

# The white half of a standard starting position — the army every run
# begins with.
const STANDARD_WHITE_LAYOUT := {
    "a2": "♙", "b2": "♙", "c2": "♙", "d2": "♙",
    "e2": "♙", "f2": "♙", "g2": "♙", "h2": "♙",
    "a1": "♖", "b1": "♘", "c1": "♗", "d1": "♕",
    "e1": "♔", "f1": "♗", "g1": "♘", "h1": "♖",
}

const STANDARD_BLACK_LAYOUT := {
    "a7": "♟", "b7": "♟", "c7": "♟", "d7": "♟",
    "e7": "♟", "f7": "♟", "g7": "♟", "h7": "♟",
    "a8": "♜", "b8": "♞", "c8": "♝", "d8": "♛",
    "e8": "♚", "f8": "♝", "g8": "♞", "h8": "♜",
}

static func is_fairy(symbol: String) -> bool:
    return symbol.length() > 1

static func is_white(symbol: String) -> bool:
    return WHITE_STANDARD.has(symbol.left(1))

static func is_black(symbol: String) -> bool:
    return BLACK_STANDARD.has(symbol.left(1))

# The standard glyph of this piece's class, in its own color: "♗A" -> "♗",
# "♝A" -> "♝", "♘" -> "♘". This is what card effects check against, so
# fairy pieces count as their class for cards.
static func class_symbol(symbol: String) -> String:
    return symbol.left(1)

# The same piece in the other color: "♗A" <-> "♝A", "♘" <-> "♞".
static func to_color(symbol: String, white: bool) -> String:
    var glyph: String = symbol.left(1)
    var index: int = WHITE_STANDARD.find(glyph)
    if index == -1:
        index = BLACK_STANDARD.find(glyph)
    if index == -1:
        return symbol
    var colored: String = WHITE_STANDARD[index] if white else BLACK_STANDARD[index]
    return colored + symbol.substr(1)

static func _fairy_entry(symbol: String) -> Dictionary:
    return FAIRY.get(to_color(symbol, true), {})

static func value(symbol: String) -> int:
    if is_fairy(symbol):
        return _fairy_entry(symbol).get("value", 0)
    return STANDARD_VALUES.get(symbol, 0)

static func display_glyph(symbol: String) -> String:
    return symbol.left(1)

static func badge(symbol: String) -> String:
    return _fairy_entry(symbol).get("badge", "") if is_fairy(symbol) else ""

static func display_name(symbol: String) -> String:
    return _fairy_entry(symbol).get("name", "") if is_fairy(symbol) else ""

static func description(symbol: String) -> String:
    return _fairy_entry(symbol).get("description", "") if is_fairy(symbol) else ""

static func slides(symbol: String) -> Array:
    return _fairy_entry(symbol).get("slides", [])

static func steps(symbol: String) -> Array:
    return _fairy_entry(symbol).get("steps", [])

# The upgraded version of this piece in its own color, or "" if it has none.
static func upgrade_of(symbol: String) -> String:
    var upgraded: String = UPGRADES.get(to_color(symbol, true), "")
    return "" if upgraded == "" else to_color(upgraded, is_white(symbol))
