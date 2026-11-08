# Kang Chess — Phase 1 Analysis

Clean-room study of how a modern chess client grades moves, scales bot
strength, handles premoves, and runs clocks. It feeds the design of this
offline app.

## Method and evidence labels

Chess.com's client code was **not** decompiled, extracted, or instrumented.
Its terms of service forbid that, and its grading and bot logic run on its
servers, where no client-side tool can observe them. Proprietary behavior was
therefore studied only through public documentation and normal user-visible
behavior. Everything implemented here is our own code, built on open
references.

Each finding carries one label:

| Label | Meaning |
|---|---|
| **Documented** | Stated in a public source (cited). |
| **Observed** | Visible to any user of chess clients during normal play. |
| **Derived** | Mathematics or open-source reference formulas we adopt. |
| **Design** | Our own choice for this app. |
| **Unknown** | Proprietary or unpublished; not inferable without unauthorized access. |

Sources:

- Chess.com Help Center, "How are moves classified?"
  <https://support.chess.com/en/articles/8572705>
- Stockfish UCI options (`Skill Level`, `UCI_LimitStrength`, `UCI_Elo`,
  `MultiPV`): Stockfish source and README, <https://github.com/official-stockfish/Stockfish>
- Lichess open-source win-probability and accuracy formulas,
  <https://lichess.org/page/accuracy> (formulas only; no Lichess code is used)

---

## 1. Game review and move classification

### 1.1 Win probability ("expected points")

**Documented:** Chess.com grades moves by *expected points* rather than raw
centipawns. Expected points estimate a score between 0 (loss) and 1 (win),
and a move is graded by how many expected points it gives up compared with
the best move. Its model also uses player rating. That model is
**Unknown**.

**Derived:** We use the logistic mapping from Lichess, with no rating term:

```
W(cp) = 1 / (1 + e^(−0.00368208 · cp))        // 0..1, from the mover's view
```

- `cp` is the engine score in centipawns from the mover's point of view.
- Mate scores map to `W = 1.0` (mover mates) or `W = 0.0` (mover is mated).
- Terminal positions: checkmate gives 1.0 or 0.0. Stalemate, insufficient
  material, threefold repetition and the 50-move rule all give 0.5.

| cp | W |
|---:|---:|
| 0 | 0.50 |
| +100 | 0.59 |
| +300 | 0.75 |
| +500 | 0.86 |
| +1000 | 0.98 |

### 1.2 Expected points lost (EPL)

For a move `m` played from position `P` to position `P'`:

```
S_best  = engine score of P (best line), mover's view
S_after = −(engine score of P'), converted to mover's view
EPL     = max(0, W(S_best) − W(S_after))
```

When `m` equals the engine's best move, EPL is 0 by definition. This absorbs
search noise between the two independent searches.

One search per position gives both values. Position `P_k` serves as "after"
for move `k` and "before" for move `k+1`, so a game of `n` plies needs
`n + 1` searches. Each search runs with `MultiPV 2` so the second-best line
is available for the Great and Brilliant rules.

### 1.3 Base thresholds

**Documented** (Chess.com Help Center ranges, applied to EPL):

| Class | EPL range |
|---|---|
| Best | engine's top move (EPL 0) |
| Excellent | 0.00 – 0.02 |
| Good | 0.02 – 0.05 |
| Inaccuracy `?!` | 0.05 – 0.10 |
| Mistake `?` | 0.10 – 0.20 |
| Blunder `??` | 0.20 – 1.00 |

Chess.com notes that its rating-aware model judges the same evaluation swing
differently at different ratings. Our model does not use rating (**Design**).

### 1.4 Special classes

Chess.com documents what the special classes mean in prose. It does not
publish the exact rules (**Unknown**). The rules below are our own
(**Design**). Each turns the documented intent into a test on engine output.

The rules run in this order. The first one that matches wins.

1. **Book.** The game so far, in UCI form, is a prefix of a line in the
   bundled opening list (`lib/src/core/opening_book.dart`), the move is
   within the first 20 plies, and EPL ≤ 0.05.
2. **Brilliant `!!`** (documented intent: a good piece sacrifice, played when
   not already completely winning and not leaving a bad position).
   All of the following must hold:
   - EPL ≤ 0.02 (best or excellent);
   - **Sacrifice test:** play `m`, then follow the engine's principal
     variation from `P'` for up to 6 plies. The mover's material
     (P=1, N=B=3, R=5, Q=9) at the end of that line is at least 2 points
     lower than before `m`. A trade that wins the material back does not
     count, and neither does a single pawn.
   - `W(S_after) ≥ 0.50`: the position is not bad after the sacrifice;
   - The second-best line has `W(S_second) < 0.95`: without the sacrifice
     the mover was not already completely winning.
