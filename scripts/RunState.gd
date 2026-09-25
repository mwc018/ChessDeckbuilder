extends Node

# Autoload singleton — the only state that survives a change_scene_to_file
# call between Map.tscn, Match.tscn and Victory.tscn. They're separate
# top-level scenes (not nested inside each other), so anything that
# needs to outlive the swap — the run's accumulated deck, which match
# number this is, what the victory screen should offer, the map and where
# the player is on it — has to live somewhere none of them owns.

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

# The player's army: coord -> symbol for all 16 of their pieces, in the
# arrangement they last set up. Starts as the standard layout; fairy pieces
# replace standard ones in place (see upgrade_piece), and pre-match setup
# rearranges them among their class's squares.
var army_layout: Dictionary = {}

func _ready() -> void:
    reset_run()

# Everything back to a fresh run: starting deck and army, no map (Map
# generates a new one when it next loads).
func reset_run() -> void:
    deck_card_names = CardCatalog.STARTING_DECK_CARD_NAMES.duplicate()
    match_number = 1
    pending_reward_offer = []
    army_layout = PieceCatalog.STANDARD_WHITE_LAYOUT.duplicate()
    map_node_ring = []
    map_node_angle = []
    map_adjacency = []
    map_cleared = []
    map_current_node = -1
    map_pending_node = -1

func advance_to_new_match() -> void:
    match_number += 1

# The full starting position for the next match: the player's army plus a
# standard enemy side.
func build_match_layout() -> Dictionary:
    return army_layout.merged(PieceCatalog.STANDARD_BLACK_LAYOUT)

# Whether pre-match setup has anything to offer — with only standard pieces,
# every rearrangement is identical to the one you already have.
func army_has_fairy_pieces() -> bool:
    for symbol in army_layout.values():
        if PieceCatalog.is_fairy(symbol):
            return true
    return false

# Replaces the piece at coord with its direct upgrade (the shrine's
# "promote"). Returns false if that piece has no upgrade.
func upgrade_piece(coord: String) -> bool:
    var upgraded: String = PieceCatalog.upgrade_of(army_layout.get(coord, ""))
    if upgraded == "":
        return false
    army_layout[coord] = upgraded
    return true

# --- Map -------------------------------------------------------------------
#
# The run's map: a boss at the center (node 0), surrounded by concentric
# rings of nodes, each ring slightly bigger than the one inside it. Lives
# here rather than in Map.gd because the Map scene is torn down every time
# the player enters a match, and the layout/progress has to survive that.
#
# Nodes are stored as parallel arrays indexed by node id. Positions aren't
# stored in pixels — just (ring, angle) — so Map can lay them out to fit
# whatever the window size happens to be.

# Node counts per ring, innermost first. Ring 0 is the boss alone. Each
# ring must have exactly one more node than the ring inside it — the
# crossing-free link layout in generate_map() depends on it.
const MAP_RING_NODE_COUNTS: Array[int] = [5, 6, 7, 8, 9, 10, 11]

const BOSS_NODE: int = 0

var map_node_ring: Array[int] = []
var map_node_angle: Array[float] = []
# map_adjacency[id] = ids of every node connected to it (both directions).
var map_adjacency: Array = []
var map_cleared: Array[bool] = []
# Where the player currently stands.
var map_current_node: int = -1
# The node whose match is in progress — set when the player clicks an
# uncleared node on the map, consumed by complete_pending_node() on a win.
var map_pending_node: int = -1

func has_map() -> bool:
    return not map_node_ring.is_empty()

func generate_map() -> void:
    map_node_ring = [0]
    map_node_angle = [0.0]
    map_adjacency = [[]]
    map_cleared = [false]

    # ring_ids[r] = node ids in ring r, in increasing angle order.
    var ring_ids: Array = [[BOSS_NODE]]
    for ring_index in MAP_RING_NODE_COUNTS.size():
        var count: int = MAP_RING_NODE_COUNTS[ring_index]
        var inner: Array = ring_ids[ring_index]
        # The first ring can sit at any rotation. Every ring after that is
        # rotated so its first node sits directly outside a random node of
        # the ring inside it — see the inward-link comment below for why.
        var anchor: int = randi() % inner.size()
        var rotation: float = randf() * TAU if ring_index == 0 else map_node_angle[inner[anchor]]
        var ids: Array[int] = []
        for i in count:
            ids.append(map_node_ring.size())
            map_node_ring.append(ring_index + 1)
            map_node_angle.append(rotation + TAU * i / count)
            map_adjacency.append([])
            map_cleared.append(false)
        ring_ids.append(ids)

        # Neighbors along the ring.
        for i in count:
            _link(ids[i], ids[(i + 1) % count])

        # Links inward. The first ring just links to the boss.
        if ring_index == 0:
            for id in ids:
                _link(BOSS_NODE, id)
            continue

        # Every other ring: each node links to the two inner nodes it sits
        # between, except the first one, which sits directly outside the
        # anchor and links only to it. That one exception can't be avoided:
        # each ring has one more node than the ring inside it, and there's
        # no way for every node to have two inward links without some of
        # them crossing. Going around the ring, node k links to inner nodes
        # anchor+k-1 and anchor+k, so consecutive nodes always share an
        # inner node and the links fan out in order, never crossing.
        assert(count == inner.size() + 1, "Each map ring must have exactly one more node than the ring inside it.")
        _link(ids[0], inner[anchor])
        for k in range(1, count):
            _link(ids[k], inner[(anchor + k - 1) % inner.size()])
            _link(ids[k], inner[(anchor + k) % inner.size()])

    var outer_ring: Array = ring_ids[ring_ids.size() - 1]
    map_current_node = outer_ring[randi() % outer_ring.size()]
    map_pending_node = -1

func _link(a: int, b: int) -> void:
    if not (b in map_adjacency[a]):
        map_adjacency[a].append(b)
    if not (a in map_adjacency[b]):
        map_adjacency[b].append(a)

# Nodes the player can click right now. Until the node they're standing on
# has been beaten, that's the only one (this is how the run's very first
# match works — they start on an outer node that hasn't been fought yet).
# Once it's cleared, it's every node adjacent to it.
func reachable_map_nodes() -> Array:
    if map_current_node == -1:
        return []
    if not map_cleared[map_current_node]:
        return [map_current_node]
    return map_adjacency[map_current_node]

# Called on a win. A match started directly (e.g. running Match.tscn from
# the editor) has no pending node, so this does nothing then.
func complete_pending_node() -> void:
    if map_pending_node == -1:
        return
    map_cleared[map_pending_node] = true
    map_current_node = map_pending_node
    map_pending_node = -1
