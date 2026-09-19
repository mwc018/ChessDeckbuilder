extends Node

# Autoload singleton — the only state that survives a change_scene_to_file
# call between Match.tscn and Victory.tscn. Match and Victory are separate
# top-level scenes now (not one nested inside the other), so anything that
# needs to outlive the swap — the run's accumulated deck, which match
# number this is, what the victory screen should offer — has to live
# somewhere neither scene owns.

# The current run's actual deck. Starts as a copy of CardCatalog.
# STARTING_DECK_CARD_NAMES (see _ready()) and grows every time the player
# drafts a card from the victory screen. Every match — including the very
# first — is dealt from this, not the constant directly.
var deck_card_names: Array[String] = []

# Just a display counter for "Match N — AI difficulty M%"; doesn't affect
# anything else.
var match_number: int = 1

# Set by Match right before switching to Victory.tscn, with the (already
# shuffled, already trimmed to at most 3) card names to offer. Read once by
# Victory in its own _ready() and cleared immediately after, so a stale
# offer can never leak into some later run.
var pending_reward_offer: Array[String] = []

func _ready() -> void:
    deck_card_names = CardCatalog.STARTING_DECK_CARD_NAMES.duplicate()

func advance_to_new_match() -> void:
    match_number += 1
