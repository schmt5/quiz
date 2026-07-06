# Event-Readiness Review (~300 participants)

Code inspection of the quiz app ahead of the big live event. Focus: **running
correctly matters more than features**. Every finding below was verified
against the code (file references included); a few scary-sounding hypotheses
were checked and dismissed — see "Verified non-issues" at the end.

**Verdict:** the app is architecturally sound — authorization, enrollment
races, scoring math, and XSS handling all check out. The real risks are
(1) infrastructure steps that are documented but not yet applied, (2) one
likely-broken thing on the custom domain (WebSocket origin check), and
(3) a handful of correctness gaps that only bite if the host does something
unusual mid-run. Work through section A before the event; sections B–D are
ranked fixes and runbook rules.

---

## A. Critical — do/verify before the event

### A1. Apply the fly.toml scaling steps (documented, not applied)

`fly.toml` is still in idle config: `min_machines_running = 0`,
`auto_stop_machines = 'stop'`, `shared-cpu-1x` / 1 GB (fly.toml:23–36).
The checklist in [scaling-for-event.md](scaling-for-event.md) (pin to 1
machine, `performance-2x`/`-4x`, `min_machines_running = 1`) exists but has
not been executed. Without it: cold start when the first players arrive, and
a single shared CPU core choking on the 300-process render burst every time
the host advances a question.

### A2. WebSocket origin check vs. `waerweiss.ch` — likely broken, must test

There is **no `check_origin` setting anywhere** in config, so Phoenix falls
back to checking WebSocket origins against the endpoint URL host — which is
`PHX_HOST`, set to `along-quiz.fly.dev` in fly.toml:16. Meanwhile the custom
domain `waerweiss.ch` is live (docs/custom-domain-setup.md).

- If `PHX_HOST` is still the fly.dev value: pages on `waerweiss.ch` load
  (plain HTTP works), but the **LiveView socket is rejected — participants
  hang forever on the "Verbinde …" spinner**. This failure is invisible in a
  quick "does the page load" check.
- If `PHX_HOST` was overridden via a Fly secret to `waerweiss.ch`: then
  `www.waerweiss.ch` and `along-quiz.fly.dev` are the rejected origins
  instead.

**Fix:** add an explicit list in `config/runtime.exs`:

```elixir
config :quiz, QuizWeb.Endpoint,
  check_origin: [
    "https://waerweiss.ch",
    "https://www.waerweiss.ch",
    "https://along-quiz.fly.dev"
  ]
```

**Verify:** `fly secrets list -a along-quiz` (is PHX_HOST overridden?), then
join as a participant **from a phone via `https://waerweiss.ch`** and confirm
the question actually updates when the host advances. Repeat for `www.`.

### A3. QR code and "go to <host>" text follow `PHX_HOST`

The host screen's QR code and the displayed join host are built from
`QuizWeb.Endpoint.url()` ([host.ex:493–509](../lib/quiz_web/live/run_live/host.ex)).
If `PHX_HOST` is still `along-quiz.fly.dev`, the QR on the beamer sends 300
people to the fly.dev domain instead of `waerweiss.ch`. Set `PHX_HOST` to the
domain you want on screen (and keep A2's `check_origin` list covering all
hosts).

### A4. Freeze deploys during the event

A rolling deploy (a) drops **every** WebSocket — all 300 participants
reconnect at once — and (b) briefly runs two machines with clustering off,
so PubSub splits and players on the new machine silently stop receiving
updates (see scaling-for-event.md). Deploy the fly.toml/config changes well
before doors open, then **do not deploy again until the event is over**.

### A5. You are flying blind: no monitoring in prod

- No Sentry/error tracking; telemetry has no reporter
  ([telemetry.ex](../lib/quiz_web/telemetry.ex)).
- LiveDashboard is only mounted when `dev_routes` is set — which only
  dev.exs does ([router.ex:33–46](../lib/quiz_web/router.ex)). The
  scaling doc's "watch `/dashboard` during the run" step **does not work in
  prod**.

Before the event either mount LiveDashboard in prod behind
`Plug.BasicAuth`, or plan to keep `fly logs -a along-quiz` open on a laptop
during the whole run. Errors currently surface nowhere else.

### A6. Run the load test against prod-like infra

After resizing the VM, run the existing harness (see scaling-for-event.md):

```sh
mix quiz.load --participants 300 --questions 5 --mode herd --subscribers
```

against the Fly machine / prod DB, and check pool queue times and p95
latencies. This exercises exactly the hot paths listed in section C.

---

## B. Bugs (correctness)

Ranked by event impact. None crash the app today, but each can corrupt data
or confuse the room if triggered.

### B1. The "answers closed" guard checks stale in-memory state

