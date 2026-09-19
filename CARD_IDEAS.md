# Card Ideas

Brainstorm only — nothing here is built. See `CARDS.md` for the cards that
actually exist. Each idea notes a suggested **Type** (Action/Modifier),
**Cost**, and a rough **Build** difficulty against the current engine:

- **Easy** — fits an existing pattern (`_add_*_destinations`, the
  no-action-cost exemption, or the "replace with home square" template) and
  can mostly copy-paste from a card that already works that way.
- **Medium** — a new destination-generation shape, but still just adds/
  replaces legal destinations like everything that exists today.
- **Hard** — touches something the engine doesn't currently model (check
  detection ignoring a specific attacker, defended-piece logic, multi-step
  compound moves) and would need real design work first, not just a new
  `_add_*_destinations` function.

Two templates recur throughout — worth knowing before reading piece by
piece:
- **No-action-cost** (Free Rein / Open Gate / Divine Exception): an
  ACTION-type card that lets a piece's *normal* move happen without
  spending the turn's one action. Missing for Pawn, Queen, King.
- **Return home** (Homecoming / Withdrawal / Absolution / Return to Court /
  Royal Recall): an ACTION-type card that replaces a piece's destinations
  with its own starting square. Already exists for every piece except Pawn
  (pawns don't have a single starting square, so this template doesn't
  really map onto them).

---

## Pawn

**Already have:** Overextend, Stride, Trample, Sidestep, Strafe, Conscript
(Modifier x3, Action x3) — the richest set of any piece already.

- ~~**Conscript**~~ — *Action, 1 cost, Easy.* Built. The next pawn to move
  does not spend your one action for the turn.
- **Follow Through** — *Modifier, 1 cost, Easy.* After the next pawn's
  diagonal capture, it may continue one more square in the same diagonal
  direction (landing empty, or capturing a second piece there) — a diagonal
  cousin of Battering Ram.
- **Reinforced Line** — *Modifier, 1 cost, Medium.* The next pawn to move
  may instead stay in place and grant an adjacent friendly pawn immunity
  from capture until your next turn.

## Knight

**Already have:** Gallop (Modifier), Free Rein, Homecoming (Action x2).

- **Double Dutch** — *Modifier, 2 cost, Medium.* If the next Knight's move
  doesn't capture, it may immediately follow with a second Knight leap from
  its landing square.
- **Flank** — *Action, 1 cost, Easy.* The next Knight to move may swap
  places with a friendly piece up to two squares away in a straight line
  (rank, file, or diagonal), without spending your action — a longer-range
  Square Dance restricted to Knights.
- **Ambush** — *Modifier, 1 cost, Hard.* The next Knight's move may land on
  a square adjacent to the enemy king without that move being flagged as
  putting your own king in danger from a counter-attack it otherwise would
  be (i.e. a controlled exception to normal check-safety filtering) — more
  of a "feels powerful" idea than a concretely scoped one; would need real
  design work to define exactly what it overrides.

## Bishop

**Already have:** Leap of Faith, Pilgrimage (Modifier x2), Divine Exception,
Absolution, Sanctuary (Action x3).

- ~~**Pilgrimage**~~ — *Modifier, 1 cost, Easy.* Built. The next Bishop's
  move may end with one extra orthogonal step (forward, back, or sideways)
  — the diagonal-piece mirror of Drift.
- ~~**Sanctuary**~~ — *Action, 1 cost, Easy.* Built. The next Bishop to move
  may swap places with your King instead of moving normally, without
  spending your action — an emergency escape valve for the king, framed as
  the bishop "giving sanctuary." Turned out to need zero new move-execution
  code — it reuses Square Dance's swap machinery outright.
- **Second Sight** — *Modifier, 1 cost, Medium.* The next Bishop to move
  may choose either diagonal color-complex for this move only — effectively
  letting it "see" one square off its normal color before continuing, by
  taking a single orthogonal step at the *start* of its move instead of the
  end (contrast with Pilgrimage, which adds the step at the end).

## Rook

**Already have:** Battering Ram, Drift (Modifier x2), Open Gate, Withdrawal
(Action x2) — already well covered.

- **Fortify** — *Modifier, 1 cost, Medium.* The next Rook to move may
  instead not move at all and grant an adjacent friendly piece immunity
  from capture until your next turn (same "immunity" idea as Reinforced
  Line, framed as the rook's own defensive specialty).
- **Flying Buttress** — *Action, 2 cost, Easy.* The next Rook to move may
  swap places with a friendly piece anywhere along its current rank or
  file, without spending your action — a long-range Square Dance
  restricted to Rooks.

## Queen

**Already have:** Return to Court, Coronation (Action x2).

- ~~**Coronation**~~ — *Action, 2 cost, Easy.* Built (at 2 cost instead of
  the 1 suggested here). The next Queen to move does not spend your one
  action for the turn. Fills the no-action-cost template.
- **Royal Decree** — *Modifier, 1 cost, Easy.* The next Queen's move may end
  with one extra single-square step in any direction — an omnidirectional
  Drift, fitting since the Queen already moves like a Rook and Bishop
  combined.
- **Regicide** — *Modifier, 2 cost, Medium.* If the next Queen's move
  captures a piece, she may continue in the same direction to capture a
  second piece beyond it — Battering Ram's trick, but usable along any of
  the Queen's 8 directions instead of just rook lines.
- **Abdication** — *Action, 2 cost, Easy.* The next Queen to move may swap
  places with any friendly piece anywhere on the board, without spending
  your action — the biggest-range version of the swap idea, benchmarked
  against Flank/Flying Buttress above.
- **Sovereign's Gaze** — *Modifier, 1 cost, Medium.* The next Queen to move
  may jump over the first piece blocking her path once and keep going, in
  any of her 8 directions — Leap of Faith's trick generalized from Bishop
  to Queen.

## King

**Already have:** Royal Recall, Royal Guard (Action x2). Ideas here lean
protective/tactical rather than purely aggressive, since the King is
uniquely precious and already tightly constrained by check rules.

- ~~**Royal Guard**~~ — *Action, 2 cost, Easy.* Built (at 2 cost instead of
  the 1 suggested here). The next King to move does not spend your one
  action for the turn. Fills the no-action-cost template.
- **Second Wind** — *Modifier, 1 cost, Medium.* The next King to move may
  move 2 squares in a straight line instead of 1, as long as neither the
  passed-through square nor the destination is under attack — a controlled
  "royal dash," similar in spirit to castling but usable at any time.
- **Rally the Guard** — *Action, 2 cost, Easy.* The next King to move may
  swap places with any friendly piece anywhere on the board, without
  spending your action — "the king calls a defender to his side."
- **Last Stand** — *Modifier, 1 cost, Hard.* If your King is currently in
  check, its next move may capture the checking piece even if that piece
  is defended by another enemy piece (normally capturing into a defended
  square would just trade the King for it, which isn't legal — this would
  need its own carve-out in the check-safety logic, not just a new
  destination).
- **Decree of Safety** — *Modifier, 2 cost, Hard.* The next King move may
  end on a square attacked by exactly one enemy piece without that being
  treated as moving into check, as long as that attacker itself is pinned
  or otherwise can't actually capture the King next turn — the most
  rules-bending idea on this list; would need a real definition of
  "counts as safe" before it could be scoped, let alone built.
