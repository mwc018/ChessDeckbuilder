# Cards

Reference for every card that currently exists. Card scenes live in
`scenes/cards/`; the name-to-scene registry and starting deck/reward pool
lists live in the `CardCatalog` autoload (`scripts/CardCatalog.gd`); the
run's actual accumulated deck lives in the `RunState` autoload
(`scripts/RunState.gd`). Most cards' rule effects live in
`scripts/Board.gd` (`_apply_card_effect` and the `pending_*` fields) —
Clean Slate is the one exception, handled in `scripts/Match.gd` instead,
since its effect is about the hand rather than a chess move.

Energy refills to 3 and a fresh 5-card hand is drawn at the start of each of
the player's turns. The player gets one normal chess move ("action") per
turn by default; ACTION-type cards below are explicitly exempt from
spending it.

## Starting deck

One copy of each of the following (13 cards total):

- Overextend
- Battering Ram
- Stride
- Gallop
- Trample
- Sidestep
- Free Rein
- Open Gate
- Divine Exception
- Leap of Faith
- Clean Slate
- Drift
- Conscript

**Not in the starting deck:** Square Dance, Strafe, Homecoming, Withdrawal,
Absolution, Return to Court, Royal Recall, Pilgrimage, Coronation, Royal
Guard, and Sanctuary — all fully working and registered, just not dealt at
game start. Strafe is just being held back for now; the other ten are the
victory-screen reward pool (see below). Going forward, new piece-specific
bonus cards default to the reward pool rather than the starting deck, to
keep the starting deck from growing indefinitely as more cards get built
(see `CARD_IDEAS.md` and the "starting card pool size" discussion) —
Pilgrimage was the first card built under that approach.

## Winning a match: the card draft