`Play.submit_answer/4` rejects submissions by pattern-matching
`%Game{revealing: true}` — but that's the **caller's copy** of the game from
LiveView assigns, not fresh DB state
([play.ex:291](../lib/quiz/play.ex)). The docstring calls it a server-side
guard; it isn't. A participant whose LiveView hasn't yet processed the
reveal broadcast (slow venue Wi-Fi, congested mailbox) can still submit
after the host reveals the solution, corrupting the stats the room is
looking at. The window is normally sub-second but grows under load.

**Fix:** inside `submit_answer`, re-read `revealing`/`current_position` from
the DB (or at least `Repo.reload` the game) before accepting.

### B2. Questions can be edited, deleted, and reordered while the game runs

`@locked_run_states` is only `[:finished, :closed]`
([games.ex:463](../lib/quiz/games.ex)) — `:open` and `:running` are not
locked. During a live run:

- **Deleting the current question** orphans `current_position` → all 300
  participants and the host see "Keine Frage verfügbar".
- **Reordering** shifts positions underneath `current_position` → the run
  jumps to an unexpected question.
- **Editing choices/solutions** silently invalidates stored grades: grades
  are computed at submit time and never recomputed, so already-submitted
  answers stay graded against the old version.

**Fix:** extend the lock to `:open`/`:running` (at minimum for delete and
reposition). **Runbook rule until then: nobody touches the question editor
once the lobby opens.**

### B3. A running game can be deleted with one confirmed click

The "Löschen" action in the games list works in any status — the only
protection is a `data-confirm` dialog
([index.ex:84–86](../lib/quiz_web/live/game_live/index.ex),
[games.ex:138](../lib/quiz/games.ex)). Deleting cascades questions → answers:
one misclick + reflexive "OK" during the event and the entire run (all
answers, all grading) is unrecoverable.

**Fix:** refuse deletion for `:open`/`:running` (and arguably `:finished`
until grading is published).

### B4. Re-submission overwrites manual grades

The answer upsert replaces `grade` with the fresh auto-grade
([play.ex:310](../lib/quiz/play.ex)). If the host retreats to a question
*after* the corrector already hand-graded its text answers, any team that
re-submits wipes its manual grade back to the auto value — silently.

**Runbook rule:** correct only after the quiz is finished, and never use
"Vorherige Frage" once correction has started. (Code fix: skip the grade
column on conflict when a manual correction exists, or block retreat after
correction begins.)

### B5. Participant LiveView has no catch-all `handle_info`

`PlayLive.Play` handles exactly the four current broadcast types
([play.ex:274–288](../lib/quiz_web/live/play_live/play.ex)); the host screen
has a defensive catch-all ([host.ex:446](../lib/quiz_web/live/run_live/host.ex))
precisely so "a new message type can never crash the presenter screen".
The participant side lacks that: the next commit that adds a broadcast type
crashes **all 300 participant processes simultaneously** (they remount, but
the room sees a collective flicker/spinner).

**Fix:** one line — `def handle_info(_msg, socket), do: {:noreply, socket}`.

### B6. `publish_grading` is not idempotent

It always writes and always broadcasts ([play.ex:472–481](../lib/quiz/play.ex)).
A double-click publishes twice → every participant recomputes the leaderboard
twice (see C1). Minor on its own; cheap to guard with
`if game.grading_published, do: {:ok, game}`.

---

## C. Performance / thundering-herd hot spots

The DB pool is 50 and Postgres is oversized, so none of these are expected
to fail outright — but they are the places that buckle first. All are
exercised by `mix quiz.load` (A6).

### C1. Publishing the grading → 300 simultaneous full-table leaderboard loads

On the `grading_published` broadcast, **every** participant LiveView calls
`Play.leaderboard/1`, which loads *all answer rows of the game* plus *all
participants* and ranks them in memory
([play_live/play.ex:286–296](../lib/quiz_web/live/play_live/play.ex),
[play.ex:487–503](../lib/quiz/play.ex)). With 300 teams × ~20 questions
that's 300 concurrent copies of a ~6,000-row query + a 300-row query — the
single heaviest burst in the app, at the emotional climax of the evening.

**Improvement:** compute the leaderboard once inside `publish_grading` and
ship the rows in the broadcast payload; keep the on-demand path only for
reconnects.

### C2. Every host click → ~900 simultaneous queries

Each `status_changed` broadcast (start / reveal / next / previous) makes all
300 participant LiveViews run `current_question` + `question_numbering` +
`get_answer` ([play_live/play.ex:298–317](../lib/quiz_web/live/play_live/play.ex)).
~900 near-identical queries hit the pool at the same instant, ~20+ times
during the quiz. Pool 50 should absorb it (verify via A6); the optional
improvement is to include the question and numbering in the broadcast so
participants don't query at all.

### C3. One COUNT query per submitted answer (host screen)