3. **Great `!`** (documented intent: a move critical to the result, such as
   the only move or one that turns a loss into equality).
   - `m` is the engine's best move;
   - `W(S_best) − W(S_second) ≥ 0.15`: every alternative is clearly worse,
     so it is effectively the only good move;
   - `m` is not a plain recapture on the square where the opponent just
     captured. Recaptures are usually forced and obvious.
4. **Miss `X`** (documented intent: failing to punish the opponent's error).
   - The opponent's previous move had EPL ≥ 0.10;
   - `W(S_best) ≥ 0.70`: a real winning chance existed;
   - this move has EPL ≥ 0.10.
   Miss replaces the Mistake or Blunder label for that move.
5. Otherwise, apply the thresholds in §1.3.

### 1.5 Accuracy

Chess.com's accuracy score (CAPS) is proprietary (**Unknown**). We use the
published Lichess formula (**Derived**), with win percentages on a 0–100
scale:

```
moveAccuracy = clamp(103.1668 · e^(−0.04354 · (W%_before − W%_after)) − 3.1669, 0, 100)
gameAccuracy = (arithmetic mean + harmonic mean) / 2    // over that side's moves
```

Lichess adds volatility weighting. We omit it to keep the formula
transparent (**Design**).

---

## 2. Engine control and bot rating scaling

### 2.1 What Stockfish provides (Documented)

| Option | Effect |
|---|---|
| `Skill Level` 0–20 | Weakens play by choosing among MultiPV candidates with a random, skill-dependent error term. |
| `UCI_LimitStrength` + `UCI_Elo` | Maps a target Elo to an internal skill level. Stockfish 17 accepts **1320–3190**. Its source comments say the scale is calibrated against engine-vs-engine play at fixed time controls. |
| `MultiPV n` | Reports the top `n` lines. Used for review and for our own weakening. |
| `go depth d` / `go movetime t` | Hard search limits. Both can be given together; whichever is hit first stops the search. |

Chess.com's bots run on its own engine stack with tuned "personalities". Their
implementation is **Unknown**.

### 2.2 Our strength model (Design)

Stockfish cannot play below 1320 Elo by itself. We use two regimes.

**Below 1320, our own error injection** (`lib/src/engine/bot_move_picker.dart`):

1. Search with `MultiPV k` at a small depth `d`.
2. With probability `p_random`, play a uniformly random legal move. This
   models a beginner who misses tactics.
3. Otherwise sample among the `k` candidates with a softmax over their
   scores at temperature `τ` (in centipawns):
   `P(i) ∝ exp((score_i − score_best) / τ)`.
   A larger `τ` makes the bot more willing to play clearly worse moves.
4. A style bias adds centipawns to some candidate types before sampling.
   *Aggressive* favors checks and captures; *Solid* favors quiet moves.

**From 1320 up, Stockfish's own limiter:** `UCI_LimitStrength=true`,
`UCI_Elo=e`, with a capped `movetime`. The top preset turns the limiter off
and searches at full strength.

| Elo | Regime | depth | MultiPV | τ (cp) | p_random | movetime cap |
|---:|---|---:|---:|---:|---:|---:|
| 100 | injection | 1 | 8 | 500 | 0.55 | 200 ms |
| 250 | injection | 1 | 8 | 350 | 0.40 | 200 ms |
| 400 | injection | 2 | 6 | 250 | 0.28 | 250 ms |
| 600 | injection | 3 | 5 | 170 | 0.18 | 300 ms |
| 800 | injection | 4 | 5 | 120 | 0.11 | 300 ms |
| 1000 | injection | 5 | 4 | 80 | 0.06 | 400 ms |
| 1200 | injection | 6 | 4 | 50 | 0.03 | 400 ms |
| 1400–2600 | `UCI_Elo` | — | — | — | — | 500–1200 ms |
| 2850 (GM) | `UCI_Elo` 2850 | — | — | — | — | 1500 ms |
| Max | full strength | — | — | — | — | 2000 ms |

The ratings below 1320 are **estimates**, not calibrated. Verifying them
would mean running bot-vs-bot matches against anchored opponents. That is
listed as follow-up work in the README.

Engine search time: each bot move uses `min(movetimeCap, remaining/30 + increment/2)`.

### 2.3 Thinking pace (Design, `lib/src/domain/bot_pacing.dart`)

The engine answers far faster than a person, so each reply is held back until
a human-like total think time has passed. Search time counts toward it. The
think time is drawn per move:

- **Base by rating:** about 1 s at 100 rising to 4.5 s at 2850, in an
  unhurried game.
- **Clock:** scaled by the per-move budget `remaining/35 + 0.8·increment`
  (×0.3 to ×2), and never more than 12% of the remaining clock.
- **Opening:** ×0.35 for the first `4 + elo/250` plies (moves from memory).
- **Obvious moves:** a forced move takes 0.35–0.85 s; a recapture ×0.4;
  escaping check with ≤3 replies ×0.5. Otherwise busier positions take
  longer (×0.6 to ×1.4 by legal-move count).
- **Spread:** a log-normal factor (σ 0.6 for weak bots, 0.4 for strong)
  and a 7% chance of a long think (×1.8 to ×3.3).
- **Limits:** 0.35 s minimum (less only in a time scramble), 15 s maximum.

This also leaves a natural window for premoves.

---

## 3. Premoves

**Observed** in mainstream clients:

- A premove is entered while the opponent is thinking. It is shown as a
  highlighted ghost move.
- It runs immediately after the opponent's move if it is legal. If not, it
  is silently cancelled.
- Several clients, Chess.com included, can queue more than one premove.
  Clicking or right-clicking elsewhere cancels the queue.

How much clock time a premove costs, and whether there is a latency penalty,
differs between platforms and is not specified publicly (**Unknown**).

**Our rules (Design, `lib/src/domain/premove_queue.dart`):**

1. **Queueing:** up to 10 premoves. Each one is checked against a
   *projected board*: the current board with all earlier premoves applied.
   The source square must hold one of your pieces on that board.
2. **Entry check:** geometry only. Is the move a valid pattern for that
   piece? Blocking pieces are ignored, because the opponent may move them.
   A pawn may premove diagonally even onto an empty square, since a capture
   may become possible. Castling patterns are allowed while the king is on
   its home square. A premove may also land on one of your own pieces, as a
   planned recapture in case the opponent takes there. Pawns may only do this
   diagonally, and a king's two-square move onto a piece is never accepted
   (that pattern is castling).
3. **Execution:** after the opponent moves, the head of the queue is checked
   for full legality on the real position. A legal move plays immediately
   with **0 ms** clock cost. The increment is still added.
4. **Cancellation:** if the head is illegal, the **whole queue** is cleared,
   because later premoves were planned assuming it would succeed. Tapping an
   empty square, a new game, game end, or a takeback also clears the queue.
5. **Promotion** premoves always promote to a queen.

---

## 4. Clock engine

**Documented** (FIDE Laws, Fischer increment): the increment is added to the
mover's clock after each completed move. Flag fall loses, unless the opponent
has no possible way to checkmate, in which case the game is drawn.

**Our implementation (Design, `lib/src/domain/chess_clock.dart`):**

- Time is measured with a monotonic `Stopwatch`, not wall-clock time.
  Changing the device clock or sleeping does not distort it.
- The clocks start after White's first move, so that move is free. From then
  on the side to move's clock runs.
- On each move: stop the mover's clock, subtract the exact elapsed
  microseconds, add the increment, then start the opponent's clock.
- Each side has its own `TimeControl(initial, increment)`. This supports
  asymmetric games such as Player 5+2 against Bot 1+0. "Untimed" turns the
  clock off entirely.
- The display refreshes every 100 ms from a single `Timer.periodic`, which
  is cancelled when the clock stops or is disposed. A flag is detected on the
  first tick at or below zero. Below 20 s the display shows tenths.
- The clock is its own `ChangeNotifier`. Its ticks rebuild only the two clock
  widgets, not the board.

---

## 5. Resulting architecture

```
lib/src/
  core/       chess helpers (UCI ↔ dartchess, material), opening book
  domain/     pure Dart: TimeControl, ChessClock, PremoveQueue,
              move classification math, bot profiles
  engine/     UCI protocol parser, EngineService (serialized job queue over
              one Stockfish instance), Stockfish FFI transport, bot move picker
  game/       GameController (rules, clocks, premoves, bot turns)
  review/     GameAnalyzer (per-ply search, classification), review state
  settings/   persisted user preferences
  ui/         board widget and painters, themes, piece sets, screens
```

Engine lifecycle and resource rules:

- **One** Stockfish instance per app run. The FFI plugin allows only one. It
  starts on first use and is disposed when the app is detached.
- Commands are serialized through a single job queue. Each job is
  `setoption…` → `isready`/`readyok` → `position…` → `go…` → `bestmove`.
- Cancelling sends `stop`. The job still waits for `bestmove`, so the next
  job never reads a stale search.
- Bot replies and review results carry a generation token. Results from a
  game or review that has ended are dropped.
- One `stdout` subscription for the whole app. Per-job listeners are plain
  callbacks, so no stream subscriptions build up over time.

Licensing: Stockfish and `dartchess` are GPL-3.0, so the app is GPL-3.0.
Piece art is drawn by our own code (glyph-based and vector-painted sets), and
no third-party artwork is bundled.