Winning (checkmate, or the "Win (Debug)" button in the corner of the match
screen while that's still around for testing) shows a victory screen
offering up to 3 cards drawn from `CardCatalog.REWARD_POOL_CARD_NAMES` —
the cards held back from the starting deck above. Cards already
drafted this run are excluded from future offers, so the pool only shrinks;
once it's empty, winning just starts the next match with no draft screen.
Clicking a card lets you Confirm (adds it to the run's deck,
`RunState.deck_card_names`, and starts a new match) or Cancel (back to all
3 choices); Skip starts a new match with the deck unchanged. The drafted
deck persists for the rest of the run — every match after a draft is dealt
from the updated list, not the original starting deck.

## All cards

| Card | Cost | Type | Description | Flavor Text |
|---|---|---|---|---|
| Overextend | 1 | Modifier | The next pawn to move from its original square this turn may advance up to 3 squares instead of 2. | "Discipline is the first casualty of ambition." |
| Battering Ram | 2 | Modifier | The next Rook to move that captures a piece continues through it and also captures the next piece in its path. | "Walls do not stop at the first thing they break." |
| Stride | 1 | Modifier | The next pawn to move may advance 2 squares even if it has already moved earlier this game. | "A soldier who has marched once can march again." |
| Square Dance | 1 | Action | The next piece to move may instead swap places with an adjacent friendly piece. | "Take your partner, promenade — nobody said the line had to hold still." |
| Gallop | 1 | Modifier | The next Knight to move may instead leap 1 square in one direction and 3 in the other. | "Give the horse its head, and it will carry you further than you asked." |
| Trample | 1 | Modifier | The next Pawn to move may capture the piece directly ahead of it. | "What stands in the way stands in the way no longer." |
| Sidestep | 1 | Action | The next pawn to move may instead step one square to the left or right. | "Forward isn't the only way to avoid a fight." |
| Free Rein | 2 | Action | The next Knight to move does not spend your one action for the turn. | "No one tells it when to move." |
| Open Gate | 2 | Action | The next Rook to move does not spend your one action for the turn. | "The walls can't hold what doesn't want to be held." |
| Divine Exception | 2 | Action | The next Bishop to move does not spend your one action for the turn. | "Even doctrine bends for the chosen." |
| Leap of Faith | 1 | Modifier | The next Bishop to move may jump over the first piece in its path and keep sliding. | "Doubt is just faith that hasn't jumped yet." |
| Strafe | 1 | Modifier | The next pawn to move may instead step diagonally forward one square onto an empty square. | "Not every advance marches straight ahead." |
| Homecoming | 1 | Action | The next Knight to move may only return to its starting square, without spending your one action for the turn. | "Every road it takes still leads back here." |
| Withdrawal | 1 | Action | The next Rook to move may only return to its starting square, without spending your one action for the turn. | "Some battles end where they began." |
| Absolution | 1 | Action | The next Bishop to move may only return to its starting square, without spending your one action for the turn. | "It came back to where it was forgiven." |
| Return to Court | 1 | Action | The next Queen to move may only return to its starting square, without spending your one action for the turn. | "Even the boldest queen answers the call home." |
| Royal Recall | 1 | Action | The next King to move may only return to its starting square, without spending your one action for the turn. | "The crown is safest where it began." |
| Clean Slate | 1 | Action | Discard the rest of your hand, then draw that many cards. | "Burn the hand. Deal a new one." |
| Drift | 1 | Modifier | The next Rook to move may end its move with one extra diagonal step. | "Not every line stays straight to the end." |
| Conscript | 1 | Action | The next pawn to move does not spend your one action for the turn. | "No one asked if he was ready to fight." |
| Pilgrimage | 1 | Modifier | The next Bishop to move may end its move with one extra orthogonal step. | "Even the faithful sometimes step off the path." |
| Coronation | 2 | Action | The next Queen to move does not spend your one action for the turn. | "The crown does not ask permission to move." |
| Royal Guard | 2 | Action | The next King to move does not spend your one action for the turn. | "Even kings need not walk alone." |
| Sanctuary | 1 | Action | The next Bishop to move may instead swap places with your King, without spending your one action for the turn. | "Even a king may take shelter in faith." |

## Card effect lifetimes

- **Overextend / Stride / Square Dance / Trample / Sidestep / Strafe / Free
  Rein / Open Gate / Divine Exception / Homecoming / Withdrawal /
  Absolution / Return to Court / Royal Recall / Conscript / Coronation /
  Royal Guard / Sanctuary** — a "next move only" window: cleared the instant
  the player makes their very next move, whether or not that move actually
  used the bonus, and always cleared by End Turn if unused. (This includes
  the eleven action-exempt "does not spend your action" cards — they're
  spent by the very next move, not just the next move of their matching
  piece type, so the exemption can't be chained across several moves in one
  turn. Sanctuary is only usable by a Bishop, but like every other
  ACTION-type card its window still isn't held open waiting specifically
  for one — playing it and then moving some other piece wastes it, same as
  Square Dance.)
- **Battering Ram / Drift / Gallop / Leap of Faith / Pilgrimage** — wait
  specifically for their matching piece type (Battering Ram and Drift both
  wait for a Rook, Gallop a Knight, Leap of Faith and Pilgrimage both a
  Bishop) to move, however many other moves happen first within the same
  turn — but still never survive past End Turn if that piece never moved.
- **Clean Slate** — not a "next move" window at all; it resolves the
  instant it's played (discard the rest of hand, draw that many back),
  with no pending_* flag and no interaction with piece movement.

## Same-piece-type collisions

Homecoming/Withdrawal/Absolution/Return to Court/Royal Recall each fully
*replace* their piece's destinations (see
`_replace_with_home_square_destinations` in `Board.gd`) — "go home and
nowhere else," overriding whatever Battering Ram/Gallop/Leap of Faith would
otherwise have added for that same move. If a player somehow has both a
piece-type modifier and its matching "return home" card pending on the same
turn, the return-home card wins. Sanctuary is the same kind of "replace"
card for the Bishop specifically; if both Absolution and Sanctuary are
pending on the same Bishop move, Sanctuary wins (its hook runs after
Absolution's in `_collect_legal_moves_for_piece`).

Sanctuary itself needed no new move-execution code at all — it reuses
Square Dance's swap machinery outright. `_move_piece`'s swap branch
triggers on *any* friendly-occupied destination regardless of which card
added it, and the action-exemption filter's swap check works the same way,
so a Bishop swapping with its King (however far away) is already handled
by logic that already existed for Square Dance.