Every answer submission triggers `count_answers` on the host LiveView only
([host.ex:433](../lib/quiz_web/live/run_live/host.ex)) — ~300 COUNTs per
question, spread over the answering window. Fine as-is; listed so it isn't
"discovered" during the event.

---

## D. Hardening / event-day risks

### D1. No way to remove or rename a participant ⚠️

The join QR is on the beamer all evening; anyone in the room can enroll with
any name (≤ 50 chars, no filtering), and that name renders on the projector
roster and the final leaderboard. There is **no host UI and no context
function to kick or rename a team.** If someone joins as something obscene,
your only options are raw SQL on prod or living with it on the big screen.
This is the most likely *social* failure mode of the evening — consider a
minimal "remove team" action on the host roster before the event.

### D2. No enrollment cap or rate limiting

`get_game_by_join_code` and `enroll` are unauthenticated and unthrottled
([play.ex:175–248](../lib/quiz/play.ex)). A prankster can script-enroll
hundreds of fake teams, polluting the roster and leaderboard (and each
enrollment broadcasts to everyone). Cheap insurance: cap participants per
game (e.g. reject enrollment past 400).

### D3. Defense-in-depth asserts missing in `submit_answer`

`submit_answer` trusts `participant` and `question` from socket assigns and
never asserts `participant.game_id == game.id` or
`question.game_id == game.id` ([play.ex:295](../lib/quiz/play.ex)). Today's
call sites load both correctly; the asserts make future call sites unable to
cross-contaminate games. Two lines.

### D4. The localStorage token is the only way back into a team

Signed token in `localStorage` per join code; if a team's browser clears it
(private mode, "clear site data", switching devices), they cannot rejoin as
themselves — the old name is blocked (`name_taken`) and their points are
stranded on the orphaned team
([play.ex:213–246](../lib/quiz/play.ex)). Token lifetime (24 h) is fine.
**Brief the room: use one device per team and keep the same browser tab.**
Know that the workaround for a locked-out team is "new name, points lost".

### D5. Question images depend on R2/Cloudflare at show time

Media is served from `images.waerweiss.ch` (R2 public bucket). If R2 or the
CDN misbehaves, images 404 with no fallback. **Warm the cache** before the
event by clicking through every question in the preview from the venue
network — repeat views then serve from Cloudflare's edge
(`cf-cache-status: HIT`).

### D6. No HTTP health check in fly.toml (optional)

fly.toml defines no `[[http_service.checks]]`, so Fly only knows the port is
open, not that the app responds. A simple GET check on `/` speeds up
automatic recovery if the app wedges. Optional for a single-machine run.

---

## E. Verified non-issues

Checked explicitly so nobody re-litigates them under stress:

- **Authorization is solid.** All host/correction/leaderboard routes require
  login *and* every mount goes through owner-scoped
  `Games.get_game!(scope, …)`; participants are identified by a signed
  `Phoenix.Token` that is verified against the game on restore.
- **Tie ranking is exact.** Scores are sums of 1.0 / 0.5 / 0.0 — all exactly
  representable floats, so the `==` tie comparison in `with_ranks/1` is safe.
- **Enrollment name races are handled** via the unique index on
  `(game_id, name)` plus a retry that maps constraint errors to
  `:name_taken` ([play.ex:223–246](../lib/quiz/play.ex)).
- **The correction view does not stampede**: it ignores `answer_submitted`
  broadcasts for other questions
  ([question.ex:226](../lib/quiz_web/live/correction_live/question.ex)).
- **XSS is covered**: question descriptions pass through a strict allowlist
  scrubber; participant names are HEEx-escaped everywhere they render.
- **Sequence questions grade correctly**: the shuffle is applied to a display
  copy only; scoring always uses the canonical question.
- **Answer indexes are adequate**: `answers(question_id)` +
  unique `(participant_id, question_id)`; participants unique on
  `(game_id, name)`.

---

## Suggested order of work

| # | Action | Type | Effort | Status |
|---|--------|------|--------|--------|
| 1 | A2 `check_origin` + verify on phone via `waerweiss.ch` | config | small | ✅ done (config + PHX_HOST; phone test pending after deploy) |
| 2 | A1 apply fly.toml scaling steps | ops | small | open |
| 3 | B5 catch-all `handle_info` in participant LiveView | code | 1 line | ✅ done |
| 4 | B3 block deleting open/running games | code | small | open |
| 5 | B2 lock question edits/reorder/delete while open/running | code | small | open |
| 6 | B1 server-side reveal re-check in `submit_answer` | code | small | open |
| 7 | C1 leaderboard computed once, shipped in broadcast (incl. B6 idempotency) | code | medium | ✅ done |
| 8 | D1 "remove team" action on host roster | code | medium | open |
| 9 | A5 LiveDashboard behind Basic Auth in prod | code | small | open |
| 10 | A6 load test on prod-like target; A4 deploy freeze; B4/D4 runbook rules | ops | — | open |
