extends Node

# Autoload singleton — the one place that maps a card's name to its scene.
# Moved out of Match.gd so both Match and Victory (now separate scenes,
# swapped via change_scene_to_file rather than one being a child of the
# other) can reach it without holding a reference to each other. Every card
# that exists gets an entry here, whether or not it's in the starting deck
# below — whoever's instancing a card by name (Match's hand, Victory's
# reward picks) needs the scene for any name Board might ever hand back.
# Board only ever deals in names (see draw_pile/discard_pile there); it has
# no idea these scenes exist.
const CARD_SCENES: Dictionary = {
    "Overextend": preload("res://scenes/cards/Overextend.tscn"),
    "Battering Ram": preload("res://scenes/cards/BatteringRam.tscn"),
    "Stride": preload("res://scenes/cards/Stride.tscn"),
    "Square Dance": preload("res://scenes/cards/SquareDance.tscn"),
    "Gallop": preload("res://scenes/cards/Gallop.tscn"),
    "Trample": preload("res://scenes/cards/Trample.tscn"),
    "Sidestep": preload("res://scenes/cards/Sidestep.tscn"),
    "Free Rein": preload("res://scenes/cards/FreeRein.tscn"),
    "Open Gate": preload("res://scenes/cards/OpenGate.tscn"),
    "Divine Exception": preload("res://scenes/cards/DivineException.tscn"),
    "Leap of Faith": preload("res://scenes/cards/LeapOfFaith.tscn"),
    "Strafe": preload("res://scenes/cards/Strafe.tscn"),
    "Homecoming": preload("res://scenes/cards/Homecoming.tscn"),
    "Withdrawal": preload("res://scenes/cards/Withdrawal.tscn"),
    "Absolution": preload("res://scenes/cards/Absolution.tscn"),
    "Return to Court": preload("res://scenes/cards/ReturnToCourt.tscn"),
    "Royal Recall": preload("res://scenes/cards/RoyalRecall.tscn"),
}

# The singleton starting deck — one copy of each card a run begins with.
# Square Dance is deliberately left out: it's a card found later in a run
# rather than something every game starts with. The five "return to
# starting square" cards (Homecoming/Withdrawal/Absolution/Return to Court/
# Royal Recall) are left out too, and so is Strafe — they stay registered
# in CARD_SCENES above and fully working, just not part of the starting
# deck.
const STARTING_DECK_CARD_NAMES: Array[String] = [
    "Overextend", "Battering Ram", "Stride", "Gallop", "Trample", "Sidestep", "Free Rein", "Open Gate", "Divine Exception", "Leap of Faith",
]

# The pool the victory screen's 3-card draft draws from — exactly the cards
# left out of the starting deck above (except Strafe, which isn't part of
# the "find it later" story, it's just being held back from the opening
# hand entirely for now). Winning is how a run actually acquires these.
const REWARD_POOL_CARD_NAMES: Array[String] = [
    "Square Dance", "Homecoming", "Withdrawal", "Absolution",
    "Return to Court", "Royal Recall",
]
