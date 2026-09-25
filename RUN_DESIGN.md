# Run Design

The agreed design for the run layer: the map, node types, the player's army,
corruption, and the economy. Status markers: **Built**, **Partial**, or
**Planned**. See `CARDS.md` for cards themselves.

The core tension: exploring the map makes you stronger (shops, elites,
shrines, events), but every move spreads corruption, which makes the path to
the boss harder. The player should be pushed to explore *some*, not all.

## Map — Built

- A full-screen chessboard background with the boss at the center.
- 7 rings of nodes around the boss, 5 nodes in the innermost ring and one
  more per ring outward (5, 6, 7, 8, 9, 10, 11). Each ring must have exactly
  one more node than the ring inside it — the link layout depends on it.
- Links: every node links to its neighbors along its ring. The inner ring
  links to the boss. Every other node links to the two nodes on the next
  ring in that it sits between, except one node per ring, which sits
  directly outside an inner node and links only to it. (Two inward links for
  every node is impossible without links crossing.) Links never cross.
- The player starts on a random outer-ring node and can move to any
  adjacent node. Moving onto an uncleared node starts its encounter; moving
  onto a cleared, uncorrupted node is free.
- The map is generated once per run and stored in `RunState`.

## Run flow

- Win a match → victory screen (card draft) → back to the map. **Built**
- Lose any match → the run ends. **Built**
- Beat the boss → **Planned** (undecided).

## Army and fairy pieces — Partial

- The player has a persistent army of 16 pieces. Each fairy piece
  *replaces* one class of standard piece (e.g. an Archbishop replaces a
  Bishop, a Squire would replace a Pawn).
- Before each match, the player can rearrange their pieces, but only among
  their own class's starting squares — a Squire can go on any pawn square,
  an Archbishop on either bishop square. The king never moves.
- Every standard piece has one direct **upgrade** (e.g. Bishop →
  Archbishop), used by the shrine's "promote".
- **Transform** replaces a piece with a random *other* piece that can fill
  the same class (e.g. a Pawn becomes a Squire or a Diplomat at random).
- Fairy pieces count as their class for cards: an Archbishop is a Bishop as
  far as Leap of Faith, Divine Exception, etc. are concerned.
- Built so far: **Archbishop** (replaces Bishop; moves like a bishop, plus
  one square orthogonally). It is the Bishop's upgrade.

## Node types — Planned

Placed by percentage weight: normal match 50%, event 20%, elite 12%,
shrine 10%, shop 8%.

- The starting node is always a normal match.
- No elites on the outer ring.
- Shops, shrines, events, and elites may not be adjacent to each other.
- A used node cannot be used again unless it becomes corrupted.

**Normal match.** Each match gets a slightly harder AI than the last and
about one more enemy fairy piece.

**Elite.** A spike in difficulty: a much stronger AI and more enemy fairy
pieces. Rewards: better card-draft odds, a choice of 1 of 3 pieces, and
more gold.

**Shop.** Sells cards and pieces, and removes a card from your deck.

**Event.** A choice, e.g. transform a piece or transform a card.

**Shrine.** Choose between removing negative corruption effects or
promoting a piece (its direct upgrade).

## Corruption — Planned

- Starts at the boss. After each of the player's moves on the map
  (including moving onto an already-visited node), it spreads to 2 random
  uncorrupted nodes adjacent to corrupted ones.
- It never spreads onto the node the player is standing on.
- Corruption can reach cleared nodes, which reactivates them.
- In a corrupted match, some enemy pieces are corrupted: 3 in a normal
  match, 5 in an elite. Hovering a corrupted piece shows what happens if
  you capture it.
- Capture penalties (starter list, to be tuned):
  - Normal: lose 1 energy next turn; a random card in hand is discarded;
    the capturing piece is stunned for a turn.
  - Elite, which can also persist beyond the match: a curse card added to
    your deck; one of your pieces becomes corrupted (e.g. can't be moved
    by cards); lose gold.
- A corrupted shop is undecided: possibly a battle with the shopkeeper to
  get in, higher prices, or lower-rarity stock.

## Economy — Planned

- Gold: 15–25 per normal win, 35–50 per elite win.
- Shop prices: common card 50, uncommon 75, rare 120; pieces 100–150;
  card removal 75, going up with each use.
- Card rarity: common, uncommon, rare. Every current card is common. When a
  rarity with no cards is rolled, fall back to common.

## Build order

1. Loss ends the run. Army in `RunState`, pre-match setup, Board setting up
   from the army. Archbishop. **Done**
2. More fairy pieces, and enemy fairy pieces.
3. Gold, rarity, and rarity-weighted card drafts.
4. Node types with weighted, non-adjacent placement; then elite, shop,
   shrine, and event.
5. Corruption spreading on the map, then corrupted pieces with hover
   explanations and capture penalties.
