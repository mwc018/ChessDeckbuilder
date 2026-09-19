# Cards

Reference for every card that currently exists. Card scenes live in
`scenes/cards/`; the name-to-scene registry and starting deck list live in
`scripts/Match.gd` (`CARD_SCENES` / `STARTING_DECK_CARD_NAMES`); the actual
rule effects live in `scripts/Board.gd` (`_apply_card_effect` and the
`pending_*` fields).

Energy refills to 3 and a fresh 5-card hand is drawn at the start of each of
the player's turns. The player gets one normal chess move ("action") per
turn by default; ACTION-type cards below are explicitly exempt from
spending it.

## Starting deck

One copy of each of the following (10 cards total):

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

**Not in the starting deck:** Square Dance, Strafe, Homecoming, Withdrawal,
Absolution, Return to Court, and Royal Recall — all fully working and
registered, just not dealt at game start. Strafe is just being held back
for now; the other six are the victory-screen reward pool (see below) —
that "find it later" mechanic now exists.

## Winning a match: the card draft

Winning (checkmate, or the "Win (Debug)" button in the corner of the match
screen while that's still around for testing) shows a victory screen
offering up to 3 cards drawn from `Match.REWARD_POOL_CARD_NAMES` — exactly
the six cards held back from the starting deck above. Cards already
drafted this run are excluded from future offers, so the pool only shrinks;
once it's empty, winning just starts the next match with no draft screen.
Clicking a card lets you Confirm (adds it to the run's deck,
`Match.run_deck_card_names`, and starts a new match) or Cancel (back to all
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

## Card effect lifetimes

- **Overextend / Stride / Square Dance / Trample / Sidestep / Strafe / Free
  Rein / Open Gate / Divine Exception / Homecoming / Withdrawal /
  Absolution / Return to Court / Royal Recall** — a "next move only" window:
  cleared the instant the player makes their very next move, whether or not
  that move actually used the bonus, and always cleared by End Turn if
  unused. (This includes the seven action-exempt "does not spend your
  action" cards — they're spent by the very next move, not just the next
  move of their matching piece type, so the exemption can't be chained
  across several moves in one turn.)
- **Battering Ram / Gallop / Leap of Faith** — wait specifically for their
  matching piece type (Rook, Knight, Bishop respectively) to move, however
  many other moves happen first within the same turn — but still never
  survive past End Turn if that piece never moved.

## Same-piece-type collisions

Homecoming/Withdrawal/Absolution/Return to Court/Royal Recall each fully
*replace* their piece's destinations (see
`_replace_with_home_square_destinations` in `Board.gd`) — "go home and
nowhere else," overriding whatever Battering Ram/Gallop/Leap of Faith would
otherwise have added for that same move. If a player somehow has both a
piece-type modifier and its matching "return home" card pending on the same
turn, the return-home card wins.
